from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from customers.auth.models import (
    LoginHistory, PasswordResetToken, RefreshToken, Role, User, UserRole, UserSession, VerificationCode,
)
from customers.profiles.models import UserProfile
from utils.helpers import utcnow


class AuthRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # ----------------------------------------------------------------- users
    async def get_user(self, user_id: int) -> User | None:
        return await self.session.get(User, user_id)

    async def get_user_by_email(self, email: str) -> User | None:
        return (await self.session.execute(select(User).where(User.email == email.lower()))).scalar_one_or_none()

    async def get_user_by_phone(self, phone: str) -> User | None:
        return (await self.session.execute(select(User).where(User.phone == phone))).scalar_one_or_none()

    async def get_user_by_referral_code(self, code: str) -> User | None:
        return (await self.session.execute(select(User).where(User.referral_code == code))).scalar_one_or_none()

    async def add_user(self, user: User) -> User:
        self.session.add(user)
        await self.session.flush()
        return user

    async def ensure_profile(self, user_id: int) -> UserProfile:
        profile = await self.session.get(UserProfile, user_id)
        if profile is None:
            profile = UserProfile(user_id=user_id)
            self.session.add(profile)
            await self.session.flush()
        return profile

    async def assign_customer_role(self, user_id: int, role_code: str) -> None:
        role_id = (await self.session.execute(select(Role.role_id).where(Role.role_code == role_code))).scalar_one_or_none()
        if role_id is not None:
            self.session.add(UserRole(user_id=user_id, role_id=role_id))
            await self.session.flush()

    # -------------------------------------------------------------- sessions
    async def create_session(self, *, user_id: int, ip: str | None, ua: str | None, device: str, expires_at: datetime) -> UserSession:
        row = UserSession(session_id=uuid.uuid4(), user_id=user_id, ip_address=ip, user_agent=ua, device_type=device,
                          last_activity_at=utcnow(), expires_at=expires_at)
        self.session.add(row)
        await self.session.flush()
        return row

    async def get_session(self, session_id: uuid.UUID) -> UserSession | None:
        return await self.session.get(UserSession, session_id)

    async def end_session(self, session_id: uuid.UUID) -> None:
        now = utcnow()
        await self.session.execute(update(UserSession).where(UserSession.session_id == session_id, UserSession.ended_at.is_(None)).values(ended_at=now))
        await self.session.execute(update(RefreshToken).where(RefreshToken.session_id == session_id, RefreshToken.revoked_at.is_(None)).values(revoked_at=now))

    async def end_all_sessions(self, user_id: int) -> None:
        now = utcnow()
        await self.session.execute(update(UserSession).where(UserSession.user_id == user_id, UserSession.ended_at.is_(None)).values(ended_at=now))
        await self.session.execute(update(RefreshToken).where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None)).values(revoked_at=now))

    # --------------------------------------------------------- refresh tokens
    async def add_refresh_token(self, *, user_id: int, session_id: uuid.UUID, token_hash: str, expires_at: datetime) -> RefreshToken:
        row = RefreshToken(user_id=user_id, session_id=session_id, token_hash=token_hash, expires_at=expires_at)
        self.session.add(row)
        await self.session.flush()
        return row

    async def get_refresh_token(self, token_hash: str) -> RefreshToken | None:
        return (await self.session.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash).with_for_update())).scalar_one_or_none()

    # ---------------------------------------------------------- login history
    async def add_login_history(self, *, user_id: int | None, email: str, status: str, reason: str | None,
                                ip: str | None, ua: str | None, session_id: uuid.UUID | None = None) -> None:
        self.session.add(LoginHistory(user_id=user_id, attempted_email=email[:255], login_status=status, failure_reason=reason,
                                      ip_address=ip, user_agent=ua, session_id=session_id))
        await self.session.flush()

    # ----------------------------------------------------------- password reset
    async def add_reset_token(self, *, user_id: int, token_hash: str, ip: str | None, expires_at: datetime) -> None:
        self.session.add(PasswordResetToken(user_id=user_id, token_hash=token_hash, requested_ip=ip, expires_at=expires_at))
        await self.session.flush()

    async def get_reset_token(self, token_hash: str) -> PasswordResetToken | None:
        return (await self.session.execute(select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash).with_for_update())).scalar_one_or_none()

    async def invalidate_reset_tokens(self, user_id: int) -> None:
        await self.session.execute(update(PasswordResetToken).where(PasswordResetToken.user_id == user_id, PasswordResetToken.used_at.is_(None)).values(used_at=utcnow()))

    # -------------------------------------------------------------------- OTP
    async def latest_active_code(self, user_id: int, purpose: str = "P") -> VerificationCode | None:
        stmt = (select(VerificationCode)
                .where(VerificationCode.user_id == user_id, VerificationCode.purpose == purpose, VerificationCode.consumed_at.is_(None),
                       VerificationCode.expires_at > utcnow())
                .order_by(VerificationCode.created_at.desc()).limit(1).with_for_update())
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def consume_codes(self, user_id: int, purpose: str = "P") -> None:
        await self.session.execute(update(VerificationCode).where(VerificationCode.user_id == user_id, VerificationCode.purpose == purpose,
                                                                 VerificationCode.consumed_at.is_(None)).values(consumed_at=utcnow()))

    async def add_code(self, *, user_id: int, target: str, code_hash: str, expires_at: datetime, purpose: str = "P") -> VerificationCode:
        row = VerificationCode(user_id=user_id, purpose=purpose, target=target, code_hash=code_hash, expires_at=expires_at)
        self.session.add(row)
        await self.session.flush()
        return row
