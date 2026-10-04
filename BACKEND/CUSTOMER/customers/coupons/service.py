from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import COUPON_FLAT, COUPON_PERCENT, COUPON_USAGE_APPLIED, PERSONAL_COUPON_PREFIX
from core.database import get_db
from core.exceptions import UnprocessableError
from core.schemas import Page
from customers.auth.models import User
from customers.coupons.models import Coupon
from customers.coupons.repository import CouponRepository
from customers.coupons.schemas import CouponOut, CouponUsageOut, CouponValidation
from utils.helpers import utcnow
from utils.pagination import PageParams, paginate
from utils.pricing import ZERO, compute_coupon_discount, q2


class CouponError(UnprocessableError):
    """Raised for every business-rule rejection so callers can show the exact reason."""


@dataclass
class CouponCheck:
    coupon: Coupon
    discount: Decimal


def _money(value: Decimal | None) -> str:
    if value is None:
        return "0"
    text = f"{value:,.2f}"
    return text[:-3] if text.endswith(".00") else text


def headline(c: Coupon) -> str:
    if c.discount_type == COUPON_PERCENT:
        pct = f"{c.discount_percentage:.2f}".rstrip("0").rstrip(".")
        text = f"{pct}% off"
        if c.max_discount_amount is not None:
            text += f" up to \u20b9{_money(c.max_discount_amount)}"
    else:
        text = f"\u20b9{_money(c.discount_amount)} off"
    if c.min_order_amount and c.min_order_amount > 0:
        text += f" on orders above \u20b9{_money(c.min_order_amount)}"
    return text


def to_coupon_out(c: Coupon) -> CouponOut:
    return CouponOut(
        coupon_id=c.coupon_id, code=c.coupon_code, description=c.description, discount_type=c.discount_type,
        discount_type_label="percentage" if c.discount_type == COUPON_PERCENT else "flat", discount_percentage=c.discount_percentage,
        discount_amount=c.discount_amount, max_discount_amount=c.max_discount_amount, min_order_amount=c.min_order_amount,
        valid_from=c.valid_from, valid_until=c.valid_until, first_order_only=c.first_order_only, headline=headline(c))


class CouponService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = CouponRepository(session)

    # ------------------------------------------------------------ rules
    async def evaluate(self, code: str, *, user_id: int | None, subtotal: Decimal, lock: bool = False) -> CouponCheck:
        """Applies every coupon rule. `user_id=None` (guest) skips only the rules that need an account."""
        coupon = await self.repo.get_by_code(code, lock=lock)
        if coupon is None:
            raise CouponError("This coupon code does not exist", code="coupon_not_found")
        return await self.evaluate_loaded(coupon, user_id=user_id, subtotal=subtotal)

    async def evaluate_loaded(self, coupon: Coupon, *, user_id: int | None, subtotal: Decimal) -> CouponCheck:
        now = utcnow()
        if not coupon.is_active:
            raise CouponError("This coupon is no longer active", code="coupon_inactive")
        if now < coupon.valid_from:
            raise CouponError("This coupon is not valid yet", code="coupon_not_started")
        if now > coupon.valid_until:
            raise CouponError("This coupon has expired", code="coupon_expired")
        if coupon.coupon_code.startswith(PERSONAL_COUPON_PREFIX):
            if user_id is None:
                raise CouponError("Please log in to use this reward coupon", code="coupon_login_required")
            if await self.repo.personal_beneficiary(coupon.coupon_id) != user_id:
                raise CouponError("This coupon is not valid for your account", code="coupon_not_applicable")
        if subtotal < coupon.min_order_amount:
            shortfall = coupon.min_order_amount - subtotal
            raise CouponError(f"Add items worth \u20b9{_money(shortfall)} more to use this coupon", code="coupon_min_order",
                              details={"min_order_amount": float(coupon.min_order_amount), "shortfall": float(shortfall)})
        if coupon.usage_limit is not None and await self.repo.total_usage(coupon.coupon_id) >= coupon.usage_limit:
            raise CouponError("This coupon has reached its usage limit", code="coupon_exhausted")
        if user_id is not None:
            if await self.repo.user_usage(coupon.coupon_id, user_id) >= coupon.usage_limit_per_user:
                raise CouponError("You have already used this coupon", code="coupon_already_used")
            if coupon.first_order_only and await self.repo.user_has_prior_orders(user_id):
                raise CouponError("This coupon is only valid on your first order", code="coupon_first_order_only")
        discount = compute_coupon_discount(discount_type=coupon.discount_type, percentage=coupon.discount_percentage,
                                           amount=coupon.discount_amount, max_discount=coupon.max_discount_amount, subtotal=subtotal)
        if discount <= ZERO:
            raise CouponError("This coupon does not give a discount on your cart", code="coupon_no_discount")
        return CouponCheck(coupon=coupon, discount=q2(discount))

    # --------------------------------------------------------- endpoints
    async def available(self, user: User | None) -> list[CouponOut]:
        coupons = await self.repo.list_public(utcnow())
        counts = await self.repo.usage_counts([c.coupon_id for c in coupons if c.usage_limit is not None])
        visible: list[Coupon] = []
        for c in coupons:
            if c.usage_limit is not None and counts.get(c.coupon_id, 0) >= c.usage_limit:
                continue
            if user is not None:
                if await self.repo.user_usage(c.coupon_id, user.user_id) >= c.usage_limit_per_user:
                    continue
                if c.first_order_only and await self.repo.user_has_prior_orders(user.user_id):
                    continue
            visible.append(c)
        return [to_coupon_out(c) for c in visible]

    async def validate(self, user: User | None, code: str, order_amount: Decimal) -> CouponValidation:
        try:
            check = await self.evaluate(code, user_id=user.user_id if user else None, subtotal=order_amount)
        except CouponError as exc:
            return CouponValidation(valid=False, code=code, message=exc.message, reason_code=exc.code, order_amount=q2(order_amount))
        return CouponValidation(valid=True, code=code, message=f"Coupon applied: {headline(check.coupon)}", discount_amount=check.discount,
                                order_amount=q2(order_amount), coupon=to_coupon_out(check.coupon))

    async def usage_history(self, user: User, page: PageParams) -> Page[CouponUsageOut]:
        rows, total = await self.repo.usage_page(user.user_id, page)
        items = [CouponUsageOut(coupon_usage_id=u.coupon_usage_id, order_id=u.order_id, order_number=number, coupon_code=code,
                                discount_applied=u.discount_applied, status=u.status,
                                status_label="applied" if u.status == COUPON_USAGE_APPLIED else "reversed", used_at=u.created_at)
                 for u, number, code in rows]
        return paginate(items, total, page)


def get_coupon_service(session: AsyncSession = Depends(get_db)) -> CouponService:
    return CouponService(session)
