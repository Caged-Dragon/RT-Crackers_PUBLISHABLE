from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from core.constants import (
    ORDER_DELIVERED, REWARD_EXPIRED, REWARD_GRANTED, REWARD_PENDING, REWARD_ROLE_REFEREE, REWARD_ROLE_REFERRER,
)
from customers.auth.models import User
from customers.coupons.models import Coupon
from customers.orders.models import Order
from customers.referrals.models import ReferralReward
from utils.helpers import utcnow

R = ReferralReward


def _relevant(user_id: int):
    """Rewards a user benefits from: their own sign-up reward (E) or rewards for people they referred (R)."""
    referred_ids = select(User.user_id).where(User.referred_by == user_id)
    return or_(and_(R.beneficiary_role == REWARD_ROLE_REFEREE, R.referred_user_id == user_id),
               and_(R.beneficiary_role == REWARD_ROLE_REFERRER, R.referred_user_id.in_(referred_ids)))


class ReferralRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # ----------------------------------------------------------- creation
    async def create_pending_rewards(self, referred_user_id: int, referrer_amount: Any, referee_amount: Any, expires_at: datetime) -> None:
        self.session.add(ReferralReward(referred_user_id=referred_user_id, beneficiary_role=REWARD_ROLE_REFERRER,
                                        reward_amount=Decimal(str(referrer_amount)), status=REWARD_PENDING, expires_at=expires_at))
        self.session.add(ReferralReward(referred_user_id=referred_user_id, beneficiary_role=REWARD_ROLE_REFEREE,
                                        reward_amount=Decimal(str(referee_amount)), status=REWARD_PENDING, expires_at=expires_at))
        await self.session.flush()

    # ------------------------------------------------------ order linkage
    async def attach_qualifying_order(self, user_id: int, order_id: int) -> int:
        """First order of a referred user qualifies both rewards (only while they are still pending and unexpired)."""
        now = utcnow()
        result = await self.session.execute(
            update(R).where(R.referred_user_id == user_id, R.status == REWARD_PENDING, R.qualifying_order_id.is_(None),
                            or_(R.expires_at.is_(None), R.expires_at > now)).values(qualifying_order_id=order_id))
        return int(result.rowcount or 0)

    async def detach_order(self, order_id: int) -> None:
        """A cancelled order no longer qualifies; the user's next order can."""
        await self.session.execute(update(R).where(R.qualifying_order_id == order_id, R.status == REWARD_PENDING)
                                   .values(qualifying_order_id=None))

    async def expire_stale(self, user_id: int) -> None:
        await self.session.execute(
            update(R).where(_relevant(user_id), R.status == REWARD_PENDING, R.qualifying_order_id.is_(None), R.expires_at.is_not(None),
                            R.expires_at < utcnow()).values(status=REWARD_EXPIRED))

    async def grantable(self, user_id: int) -> list[ReferralReward]:
        """Pending rewards whose qualifying order has been delivered; row-locked so two requests cannot grant twice."""
        stmt = (select(R).join(Order, Order.order_id == R.qualifying_order_id)
                .where(_relevant(user_id), R.status == REWARD_PENDING, Order.order_status == ORDER_DELIVERED)
                .order_by(R.referral_reward_id).with_for_update(of=R))
        return list((await self.session.execute(stmt)).scalars())

    async def grantable_for_order(self, order_id: int) -> list[ReferralReward]:
        stmt = (select(R).join(Order, Order.order_id == R.qualifying_order_id)
                .where(R.qualifying_order_id == order_id, R.status == REWARD_PENDING, Order.order_status == ORDER_DELIVERED)
                .order_by(R.referral_reward_id).with_for_update(of=R))
        return list((await self.session.execute(stmt)).scalars())

    async def mint_coupon(self, coupon: Coupon) -> Coupon:
        self.session.add(coupon)
        await self.session.flush()
        return coupon

    async def mark_granted(self, reward: ReferralReward, coupon_id: int) -> None:
        reward.status = REWARD_GRANTED
        reward.coupon_id = coupon_id
        reward.granted_at = utcnow()
        await self.session.flush()

    # -------------------------------------------------------------- reads
    async def rewards_for_user(self, user_id: int) -> list[Any]:
        referred = aliased(User)
        stmt = (select(R, referred.first_name, referred.last_name, Coupon.coupon_code, Coupon.valid_until, Coupon.is_active)
                .join(referred, referred.user_id == R.referred_user_id).outerjoin(Coupon, Coupon.coupon_id == R.coupon_id)
                .where(_relevant(user_id)).order_by(R.created_at.desc(), R.referral_reward_id.desc()))
        return list((await self.session.execute(stmt)).all())

    async def history(self, user_id: int) -> list[Any]:
        referred = aliased(User)
        stmt = (select(referred.user_id, referred.first_name, referred.last_name, referred.created_at, R.status, R.reward_amount,
                       R.qualifying_order_id)
                .outerjoin(R, and_(R.referred_user_id == referred.user_id, R.beneficiary_role == REWARD_ROLE_REFERRER))
                .where(referred.referred_by == user_id).order_by(referred.created_at.desc(), referred.user_id.desc()))
        return list((await self.session.execute(stmt)).all())

    async def referred_count(self, user_id: int) -> int:
        stmt = select(func.count()).select_from(User).where(User.referred_by == user_id)
        return int((await self.session.execute(stmt)).scalar_one())

    async def reward_totals(self, user_id: int) -> dict[str, Decimal]:
        stmt = select(R.status, func.coalesce(func.sum(R.reward_amount), 0)).where(_relevant(user_id)).group_by(R.status)
        return {status: Decimal(total) for status, total in (await self.session.execute(stmt)).all()}

    async def get_user(self, user_id: int) -> User | None:
        return await self.session.get(User, user_id)
