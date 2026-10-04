from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import CART_ABANDONED, CART_ACTIVE, CART_CONVERTED, PRODUCT_ACTIVE
from customers.cart.models import Cart, CartItem
from customers.categories.models import Category
from customers.products.models import Inventory, Product, ProductVariant
from customers.products.repository import _PRIMARY_IMAGE as PRIMARY_IMAGE


@dataclass
class CatalogEntry:
    product: Product
    image: str | None
    category_active: bool


@dataclass
class Catalog:
    products: dict[int, CatalogEntry]
    variants: dict[tuple[int, int], ProductVariant]
    available: dict[tuple[int, int | None], int]


class CartRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # ---------------------------------------------------------------- carts
    async def get_active(self, user_id: int, *, lock: bool = False) -> Cart | None:
        stmt = select(Cart).where(Cart.user_id == user_id, Cart.status == CART_ACTIVE)
        if lock:
            stmt = stmt.with_for_update()
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def get_or_create(self, user_id: int, *, lock: bool = False) -> Cart:
        cart = await self.get_active(user_id, lock=lock)
        if cart is not None:
            return cart
        try:
            async with self.session.begin_nested():
                cart = Cart(user_id=user_id, status=CART_ACTIVE)
                self.session.add(cart)
                await self.session.flush()
            return cart
        except IntegrityError:  # another request created it first (uq_carts_one_active_per_user)
            cart = await self.get_active(user_id, lock=lock)
            if cart is None:
                raise
            return cart

    async def set_coupon(self, cart: Cart, coupon_id: int | None) -> None:
        cart.coupon_id = coupon_id
        await self.session.flush()

    async def set_status(self, cart: Cart, status: str) -> None:
        assert status in (CART_ACTIVE, CART_CONVERTED, CART_ABANDONED)
        cart.status = status
        await self.session.flush()

    # ---------------------------------------------------------------- items
    async def items(self, cart_id: int) -> list[CartItem]:
        stmt = select(CartItem).where(CartItem.cart_id == cart_id).order_by(CartItem.cart_item_id)
        return list((await self.session.execute(stmt)).scalars())

    async def find_item(self, cart_id: int, product_id: int, variant_id: int | None) -> CartItem | None:
        stmt = select(CartItem).where(CartItem.cart_id == cart_id, CartItem.product_id == product_id)
        stmt = stmt.where(CartItem.variant_id == variant_id) if variant_id is not None else stmt.where(CartItem.variant_id.is_(None))
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def add_item(self, cart_id: int, product_id: int, variant_id: int | None, quantity: int) -> CartItem:
        item = CartItem(cart_id=cart_id, product_id=product_id, variant_id=variant_id, quantity=quantity)
        self.session.add(item)
        await self.session.flush()
        return item

    async def delete_item(self, item: CartItem) -> None:
        await self.session.delete(item)
        await self.session.flush()

    async def clear_items(self, cart_id: int) -> None:
        await self.session.execute(delete(CartItem).where(CartItem.cart_id == cart_id))

    # -------------------------------------------------------------- catalog
    async def catalog(self, keys: set[tuple[int, int | None]]) -> Catalog:
        """One round-trip each for products, variants and stock for every (product, variant) pair."""
        product_ids = sorted({p for p, _ in keys})
        if not product_ids:
            return Catalog({}, {}, {})
        rows = (await self.session.execute(
            select(Product, PRIMARY_IMAGE.label("image"), Category.is_active)
            .join(Category, Category.category_id == Product.category_id)
            .where(Product.product_id.in_(product_ids), Product.status == PRODUCT_ACTIVE))).all()
        products = {r.Product.product_id: CatalogEntry(r.Product, r.image, bool(r.is_active)) for r in rows}

        variant_ids = sorted({v for _, v in keys if v is not None})
        variants: dict[tuple[int, int], ProductVariant] = {}
        if variant_ids:
            vrows = (await self.session.execute(
                select(ProductVariant).where(ProductVariant.product_id.in_(product_ids), ProductVariant.variant_id.in_(variant_ids),
                                             ProductVariant.is_active.is_(True)))).scalars()
            variants = {(v.product_id, v.variant_id): v for v in vrows}

        inv = (await self.session.execute(
            select(Inventory.product_id, Inventory.variant_id, func.sum(Inventory.quantity_on_hand - Inventory.reserved_quantity))
            .where(Inventory.product_id.in_(product_ids)).group_by(Inventory.product_id, Inventory.variant_id))).all()
        available = {(p, v): max(int(q or 0), 0) for p, v, q in inv}
        return Catalog(products, variants, available)

    async def user_cart_summary(self, user_id: int) -> tuple[int, int]:
        """(line_count, unit_count) of the active cart — cheap, used by the dashboard."""
        stmt = (select(func.count(CartItem.cart_item_id), func.coalesce(func.sum(CartItem.quantity), 0))
                .join(Cart, Cart.cart_id == CartItem.cart_id).where(Cart.user_id == user_id, Cart.status == CART_ACTIVE))
        row = (await self.session.execute(stmt)).one()
        return int(row[0]), int(row[1])
