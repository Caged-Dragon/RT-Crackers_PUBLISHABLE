from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Identity, Integer, String, Text, text
from sqlalchemy.dialects.postgresql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class Notification(Base, TimestampMixin):
    __tablename__ = "notifications"
    notification_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    template_id: Mapped[int | None] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(150))
    message: Mapped[str] = mapped_column(Text)
    notification_type: Mapped[str] = mapped_column(CHAR(1), server_default="S")  # O order, P promotion, S system, F festival
    reference_type: Mapped[str | None] = mapped_column(String(40))
    reference_id: Mapped[str | None] = mapped_column(String(64))
    expires_at: Mapped[datetime | None] = mapped_column(DateTime)
    created_by: Mapped[int | None] = mapped_column(Integer)


class UserNotification(Base, TimestampMixin):
    __tablename__ = "user_notifications"
    user_notification_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    notification_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("notifications.notification_id"))
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    channel: Mapped[str] = mapped_column(CHAR(1), server_default="A")  # A in-app, E email, S SMS, W WhatsApp
    delivery_status: Mapped[str] = mapped_column(CHAR(1), server_default="Q")  # Q queued, S sent, F failed
    is_read: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    read_at: Mapped[datetime | None] = mapped_column(DateTime)
