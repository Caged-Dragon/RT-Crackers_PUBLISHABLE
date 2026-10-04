from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, String, Text, text
from sqlalchemy.dialects.postgresql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class UserProfile(Base, TimestampMixin):
    __tablename__ = "user_profiles"
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"), primary_key=True)
    display_name: Mapped[str | None] = mapped_column(String(100))
    bio: Mapped[str | None] = mapped_column(Text)
    alternate_phone: Mapped[str | None] = mapped_column(CHAR(10))
    whatsapp_number: Mapped[str | None] = mapped_column(CHAR(10))
    occupation: Mapped[str | None] = mapped_column(String(80))
    timezone: Mapped[str] = mapped_column(String(50), server_default="Asia/Kolkata")
    age_verified: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    age_verified_at: Mapped[datetime | None] = mapped_column(DateTime)
    email_opt_in: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))
    sms_opt_in: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))
    whatsapp_opt_in: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
