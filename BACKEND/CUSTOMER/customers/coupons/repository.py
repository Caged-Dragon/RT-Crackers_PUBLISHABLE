from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import exists, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import COUPON_USAGE_APPLIED, COUPON_USAGE_REVERSED, ORDER_CANCELLED, PERSONAL_COUPON_PREFIX
from customers.auth.models import User
from customers.coupons.models import Coupon, CouponUsage
from customers.orders.models import Order
from customers.referrals.models import ReferralReward
from utils.pagination import PageParams


class CouponRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_code(self, code: str, *, lock: bool = False) -> Coupon | None:
        stmt = select(Coupon).where(Coupon.coupon_code == code)
        if lock:
            stmt = stmt.with_for_update()
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def get(self, coupon_id: int, *, lock: bool = False) -> Coupon | None:
        stmt = select(Coupon).where(Coupon.coupon_id == coupon_id)
        if lock:
            stmt = stmt.with_for_update()
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def list_public(self, now: datetime) -> list[Coupon]:
        """Active, in-window, non-personal coupons ordered by soonest expiry."""
        stmt = (select(Coupon).where(Coupon.is_active.is_(True), Coupon.valid_from <= now, Coupon.valid_until >= now,
                                     ~Coupon.coupon_code.like(f"{PERSONAL_COUPON_PREFIX}%"))
                .order_by(Coupon.valid_until, Coupon.coupon_id))
        return list((await self.session.execute(stmt)).scalars())

    async def total_usage(self, coupon_id: int) -> int:
        stmt = select(func.count()).select_from(CouponUsage).where(CouponUsage.coupon_id == coupon_id, CouponUsage.status == COUPON_USAGE_APPLIED)
        return int((await self.session.execute(stmt)).scalar_one())

    async def usage_counts(self, coupon_ids: list[int]) -> dict[int, int]:
        if not coupon_ids:
            return {}
        stmt = (select(CouponUsage.coupon_id, func.count()).where(CouponUsage.coupon_id.in_(coupon_ids), CouponUsage.status == COUPON_USAGE_APPLIED)
                .group_by(CouponUsage.coupon_id))
        return {cid: int(n) for cid, n in (await self.session.execute(stmt)).all()}

    async def user_usage(self, coupon_id: int, user_id: int) -> int:
        stmt = select(func.count()).select_from(CouponUsage).where(
            CouponUsage.coupon_id == coupon_id, CouponUsage.user_id == user_id, CouponUsage.status == COUPON_USAGE_APPLIED)
        return int((await self.session.execute(stmt)).scalar_one())

    async def user_has_prior_orders(self, user_id: int) -> bool:
        stmt = select(exists().where(Order.user_id == user_id, Order.order_status != ORDER_CANCELLED))
        return bool((await self.session.execute(stmt)).scalar())

    async def personal_beneficiary(self, coupon_id: int) -> int | None:
        """Who a referral-reward coupon belongs to (referee for role E, the referrer for role R)."""
        stmt = (select(ReferralReward.beneficiary_role, ReferralReward.referred_user_id, User.referred_by)
                .join(User, User.user_id == ReferralReward.referred_user_id).where(ReferralReward.coupon_id == coupon_id))
        row = (await self.session.execute(stmt)).first()
        if row is None:
            return None
        return row.referred_user_id if row.beneficiary_role == "E" else row.referred_by

    async def add_usage(self, *, order_id: int, user_id: int, coupon_id: int, discount: Decimal) -> CouponUsage:
        usage = CouponUsage(order_id=order_id, user_id=user_id, coupon_id=coupon_id, discount_applied=discount, status=COUPON_USAGE_APPLIED)
        self.session.add(usage)
        await self.session.flush()
        return usage

    async def reverse_usage(self, order_id: int) -> None:
        await self.session.execute(update(CouponUsage).where(CouponUsage.order_id == order_id, CouponUsage.status == COUPON_USAGE_APPLIED)
                                   .values(status=COUPON_USAGE_REVERSED))

    async def usage_page(self, user_id: int, page: PageParams) -> tuple[list[Any], int]:
        base = (select(CouponUsage, Order.order_number, Coupon.coupon_code)
                .join(Order, Order.order_id == CouponUsage.order_id).join(Coupon, Coupon.coupon_id == CouponUsage.coupon_id)
                .where(CouponUsage.user_id == user_id))
        total = int((await self.session.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
        rows = (await self.session.execute(base.order_by(CouponUsage.created_at.desc(), CouponUsage.coupon_usage_id.desc())
                                           .limit(page.limit).offset(page.offset))).all()
        return list(rows), total
