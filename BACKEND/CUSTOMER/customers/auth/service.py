from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import timedelta

from fastapi import BackgroundTasks, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import settings
from core.constants import CUSTOMER_ROLE_CODE, FLAG_REFERRAL, SETTING_REFEREE_REWARD, SETTING_REFERRER_REWARD, USER_ACTIVE, USER_STATUS_LABELS
from core.database import get_db
from core.exceptions import BadRequestError, ConflictError, ForbiddenError, TooManyRequestsError, UnauthorizedError
from core.security import (
    TOKEN_VERIFY_EMAIL, create_access_token, create_email_verification_token, create_refresh_token, decode_jwt,
    generate_urlsafe_token, hash_password, hash_token, password_needs_rehash, verify_password, TOKEN_REFRESH,
)
from core.system_models import get_setting, is_feature_enabled
from customers.auth.models import User, UserSession
from customers.auth.repository import AuthRepository
from customers.auth.schemas import AuthResponse, AuthUser, OtpSentResponse, RegisterRequest, TokenPair
from customers.referrals.repository import ReferralRepository
from utils.email import safe_send_template_email
from utils.helpers import device_type_from_ua, mask_email, utcnow
from utils.otp import generate_otp, hash_otp, verify_otp_hash
from utils.sms import safe_send_sms

logger = logging.getLogger("rtcrackers.auth")

_DUMMY_HASH = hash_password("timing-equalisation-dummy")


class RequestMeta:
    def __init__(self, ip: str | None = None, user_agent: str | None = None):
        self.ip = ip
        self.user_agent = user_agent


