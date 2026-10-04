"""Auth tables: users, roles, sessions, refresh tokens, login history, password reset (+ verification_codes)."""
from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import BigInteger, Boolean, Date, DateTime, ForeignKey, Identity, Integer, SmallInteger, String, func, text
from sqlalchemy.dialects.postgresql import CHAR, INET, UUID
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class Role(Base, TimestampMixin):
    __tablename__ = "roles"
    role_id: Mapped[int] = mapped_column(SmallInteger, Identity(always=True), primary_key=True)
    role_code: Mapped[str] = mapped_column(String(30), unique=True)
    role_name: Mapped[str] = mapped_column(String(60), unique=True)
    role_scope: Mapped[str] = mapped_column(CHAR(1), default="U")
    description: Mapped[str | None] = mapped_column(String(255))
    is_system: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class User(Base, TimestampMixin):
    __tablename__ = "users"
    user_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    phone: Mapped[str] = mapped_column(CHAR(10), unique=True)
    first_name: Mapped[str] = mapped_column(String(60))
    middle_name: Mapped[str | None] = mapped_column(String(60))
    last_name: Mapped[str | None] = mapped_column(String(60))
    gender: Mapped[str | None] = mapped_column(CHAR(1))
    dob: Mapped[date | None] = mapped_column(Date)
    profile_image: Mapped[str | None] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(CHAR(1), server_default="A")
    email_verified: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    phone_verified: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    failed_login_count: Mapped[int] = mapped_column(SmallInteger, server_default=text("0"))
    account_locked: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    last_login: Mapped[datetime | None] = mapped_column(DateTime)
    last_password_change: Mapped[datetime | None] = mapped_column(DateTime)
    preferred_language: Mapped[str] = mapped_column(CHAR(2), server_default="en")
    preferred_currency: Mapped[str] = mapped_column(CHAR(3), server_default="INR")
    referral_code: Mapped[str] = mapped_column(String(12), unique=True, server_default=text("''"))
    referred_by: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("users.user_id"))

    @property
    def full_name(self) -> str:
        return " ".join(p for p in (self.first_name, self.middle_name, self.last_name) if p)


class UserRole(Base, TimestampMixin):
    __tablename__ = "user_roles"
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"), primary_key=True)
    role_id: Mapped[int] = mapped_column(SmallInteger, ForeignKey("roles.role_id"), primary_key=True)
    assigned_by: Mapped[int | None] = mapped_column(BigInteger)


class UserSession(Base, TimestampMixin):
    __tablename__ = "sessions"
    session_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    ip_address: Mapped[str | None] = mapped_column(INET)
    user_agent: Mapped[str | None] = mapped_column(String(500))
    device_type: Mapped[str] = mapped_column(CHAR(1), default="W")
    last_activity_at: Mapped[datetime | None] = mapped_column(DateTime)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime)


class RefreshToken(Base, TimestampMixin):
    __tablename__ = "refresh_tokens"
    refresh_token_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    session_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("sessions.session_id"))
    token_hash: Mapped[str] = mapped_column(String(255), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime)
    replaced_by_token_id: Mapped[int | None] = mapped_column(BigInteger)


class LoginHistory(Base):
    __tablename__ = "login_history"
    login_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    user_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    attempted_email: Mapped[str] = mapped_column(String(255))
    login_status: Mapped[str] = mapped_column(CHAR(1))  # S success, F failed, L blocked by lock
    failure_reason: Mapped[str | None] = mapped_column(String(100))
    ip_address: Mapped[str | None] = mapped_column(INET)
    user_agent: Mapped[str | None] = mapped_column(String(500))
    session_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"
    token_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    token_hash: Mapped[str] = mapped_column(String(255), unique=True)
    requested_ip: Mapped[str | None] = mapped_column(INET)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    used_at: Mapped[datetime | None] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class VerificationCode(Base):
    """The only table this project adds (migration 0002): hashed one-time codes with attempt counting.
    The existing schema has no OTP storage, and OTP attempts must be tracked server-side to be brute-force safe."""
    __tablename__ = "verification_codes"
    code_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    purpose: Mapped[str] = mapped_column(CHAR(1), default="P")  # P = phone verification
    target: Mapped[str] = mapped_column(String(255))
    code_hash: Mapped[str] = mapped_column(String(255))
    attempts: Mapped[int] = mapped_column(SmallInteger, default=0)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
