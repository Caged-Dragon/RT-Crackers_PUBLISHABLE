"""Guest + customer cart.

* Customer cart  -> `carts` / `cart_items` tables (one active cart per user, enforced by a unique index).
* Guest cart     -> stateless, signed `X-Cart-Token` (JWT) that carries the lines; nothing is written to the DB.
Both flavours go through the same resolve -> price -> coupon pipeline so totals are identical before and after login.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import timedelta
from decimal import Decimal

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.constants import MAX_CART_LINE_QTY, MAX_GUEST_CART_LINES, SETTING_MIN_ORDER_AMOUNT
from core.database import get_db
from core.exceptions import AppException, BadRequestError, NotFoundError, UnauthorizedError, UnprocessableError
from core.security import TOKEN_CART, create_jwt, decode_jwt
from core.system_models import get_setting
from customers.auth.models import User
from customers.cart.models import Cart
from customers.cart.repository import CartRepository, Catalog
from customers.cart.schemas import (
    CartCount, CartCouponOut, CartItemAdd, CartLineOut, CartMergeOut, CartOut, CartSummary, SkippedLine,
)
from customers.coupons.models import Coupon
from customers.coupons.service import CouponError, CouponService
from customers.products.models import Product, ProductVariant
from customers.products.repository import ProductRepository
from utils.pricing import ZERO, LineInput, PricingResult, price_lines, q2

logger = logging.getLogger("rtcrackers.cart")


# ------------------------------------------------------------------ helpers
def line_key(product_id: int, variant_id: int | None) -> str:
    return f"{product_id}-{variant_id or 0}"


def parse_line_key(key: str) -> tuple[int, int | None]:
    try:
        raw_p, raw_v = key.split("-")
        product_id, variant_id = int(raw_p), int(raw_v)
    except ValueError as exc:
        raise BadRequestError("Invalid cart line identifier", code="invalid_line_key") from exc
    if product_id <= 0 or variant_id < 0:
        raise BadRequestError("Invalid cart line identifier", code="invalid_line_key")
    return product_id, (variant_id or None)


@dataclass
class CartContext:
    user: User | None = None
    token: str | None = None

    @property
    def is_guest(self) -> bool:
        return self.user is None


@dataclass
class RawLine:
    product_id: int
    variant_id: int | None
    quantity: int
    cart_item_id: int | None = None

    @property
    def key(self) -> str:
        return line_key(self.product_id, self.variant_id)


@dataclass
class RawCart:
    lines: list[RawLine] = field(default_factory=list)
    coupon: Coupon | None = None      # customer cart
    coupon_code: str | None = None    # guest cart
    coupon_dropped: bool = False


@dataclass
class ResolvedLine:
    raw: RawLine
    product: Product | None
    variant: ProductVariant | None
    image: str | None
    unit_price: Decimal
    mrp: Decimal
    weight: Decimal
    gst: Decimal
    available: int
    purchasable: bool
    issue: str | None

    @property
    def name(self) -> str:
        return self.product.product_name if self.product else f"Item {self.raw.product_id}"


@dataclass
class PricedCart:
    lines: list[ResolvedLine]
    buy_lines: list[ResolvedLine]
    pricing: PricingResult
    coupon: Coupon | None
    coupon_discount: Decimal
    warnings: list[str]
    min_order_amount: Decimal

    @property
    def subtotal(self) -> Decimal:
        return self.pricing.subtotal


# ------------------------------------------------------------------ service
class CartService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = CartRepository(session)
        self.products = ProductRepository(session)
        self.coupons = CouponService(session)

    # ------------------------------------------------------- guest token
    @staticmethod
    def _decode_guest(token: str | None) -> RawCart:
        if not token:
            return RawCart()
        try:
            payload = decode_jwt(token, TOKEN_CART)
        except UnauthorizedError:
            return RawCart()  # an expired/garbled cart token simply means an empty guest cart
        lines: list[RawLine] = []
        for item in (payload.get("l") or [])[:MAX_GUEST_CART_LINES]:
            try:
                product_id, variant_id, qty = int(item[0]), int(item[1]), int(item[2])
            except (TypeError, ValueError, IndexError):
                continue
            if product_id > 0 and variant_id >= 0 and 1 <= qty <= MAX_CART_LINE_QTY:
                lines.append(RawLine(product_id, variant_id or None, qty))
        code = payload.get("cc")
        return RawCart(lines=lines, coupon_code=code if isinstance(code, str) else None)

    @staticmethod
    def _issue_token(raw: RawCart) -> str:
        extra = {"l": [[l.product_id, l.variant_id or 0, l.quantity] for l in raw.lines]}
        if raw.coupon_code:
            extra["cc"] = raw.coupon_code
        token, _, _ = create_jwt("guest", TOKEN_CART, timedelta(days=settings.CART_TOKEN_EXPIRE_DAYS), extra)
        return token

    # --------------------------------------------------------- resolving
    @staticmethod
    def _resolve(raw: RawLine, catalog: Catalog) -> ResolvedLine:
        entry = catalog.products.get(raw.product_id)
        if entry is None or not entry.category_active:
            return ResolvedLine(raw, None, None, None, ZERO, ZERO, Decimal(0), Decimal(0), 0, False, "This product is no longer available")
        product = entry.product
        variant = None
        if raw.variant_id is not None:
            variant = catalog.variants.get((raw.product_id, raw.variant_id))
            if variant is None:
                return ResolvedLine(raw, product, None, entry.image, ZERO, ZERO, Decimal(0), Decimal(0), 0, False,
                                    "This option is no longer available")
        source = variant or product
        available = catalog.available.get((raw.product_id, raw.variant_id), 0)
        issue = None
        if available <= 0:
            issue = "Out of stock"
        elif raw.quantity > available:
            issue = f"Only {available} left in stock"
        return ResolvedLine(raw, product, variant, entry.image, source.selling_price, source.mrp, Decimal(source.weight or 0),
                            product.gst_percentage, available, issue is None, issue)

    async def _min_order_amount(self) -> Decimal:
        value = await get_setting(self.session, SETTING_MIN_ORDER_AMOUNT, settings.DEFAULT_MIN_ORDER_AMOUNT)
        return q2(Decimal(str(value)))

    async def build(self, raw: RawCart, user_id: int | None) -> PricedCart:
        catalog = await self.repo.catalog({(l.product_id, l.variant_id) for l in raw.lines})
        lines = [self._resolve(l, catalog) for l in raw.lines]
        buy = [l for l in lines if l.purchasable]
        inputs = [LineInput(key=l.raw.key, unit_price=l.unit_price, mrp=l.mrp, quantity=l.raw.quantity,
                            gst_percentage=l.gst, weight=l.weight) for l in buy]
        base = price_lines(inputs, ZERO)
        warnings = [f"{l.name}: {l.issue}" for l in lines if l.issue]

        coupon: Coupon | None = None
        discount = ZERO
        if buy and (raw.coupon is not None or raw.coupon_code):
            try:
                if raw.coupon is not None:
                    check = await self.coupons.evaluate_loaded(raw.coupon, user_id=user_id, subtotal=base.subtotal)
                else:
                    check = await self.coupons.evaluate(raw.coupon_code or "", user_id=user_id, subtotal=base.subtotal)
                coupon, discount = check.coupon, check.discount
            except CouponError as exc:
                code = raw.coupon.coupon_code if raw.coupon else raw.coupon_code
                warnings.append(f"Coupon {code} was removed: {exc.message}")
                raw.coupon_dropped = True
        pricing = price_lines(inputs, discount) if discount > ZERO else base
        return PricedCart(lines, buy, pricing, coupon, discount, warnings, await self._min_order_amount())

    # ------------------------------------------------------------ output
    @staticmethod
    def to_out(priced: PricedCart, *, is_guest: bool, token: str | None) -> CartOut:
        by_key = {lp.key: lp for lp in priced.pricing.lines}
        items: list[CartLineOut] = []
        for l in priced.lines:
            lp = by_key.get(l.raw.key)
            qty = l.raw.quantity
            pct = round((l.mrp - l.unit_price) * 100 / l.mrp, 2) if l.mrp else Decimal(0)
            items.append(CartLineOut(
                line_key=l.raw.key, cart_item_id=l.raw.cart_item_id, product_id=l.raw.product_id, variant_id=l.raw.variant_id,
                sku=(l.variant.variant_sku if l.variant else (l.product.sku if l.product else "")),
                slug=l.product.slug if l.product else None, name=l.name, variant_name=l.variant.variant_name if l.variant else None,
                image=l.image, quantity=qty, unit_price=l.unit_price, mrp=l.mrp, discount_percentage=Decimal(str(pct)),
                gst_percentage=l.gst, line_subtotal=lp.gross if lp else q2(l.unit_price * qty),
                line_discount=lp.discount if lp else ZERO, line_tax=lp.tax if lp else ZERO, line_total=lp.total if lp else ZERO,
                available_quantity=l.available, in_stock=l.available > 0, purchasable=l.purchasable, issue=l.issue))
        p = priced.pricing
        has_buy = bool(priced.buy_lines)
        shortfall = max(priced.min_order_amount - p.subtotal, ZERO) if has_buy else ZERO
        summary = CartSummary(
            line_count=len(priced.lines), item_count=p.item_count, subtotal=p.subtotal, discount=p.discount, tax=p.tax,
            total_before_shipping=p.total_before_shipping, mrp_savings=p.mrp_savings, total_weight_kg=p.total_weight.quantize(Decimal("0.001")),
            min_order_amount=priced.min_order_amount, meets_min_order=has_buy and shortfall == ZERO, shortfall=shortfall)
        coupon = (CartCouponOut(code=priced.coupon.coupon_code, description=priced.coupon.description, discount_amount=priced.coupon_discount)
                  if priced.coupon else None)
        return CartOut(is_guest=is_guest, items=items, summary=summary, coupon=coupon, warnings=priced.warnings, cart_token=token)

    # --------------------------------------------------------- stock rules
    async def _availability(self, product_id: int, variant_id: int | None) -> int:
        found = await self.products.get_active(str(product_id))
        if found is None:
            raise NotFoundError("Product not found", code="product_not_found")
        variants = await self.products.variants(product_id)
        if variants:
            if variant_id is None:
                raise UnprocessableError("Please choose a variant for this product", code="variant_required")
            for variant, available in variants:
                if variant.variant_id == variant_id:
                    return available
            raise NotFoundError("Variant not found", code="variant_not_found")
        if variant_id is not None:
            raise NotFoundError("Variant not found", code="variant_not_found")
        return await self.products.available_quantity(product_id, None)

    async def _check_quantity(self, product_id: int, variant_id: int | None, quantity: int) -> None:
        if quantity > MAX_CART_LINE_QTY:
            raise UnprocessableError(f"You can order at most {MAX_CART_LINE_QTY} units of one item", code="quantity_limit")
        available = await self._availability(product_id, variant_id)
        if available <= 0:
            raise UnprocessableError("This item is out of stock", code="out_of_stock")
        if quantity > available:
            raise UnprocessableError(f"Only {available} left in stock", code="insufficient_stock", details={"available": available})

    # ----------------------------------------------------- customer helpers
    async def _raw_from_cart(self, cart: Cart | None) -> RawCart:
        if cart is None:
            return RawCart()
        items = await self.repo.items(cart.cart_id)
        coupon = await self.coupons.repo.get(cart.coupon_id) if cart.coupon_id else None
        return RawCart(lines=[RawLine(i.product_id, i.variant_id, i.quantity, i.cart_item_id) for i in items], coupon=coupon)

    async def _user_out(self, user: User) -> CartOut:
        cart = await self.repo.get_active(user.user_id)
        raw = await self._raw_from_cart(cart)
        priced = await self.build(raw, user.user_id)
        if raw.coupon_dropped and cart is not None:
            await self.repo.set_coupon(cart, None)
            await self.session.commit()
        return self.to_out(priced, is_guest=False, token=None)

    def _guest_out_sync_token(self, raw: RawCart) -> str:
        return self._issue_token(raw)

    async def _guest_out(self, raw: RawCart) -> CartOut:
        priced = await self.build(raw, None)
        if raw.coupon_dropped:
            raw.coupon_code = None
        return self.to_out(priced, is_guest=True, token=self._issue_token(raw))

    async def priced_user_cart(self, user_id: int, *, lock: bool = False) -> tuple[Cart | None, PricedCart]:
        """Used by checkout/orders. Optionally row-locks the cart so two submissions cannot both convert it."""
        cart = await self.repo.get_active(user_id, lock=lock)
        raw = await self._raw_from_cart(cart)
        return cart, await self.build(raw, user_id)

    # ---------------------------------------------------------------- reads
    async def get(self, ctx: CartContext) -> CartOut:
        if ctx.user is not None:
            return await self._user_out(ctx.user)
        return await self._guest_out(self._decode_guest(ctx.token))

    async def counts(self, ctx: CartContext) -> CartCount:
        out = await self.get(ctx)
        return CartCount(line_count=out.summary.line_count, item_count=out.summary.item_count, subtotal=out.summary.subtotal)

    async def subtotal_for(self, ctx: CartContext) -> Decimal:
        return (await self.get(ctx)).summary.subtotal

    # --------------------------------------------------------------- writes
    async def add_item(self, ctx: CartContext, data: CartItemAdd) -> CartOut:
        if ctx.user is not None:
            cart = await self.repo.get_or_create(ctx.user.user_id, lock=True)
            existing = await self.repo.find_item(cart.cart_id, data.product_id, data.variant_id)
            total = (existing.quantity if existing else 0) + data.quantity
            await self._check_quantity(data.product_id, data.variant_id, total)
            if existing is not None:
                existing.quantity = total
                await self.session.flush()
            else:
                await self.repo.add_item(cart.cart_id, data.product_id, data.variant_id, total)
            await self.session.commit()
            return await self._user_out(ctx.user)

        raw = self._decode_guest(ctx.token)
        existing_line = next((l for l in raw.lines if l.product_id == data.product_id and l.variant_id == data.variant_id), None)
        total = (existing_line.quantity if existing_line else 0) + data.quantity
        await self._check_quantity(data.product_id, data.variant_id, total)
        if existing_line is not None:
            existing_line.quantity = total
        else:
            if len(raw.lines) >= MAX_GUEST_CART_LINES:
                raise UnprocessableError(f"A guest cart holds at most {MAX_GUEST_CART_LINES} different items; please log in", code="cart_full")
            raw.lines.append(RawLine(data.product_id, data.variant_id, total))
        return await self._guest_out(raw)

    async def update_item(self, ctx: CartContext, key: str, quantity: int) -> CartOut:
        product_id, variant_id = parse_line_key(key)
        if ctx.user is not None:
            cart = await self.repo.get_active(ctx.user.user_id, lock=True)
            item = await self.repo.find_item(cart.cart_id, product_id, variant_id) if cart else None
            if item is None:
                raise NotFoundError("This item is not in your cart", code="line_not_found")
            await self._check_quantity(product_id, variant_id, quantity)
            item.quantity = quantity
            await self.session.flush()
            await self.session.commit()
            return await self._user_out(ctx.user)

        raw = self._decode_guest(ctx.token)
        line = next((l for l in raw.lines if l.product_id == product_id and l.variant_id == variant_id), None)
        if line is None:
            raise NotFoundError("This item is not in your cart", code="line_not_found")
        await self._check_quantity(product_id, variant_id, quantity)
        line.quantity = quantity
        return await self._guest_out(raw)

    async def remove_item(self, ctx: CartContext, key: str) -> CartOut:
        product_id, variant_id = parse_line_key(key)
        if ctx.user is not None:
            cart = await self.repo.get_active(ctx.user.user_id, lock=True)
            item = await self.repo.find_item(cart.cart_id, product_id, variant_id) if cart else None
            if item is None:
                raise NotFoundError("This item is not in your cart", code="line_not_found")
            await self.repo.delete_item(item)
            await self.session.commit()
            return await self._user_out(ctx.user)

        raw = self._decode_guest(ctx.token)
        remaining = [l for l in raw.lines if not (l.product_id == product_id and l.variant_id == variant_id)]
        if len(remaining) == len(raw.lines):
            raise NotFoundError("This item is not in your cart", code="line_not_found")
        raw.lines = remaining
        return await self._guest_out(raw)

    async def clear(self, ctx: CartContext) -> CartOut:
        if ctx.user is not None:
            cart = await self.repo.get_active(ctx.user.user_id, lock=True)
            if cart is not None:
                await self.repo.clear_items(cart.cart_id)
                await self.repo.set_coupon(cart, None)
                await self.session.commit()
            return await self._user_out(ctx.user)
        return await self._guest_out(RawCart())

    # -------------------------------------------------------------- coupons
    async def apply_coupon(self, ctx: CartContext, code: str) -> CartOut:
        if ctx.user is not None:
            cart = await self.repo.get_or_create(ctx.user.user_id, lock=True)
            raw = await self._raw_from_cart(cart)
            priced = await self.build(RawCart(lines=raw.lines), ctx.user.user_id)
            if not priced.buy_lines:
                raise UnprocessableError("Add items to your cart before applying a coupon", code="cart_empty")
            check = await self.coupons.evaluate(code, user_id=ctx.user.user_id, subtotal=priced.subtotal)
            await self.repo.set_coupon(cart, check.coupon.coupon_id)
            await self.session.commit()
            return await self._user_out(ctx.user)

        raw = self._decode_guest(ctx.token)
        priced = await self.build(RawCart(lines=raw.lines), None)
        if not priced.buy_lines:
            raise UnprocessableError("Add items to your cart before applying a coupon", code="cart_empty")
        check = await self.coupons.evaluate(code, user_id=None, subtotal=priced.subtotal)
        raw.coupon_code = check.coupon.coupon_code
        return await self._guest_out(raw)

    async def remove_coupon(self, ctx: CartContext) -> CartOut:
        if ctx.user is not None:
            cart = await self.repo.get_active(ctx.user.user_id, lock=True)
            if cart is not None and cart.coupon_id is not None:
                await self.repo.set_coupon(cart, None)
                await self.session.commit()
            return await self._user_out(ctx.user)
        raw = self._decode_guest(ctx.token)
        raw.coupon_code = None
        return await self._guest_out(raw)

    # --------------------------------------------------- merge / bulk add
    async def _merge_lines(self, cart: Cart, lines: list[tuple[int, int | None, int, str | None]]) -> tuple[int, list[SkippedLine]]:
        merged = 0
        skipped: list[SkippedLine] = []
        for product_id, variant_id, quantity, name in lines:
            try:
                available = await self._availability(product_id, variant_id)
            except AppException as exc:
                skipped.append(SkippedLine(product_id=product_id, variant_id=variant_id, name=name, reason=exc.message))
                continue
            if available <= 0:
                skipped.append(SkippedLine(product_id=product_id, variant_id=variant_id, name=name, reason="Out of stock"))
                continue
            existing = await self.repo.find_item(cart.cart_id, product_id, variant_id)
            desired = min((existing.quantity if existing else 0) + quantity, MAX_CART_LINE_QTY)
            final = min(desired, available)
            if existing is not None:
                existing.quantity = final
                await self.session.flush()
            else:
                await self.repo.add_item(cart.cart_id, product_id, variant_id, final)
            merged += 1
            if final < desired:
                skipped.append(SkippedLine(product_id=product_id, variant_id=variant_id, name=name,
                                           reason=f"Quantity limited to {final} because of available stock"))
        return merged, skipped

    async def merge(self, user: User, token: str | None) -> CartMergeOut:
        guest = self._decode_guest(token)
        cart = await self.repo.get_or_create(user.user_id, lock=True)
        merged, skipped = await self._merge_lines(cart, [(l.product_id, l.variant_id, l.quantity, None) for l in guest.lines])
        coupon_applied = False
        if guest.coupon_code and cart.coupon_id is None and merged:
            raw = await self._raw_from_cart(cart)
            priced = await self.build(RawCart(lines=raw.lines), user.user_id)
            try:
                check = await self.coupons.evaluate(guest.coupon_code, user_id=user.user_id, subtotal=priced.subtotal)
                await self.repo.set_coupon(cart, check.coupon.coupon_id)
                coupon_applied = True
            except CouponError:
                pass
        await self.session.commit()
        return CartMergeOut(cart=await self._user_out(user), merged_lines=merged, skipped=skipped, coupon_applied=coupon_applied)

    async def bulk_add(self, user: User, entries: list[tuple[int, int | None, int, str | None]]) -> tuple[int, list[SkippedLine]]:
        cart = await self.repo.get_or_create(user.user_id, lock=True)
        merged, skipped = await self._merge_lines(cart, entries)
        await self.session.commit()
        return merged, skipped

    async def current_out(self, user: User) -> CartOut:
        return await self._user_out(user)


def get_cart_service(session: AsyncSession = Depends(get_db)) -> CartService:
    return CartService(session)
