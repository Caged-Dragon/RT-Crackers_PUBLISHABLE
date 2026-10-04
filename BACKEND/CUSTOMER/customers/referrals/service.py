from __future__ import annotations

import logging
from datetime import timedelta
from decimal import Decimal

from fastapi import BackgroundTasks, Depends
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.constants import (
    COUPON_FLAT, FLAG_REFERRAL, PERSONAL_COUPON_PREFIX, REWARD_EXPIRED, REWARD_GRANTED, REWARD_PENDING, REWARD_ROLE_REFEREE,
    REWARD_STATUS_LABELS, SETTING_REFEREE_REWARD, SETTING_REFERRER_REWARD,
)
from core.database import get_db
from core.system_models import get_setting, is_feature_enabled
from customers.auth.models import User
from customers.coupons.models import Coupon
from customers.notifications.service import NotificationService
from customers.referrals.models import ReferralReward
from customers.referrals.repository import ReferralRepository
from customers.referrals.schemas import ReferralCodeOut, ReferralHistoryItem, ReferralStats, RewardOut
from utils.email import safe_send_template_email
from utils.helpers import mask_name, random_code, utcnow

logger = logging.getLogger("rtcrackers.referrals")


class ReferralService:
    def __init__(self, session: AsyncSession, background: BackgroundTasks | None = None):
        self.session = session
        self.repo = ReferralRepository(session)
        self.bg = background

    # ---------------------------------------------------- order hooks
    async def on_order_placed(self, user_id: int, order_id: int, *, is_first_order: bool) -> None:
        if is_first_order:
            await self.repo.attach_qualifying_order(user_id, order_id)

    async def on_order_cancelled(self, order_id: int) -> None:
        await self.repo.detach_order(order_id)

    # --------------------------------------------------------- granting
    async def _grant(self, reward: ReferralReward) -> tuple[User | None, Coupon | None]:
        """Mints a single-use personal coupon for the reward; returns (beneficiary, coupon)."""
        referred = await self.repo.get_user(reward.referred_user_id)
        if referred is None:
            return None, None
        beneficiary = referred if reward.beneficiary_role == REWARD_ROLE_REFEREE else (
            await self.repo.get_user(referred.referred_by) if referred.referred_by else None)
        if beneficiary is None:
            return None, None
        now = utcnow()
        coupon: Coupon | None = None
        for _ in range(5):
            code = f"{PERSONAL_COUPON_PREFIX}{random_code(10)}"
            try:
                async with self.session.begin_nested():
                    coupon = await self.repo.mint_coupon(Coupon(
                        coupon_code=code, description="Referral reward", discount_type=COUPON_FLAT, discount_amount=reward.reward_amount,
                        min_order_amount=Decimal("0"), usage_limit=1, usage_limit_per_user=1, valid_from=now,
                        valid_until=now + timedelta(days=settings.REFERRAL_REWARD_VALID_DAYS), first_order_only=False, is_active=True))
                break
            except IntegrityError:
                coupon = None
        if coupon is None:
            logger.error("Could not mint a unique reward coupon for reward %s", reward.referral_reward_id)
            return beneficiary, None
        await self.repo.mark_granted(reward, coupon.coupon_id)
        return beneficiary, coupon

    async def _grant_many(self, rewards: list[ReferralReward]) -> None:
        for reward in rewards:
            beneficiary, coupon = await self._grant(reward)
            if beneficiary is None or coupon is None:
                continue
            title = "Your referral reward is ready"
            message = f"You earned a reward of \u20b9{reward.reward_amount:.0f}. Use coupon {coupon.coupon_code} on your next order."
            deliveries = await NotificationService(self.session, self.bg).create(
                beneficiary, "S", title, message, reference_type="referral_reward", reference_id=reward.referral_reward_id,
                email_template="REFERRAL_REWARD",
                email_context={"amount": f"{reward.reward_amount:.0f}", "coupon_code": coupon.coupon_code,
                               "valid_until": coupon.valid_until.strftime("%d %b %Y")})
            self._deliveries = getattr(self, "_deliveries", []) + deliveries
        await self.session.commit()
        if self.bg is not None and getattr(self, "_deliveries", None):
            NotificationService(self.session, self.bg).schedule(self._deliveries)
            self._deliveries = []

    async def sync(self, user: User) -> None:
        """Lazy settlement: grants rewards whose qualifying order was delivered and expires stale ones."""
        await self.repo.expire_stale(user.user_id)
        rewards = await self.repo.grantable(user.user_id)
        if rewards:
            await self._grant_many(rewards)
        else:
            await self.session.commit()

    async def grant_for_delivered_order(self, order_id: int) -> None:
        """Entry point for back-office tooling that marks an order delivered."""
        rewards = await self.repo.grantable_for_order(order_id)
        if rewards:
            await self._grant_many(rewards)

    # ------------------------------------------------------------ reads
    async def code(self, user: User) -> ReferralCodeOut:
        enabled = await is_feature_enabled(self.session, FLAG_REFERRAL)
        referrer = Decimal(str(await get_setting(self.session, SETTING_REFERRER_REWARD, settings.REFERRAL_REFERRER_REWARD)))
        referee = Decimal(str(await get_setting(self.session, SETTING_REFEREE_REWARD, settings.REFERRAL_REFEREE_REWARD)))
        return ReferralCodeOut(
            referral_code=user.referral_code, share_link=f"{settings.FRONTEND_URL.rstrip('/')}/register?ref={user.referral_code}",
            program_enabled=enabled, referrer_reward=referrer, referee_reward=referee, reward_valid_days=settings.REFERRAL_REWARD_VALID_DAYS,
            how_it_works=[
                "Share your referral code or link with a friend.",
                "They sign up with your code and place their first order.",
                f"Once that order is delivered, you get \u20b9{referrer:.0f} and they get \u20b9{referee:.0f} as personal coupons.",
            ])

    async def history(self, user: User) -> list[ReferralHistoryItem]:
        await self.sync(user)
        items = []
        for row in await self.repo.history(user.user_id):
            items.append(ReferralHistoryItem(
                referred_user_id=row.user_id, name=mask_name(row.first_name, row.last_name), joined_at=row.created_at,
                has_qualifying_order=row.qualifying_order_id is not None, reward_status=row.status,
                reward_status_label=REWARD_STATUS_LABELS.get(row.status) if row.status else None, reward_amount=row.reward_amount))
        return items

    async def rewards(self, user: User) -> list[RewardOut]:
        await self.sync(user)
        out = []
        for row in await self.repo.rewards_for_user(user.user_id):
            reward: ReferralReward = row.ReferralReward
            is_referee = reward.beneficiary_role == REWARD_ROLE_REFEREE
            out.append(RewardOut(
                referral_reward_id=reward.referral_reward_id, role=reward.beneficiary_role,
                role_label="signup bonus" if is_referee else "referrer reward", reward_amount=reward.reward_amount, status=reward.status,
                status_label=REWARD_STATUS_LABELS.get(reward.status, "pending"),
                for_referred_user="you" if is_referee else mask_name(row.first_name, row.last_name),
                coupon_code=row.coupon_code if reward.status == REWARD_GRANTED else None,
                coupon_valid_until=row.valid_until if reward.status == REWARD_GRANTED else None, granted_at=reward.granted_at,
                expires_at=reward.expires_at))
        return out

    async def stats(self, user: User, *, sync: bool = True) -> ReferralStats:
        if sync:
            await self.sync(user)
        rewards = await self.repo.rewards_for_user(user.user_id)
        counts = {REWARD_PENDING: 0, REWARD_GRANTED: 0, REWARD_EXPIRED: 0}
        for row in rewards:
            counts[row.ReferralReward.status] = counts.get(row.ReferralReward.status, 0) + 1
        totals = await self.repo.reward_totals(user.user_id)
        return ReferralStats(
            referral_code=user.referral_code, total_referred=await self.repo.referred_count(user.user_id),
            pending_rewards=counts[REWARD_PENDING], granted_rewards=counts[REWARD_GRANTED], expired_rewards=counts[REWARD_EXPIRED],
            pending_amount=totals.get(REWARD_PENDING, Decimal("0")), granted_amount=totals.get(REWARD_GRANTED, Decimal("0")))


def get_referral_service(background: BackgroundTasks, session: AsyncSession = Depends(get_db)) -> ReferralService:
    return ReferralService(session, background)
