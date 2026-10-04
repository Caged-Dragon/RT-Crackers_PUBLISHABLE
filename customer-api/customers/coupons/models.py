from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Identity, Integer, Numeric, SmallInteger, String, func, text
from sqlalchemy.dialects.postgresql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class Coupon(Base, TimestampMixin):
    __tablename__ = "coupons"
    coupon_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    coupon_code: Mapped[str] = mapped_column(String(30), unique=True)
    description: Mapped[str | None] = mapped_column(String(255))
    discount_type: Mapped[str] = mapped_column(CHAR(1))  # P percentage, F flat
    discount_percentage: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    discount_amount: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    max_discount_amount: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    min_order_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), server_default=text("0"))
    usage_limit: Mapped[int | None] = mapped_column(Integer)
    usage_limit_per_user: Mapped[int] = mapped_column(SmallInteger, server_default=text("1"))
    valid_from: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    valid_until: Mapped[datetime] = mapped_column(DateTime)
    first_order_only: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))
    created_by: Mapped[int | None] = mapped_column(Integer)


class CouponUsage(Base, TimestampMixin):
    __tablename__ = "coupon_usage"
    coupon_usage_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    order_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("orders.order_id"), unique=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    coupon_id: Mapped[int] = mapped_column(Integer, ForeignKey("coupons.coupon_id"))
    discount_applied: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    status: Mapped[str] = mapped_column(CHAR(1), server_default="A")  # A applied, R reversed
