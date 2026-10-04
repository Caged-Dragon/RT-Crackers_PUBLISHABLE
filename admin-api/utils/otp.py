"""One-time-password generation and hashing."""
from __future__ import annotations

import secrets

from core.config import settings
from core.security import constant_time_equals, hmac_digest


def generate_otp(length: int | None = None) -> str:
    length = length or settings.OTP_LENGTH
    return "".join(secrets.choice("0123456789") for _ in range(length))


def hash_otp(user_id: int, code: str) -> str:
    return hmac_digest(f"otp:{user_id}:{code}")


def verify_otp_hash(user_id: int, code: str, stored_hash: str) -> bool:
    return constant_time_equals(hash_otp(user_id, code), stored_hash)
