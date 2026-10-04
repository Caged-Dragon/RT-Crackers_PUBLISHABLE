from __future__ import annotations

from datetime import datetime

from core.schemas import BaseSchema, Money


class ReferralCodeOut(BaseSchema):
    referral_code: str
    share_link: str
    program_enabled: bool
    referrer_reward: Money
    referee_reward: Money
    reward_valid_days: int
    how_it_works: list[str]


class ReferralHistoryItem(BaseSchema):
    referred_user_id: int
    name: str
    joined_at: datetime
    has_qualifying_order: bool
    reward_status: str | None = None
    reward_status_label: str | None = None
    reward_amount: Money | None = None


class RewardOut(BaseSchema):
    referral_reward_id: int
    role: str
    role_label: str
    reward_amount: Money
    status: str
    status_label: str
    for_referred_user: str
    coupon_code: str | None = None
    coupon_valid_until: datetime | None = None
    granted_at: datetime | None = None
    expires_at: datetime | None = None


class ReferralStats(BaseSchema):
    referral_code: str
    total_referred: int
    pending_rewards: int
    granted_rewards: int
    expired_rewards: int
    pending_amount: Money
    granted_amount: Money