class AuthService:
    def __init__(self, session: AsyncSession, background: BackgroundTasks):
        self.session = session
        self.repo = AuthRepository(session)
        self.referrals = ReferralRepository(session)
        self.bg = background

    # ----------------------------------------------------------------- helpers
    async def _issue_tokens(self, user: User, session_row: UserSession) -> TokenPair:
        access, _ = create_access_token(user.user_id, session_row.session_id)
        refresh, refresh_exp = create_refresh_token(user.user_id, session_row.session_id)
        await self.repo.add_refresh_token(user_id=user.user_id, session_id=session_row.session_id,
                                          token_hash=hash_token(refresh), expires_at=refresh_exp.replace(tzinfo=None))
        return TokenPair(access_token=access, refresh_token=refresh, expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60)

    async def _open_session(self, user: User, meta: RequestMeta) -> UserSession:
        return await self.repo.create_session(
            user_id=user.user_id, ip=meta.ip, ua=meta.user_agent, device=device_type_from_ua(meta.user_agent),
            expires_at=utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS))

    def _send_verification_email(self, user: User) -> None:
        token = create_email_verification_token(user.user_id, user.email)
        link = f"{settings.FRONTEND_URL.rstrip('/')}/verify-email?token={token}"
        self.bg.add_task(safe_send_template_email, user.email, "VERIFY_EMAIL", {"first_name": user.first_name, "link": link})

    # ---------------------------------------------------------------- register
    async def register(self, data: RegisterRequest, meta: RequestMeta) -> AuthResponse:
        if await self.repo.get_user_by_email(data.email):
            raise ConflictError("An account with this email already exists", code="email_taken")
        if await self.repo.get_user_by_phone(data.phone):
            raise ConflictError("An account with this phone number already exists", code="phone_taken")
        referrer = None
        if data.referral_code:
            referrer = await self.repo.get_user_by_referral_code(data.referral_code)
            if referrer is None or referrer.status != USER_ACTIVE:
                raise BadRequestError("Invalid referral code", code="invalid_referral_code")

        pw_hash = await asyncio.to_thread(hash_password, data.password)
        user = User(email=data.email, password_hash=pw_hash, phone=data.phone, first_name=data.first_name, middle_name=data.middle_name,
                    last_name=data.last_name, gender=data.gender, dob=data.dob, referred_by=referrer.user_id if referrer else None,
                    last_password_change=utcnow(), last_login=utcnow())
        await self.repo.add_user(user)
        await self.repo.ensure_profile(user.user_id)
        await self.repo.assign_customer_role(user.user_id, CUSTOMER_ROLE_CODE)

        if referrer and await is_feature_enabled(self.session, FLAG_REFERRAL):
            referrer_amt = await get_setting(self.session, SETTING_REFERRER_REWARD, settings.REFERRAL_REFERRER_REWARD)
            referee_amt = await get_setting(self.session, SETTING_REFEREE_REWARD, settings.REFERRAL_REFEREE_REWARD)
            await self.referrals.create_pending_rewards(user.user_id, referrer_amt, referee_amt,
                                                        utcnow() + timedelta(days=settings.REFERRAL_REWARD_VALID_DAYS * 4))

        session_row = await self._open_session(user, meta)
        tokens = await self._issue_tokens(user, session_row)
        await self.repo.add_login_history(user_id=user.user_id, email=user.email, status="S", reason=None, ip=meta.ip,
                                          ua=meta.user_agent, session_id=session_row.session_id)
        await self.session.commit()
        self._send_verification_email(user)
        return AuthResponse(user=AuthUser.model_validate(user), tokens=tokens)

    # ------------------------------------------------------------------- login
    async def login(self, email: str, password: str, meta: RequestMeta) -> AuthResponse:
        user = await self.repo.get_user_by_email(email)
        if user is None or user.status == "D":
            await asyncio.to_thread(verify_password, password, _DUMMY_HASH)  # equalise timing
            await self.repo.add_login_history(user_id=None, email=email, status="F", reason="unknown_email", ip=meta.ip, ua=meta.user_agent)
            await self.session.commit()
            raise UnauthorizedError("Invalid email or password", code="invalid_credentials")

        if user.account_locked:
            await self.repo.add_login_history(user_id=user.user_id, email=email, status="L", reason="account_locked", ip=meta.ip, ua=meta.user_agent)
            await self.session.commit()
            raise ForbiddenError("Account locked after too many failed attempts. Reset your password to unlock it.", code="account_locked")

        if not await asyncio.to_thread(verify_password, password, user.password_hash):
            user.failed_login_count += 1
            locked = user.failed_login_count >= settings.MAX_FAILED_LOGINS
            if locked:
                user.account_locked = True
            await self.repo.add_login_history(user_id=user.user_id, email=email, status="F", reason="bad_password", ip=meta.ip, ua=meta.user_agent)
            await self.session.commit()
            if locked:
                raise ForbiddenError("Account locked after too many failed attempts. Reset your password to unlock it.", code="account_locked")
            raise UnauthorizedError("Invalid email or password", code="invalid_credentials")

        if user.status != USER_ACTIVE:
            await self.repo.add_login_history(user_id=user.user_id, email=email, status="F", reason=f"status_{user.status}", ip=meta.ip, ua=meta.user_agent)
            await self.session.commit()
            raise ForbiddenError(f"Your account is {USER_STATUS_LABELS.get(user.status, 'unavailable')}. Please contact support.", code="account_disabled")

        if password_needs_rehash(user.password_hash):
            user.password_hash = await asyncio.to_thread(hash_password, password)
        user.failed_login_count = 0
        user.last_login = utcnow()
        session_row = await self._open_session(user, meta)
        tokens = await self._issue_tokens(user, session_row)
        await self.repo.add_login_history(user_id=user.user_id, email=email, status="S", reason=None, ip=meta.ip, ua=meta.user_agent,
                                          session_id=session_row.session_id)
        await self.session.commit()
        return AuthResponse(user=AuthUser.model_validate(user), tokens=tokens)

    # ----------------------------------------------------------------- refresh
    async def refresh(self, refresh_token: str) -> TokenPair:
        payload = decode_jwt(refresh_token, TOKEN_REFRESH)
        stored = await self.repo.get_refresh_token(hash_token(refresh_token))
        if stored is None:
            raise UnauthorizedError("Invalid refresh token", code="invalid_token")
        if stored.revoked_at is not None:
            # A rotated token was replayed: assume theft and kill the whole session.
            if stored.session_id:
                await self.repo.end_session(stored.session_id)
            await self.session.commit()
            raise UnauthorizedError("Refresh token has been revoked", code="token_reused")
        if stored.expires_at <= utcnow():
            raise UnauthorizedError("Refresh token has expired", code="token_expired")

        session_row = await self.repo.get_session(uuid.UUID(payload["sid"]))
        user = await self.repo.get_user(int(payload["sub"]))
        if session_row is None or session_row.ended_at is not None or session_row.expires_at <= utcnow() or user is None or user.status != USER_ACTIVE:
            raise UnauthorizedError("Session is no longer valid", code="session_expired")

        new_access, _ = create_access_token(user.user_id, session_row.session_id)
        new_refresh, new_exp = create_refresh_token(user.user_id, session_row.session_id)
        new_row = await self.repo.add_refresh_token(user_id=user.user_id, session_id=session_row.session_id, token_hash=hash_token(new_refresh),
                                                    expires_at=new_exp.replace(tzinfo=None))
        stored.revoked_at = utcnow()
        stored.replaced_by_token_id = new_row.refresh_token_id
        session_row.last_activity_at = utcnow()
        session_row.expires_at = new_exp.replace(tzinfo=None)
        await self.session.commit()
        return TokenPair(access_token=new_access, refresh_token=new_refresh, expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60)

    # ------------------------------------------------------------------ logout
    async def logout(self, user_id: int, session_id: uuid.UUID, all_devices: bool = False) -> None:
        if all_devices:
            await self.repo.end_all_sessions(user_id)
        else:
            await self.repo.end_session(session_id)
        await self.session.commit()

    # --------------------------------------------------------- password reset
    async def forgot_password(self, email: str, meta: RequestMeta) -> None:
        user = await self.repo.get_user_by_email(email)
        if user is None or user.status in ("D", "B"):
            return  # never reveal whether the e-mail exists
        await self.repo.invalidate_reset_tokens(user.user_id)
        raw = generate_urlsafe_token()
        await self.repo.add_reset_token(user_id=user.user_id, token_hash=hash_token(raw), ip=meta.ip,
                                        expires_at=utcnow() + timedelta(minutes=settings.PASSWORD_RESET_EXPIRE_MINUTES))
        await self.session.commit()
        link = f"{settings.FRONTEND_URL.rstrip('/')}/reset-password?token={raw}"
        self.bg.add_task(safe_send_template_email, user.email, "PASSWORD_RESET",
                         {"first_name": user.first_name, "link": link, "minutes": settings.PASSWORD_RESET_EXPIRE_MINUTES})

    async def reset_password(self, token: str, new_password: str) -> None:
        row = await self.repo.get_reset_token(hash_token(token))
        if row is None or row.used_at is not None or row.expires_at <= utcnow():
            raise BadRequestError("This reset link is invalid or has expired", code="invalid_reset_token")
        user = await self.repo.get_user(row.user_id)
        if user is None or user.status in ("D", "B"):
            raise BadRequestError("This reset link is invalid or has expired", code="invalid_reset_token")
        user.password_hash = await asyncio.to_thread(hash_password, new_password)
        user.last_password_change = utcnow()
        user.failed_login_count = 0
        user.account_locked = False
        await self.repo.invalidate_reset_tokens(user.user_id)
        await self.repo.end_all_sessions(user.user_id)
        await self.session.commit()
        self.bg.add_task(safe_send_template_email, user.email, "PASSWORD_CHANGED", {"first_name": user.first_name})

    # ------------------------------------------------------------ verify email
    async def verify_email(self, token: str) -> None:
        payload = decode_jwt(token, TOKEN_VERIFY_EMAIL)
        user = await self.repo.get_user(int(payload["sub"]))
        if user is None or user.email != payload.get("email"):
            raise BadRequestError("This verification link is invalid", code="invalid_verification_token")
        if not user.email_verified:
            user.email_verified = True
            await self.session.commit()

    async def resend_verification(self, user: User) -> None:
        if user.email_verified:
            raise BadRequestError("Email is already verified", code="already_verified")
        self._send_verification_email(user)

    # --------------------------------------------------------------------- OTP
    async def send_phone_otp(self, user: User) -> OtpSentResponse:
        if user.phone_verified:
            raise BadRequestError("Phone number is already verified", code="already_verified")
        existing = await self.repo.latest_active_code(user.user_id)
        if existing is not None:
            wait = settings.OTP_RESEND_SECONDS - int((utcnow() - existing.created_at).total_seconds())
            if wait > 0:
                raise TooManyRequestsError(f"Please wait {wait}s before requesting another code", code="otp_resend_wait",
                                           headers={"Retry-After": str(wait)})
        await self.repo.consume_codes(user.user_id)
        code = generate_otp()
        await self.repo.add_code(user_id=user.user_id, target=user.phone, code_hash=hash_otp(user.user_id, code),
                                 expires_at=utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES))
        await self.session.commit()
        self.bg.add_task(safe_send_sms, user.phone,
                         f"{code} is your {settings.STORE_NAME} verification code. Valid for {settings.OTP_EXPIRE_MINUTES} minutes. Do not share it.")
        return OtpSentResponse(message="Verification code sent", phone_masked=f"{'*' * 6}{user.phone[-4:]}",
                               expires_in=settings.OTP_EXPIRE_MINUTES * 60, resend_after=settings.OTP_RESEND_SECONDS)

    async def verify_phone_otp(self, user: User, code: str) -> None:
        row = await self.repo.latest_active_code(user.user_id)
        if row is None:
            raise BadRequestError("No active code. Request a new one.", code="otp_not_found")
        if row.attempts >= settings.OTP_MAX_ATTEMPTS:
            row.consumed_at = utcnow()
            await self.session.commit()
            raise BadRequestError("Too many incorrect attempts. Request a new code.", code="otp_locked")
        if not verify_otp_hash(user.user_id, code, row.code_hash) or row.target != user.phone:
            row.attempts += 1
            await self.session.commit()
            raise BadRequestError("Incorrect verification code", code="otp_invalid")
        row.consumed_at = utcnow()
        user.phone_verified = True
        await self.session.commit()


def get_auth_service(background: BackgroundTasks, session: AsyncSession = Depends(get_db)) -> AuthService:
    return AuthService(session, background)
