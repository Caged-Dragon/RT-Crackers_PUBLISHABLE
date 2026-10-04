"""Password hashing, JWT creation/verification and secure token helpers."""
from __future__ import annotations

import hashlib
import hmac
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

from core.config import settings
from core.exceptions import UnauthorizedError

_hasher = PasswordHasher()

TOKEN_ACCESS = "access"
TOKEN_REFRESH = "refresh"
TOKEN_VERIFY_EMAIL = "verify_email"
TOKEN_CART = "cart"


# ------------------------------------------------------------- passwords
def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def password_needs_rehash(password_hash: str) -> bool:
    return _hasher.check_needs_rehash(password_hash)


# ---------------------------------------------------------------- tokens
def _now() -> datetime:
    return datetime.now(timezone.utc)


def create_jwt(subject: str, token_type: str, expires: timedelta, extra: dict[str, Any] | None = None) -> tuple[str, str, datetime]:
    """Returns (token, jti, expires_at_utc)."""
    jti = uuid.uuid4().hex
    exp = _now() + expires
    payload: dict[str, Any] = {"sub": subject, "type": token_type, "jti": jti, "iat": _now(), "exp": exp}
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM), jti, exp


def decode_jwt(token: str, expected_type: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM], options={"require": ["exp", "sub", "type"]})
    except jwt.ExpiredSignatureError as exc:
        raise UnauthorizedError("Token has expired", code="token_expired") from exc
    except jwt.PyJWTError as exc:
        raise UnauthorizedError("Invalid token", code="invalid_token") from exc
    if payload.get("type") != expected_type:
        raise UnauthorizedError("Invalid token type", code="invalid_token")
    return payload


def create_access_token(user_id: int, session_id: uuid.UUID) -> tuple[str, datetime]:
    token, _, exp = create_jwt(str(user_id), TOKEN_ACCESS, timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES), {"sid": str(session_id)})
    return token, exp


def create_refresh_token(user_id: int, session_id: uuid.UUID) -> tuple[str, datetime]:
    token, _, exp = create_jwt(str(user_id), TOKEN_REFRESH, timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS), {"sid": str(session_id)})
    return token, exp


def create_email_verification_token(user_id: int, email: str) -> str:
    token, _, _ = create_jwt(str(user_id), TOKEN_VERIFY_EMAIL, timedelta(hours=settings.EMAIL_VERIFY_EXPIRE_HOURS), {"email": email})
    return token


# ------------------------------------------------------- opaque secrets
def generate_urlsafe_token(nbytes: int = 32) -> str:
    return secrets.token_urlsafe(nbytes)


def hash_token(raw: str) -> str:
    """SHA-256 hex digest — raw tokens are never stored."""
    return hashlib.sha256(raw.encode()).hexdigest()


def hmac_digest(value: str) -> str:
    return hmac.new(settings.JWT_SECRET_KEY.encode(), value.encode(), hashlib.sha256).hexdigest()


def constant_time_equals(a: str, b: str) -> bool:
    return hmac.compare_digest(a.encode(), b.encode())
