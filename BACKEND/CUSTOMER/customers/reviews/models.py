from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, Boolean, Computed, DateTime, ForeignKey, Identity, Integer, SmallInteger, String, Text, func, text
from sqlalchemy.dialects.postgresql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class Review(Base, TimestampMixin):
    __tablename__ = "reviews"
    review_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"))
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    order_item_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("order_items.order_item_id"), unique=True)
    rating: Mapped[int] = mapped_column(SmallInteger)
    title: Mapped[str | None] = mapped_column(String(150))
    review_text: Mapped[str | None] = mapped_column(Text)
    verified_purchase: Mapped[bool] = mapped_column(Boolean, Computed("order_item_id IS NOT NULL", persisted=True))
    helpful_count: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    reported_count: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    status: Mapped[str] = mapped_column(CHAR(1), server_default="P")


class ReviewImage(Base):
    __tablename__ = "review_images"
    review_image_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    review_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("reviews.review_id"))
    image_url: Mapped[str] = mapped_column(String(500))
    display_order: Mapped[int] = mapped_column(SmallInteger, server_default=text("0"))
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class ReviewReport(Base, TimestampMixin):
    __tablename__ = "review_reports"
    report_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    review_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("reviews.review_id"))
    reported_by: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    reason_code: Mapped[str] = mapped_column(CHAR(1))
    description: Mapped[str | None] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(CHAR(1), server_default="P")
    reviewed_by: Mapped[int | None] = mapped_column(Integer)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime)
