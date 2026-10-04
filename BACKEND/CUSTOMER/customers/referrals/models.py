from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import BigInteger, DateTime, ForeignKey, Identity, Integer, Numeric
from sqlalchemy.dialects.postgresql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class ReferralReward(Base, TimestampMixin):
    __tablename__ = "referral_rewards"
    referral_reward_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    referred_user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    beneficiary_role: Mapped[str] = mapped_column(CHAR(1))  # R referrer, E referee
    qualifying_order_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("orders.order_id"))
    reward_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    coupon_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("coupons.coupon_id"))
    status: Mapped[str] = mapped_column(CHAR(1), server_default="P")  # P pending, G granted, X expired
    granted_at: Mapped[datetime | None] = mapped_column(DateTime)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime)
