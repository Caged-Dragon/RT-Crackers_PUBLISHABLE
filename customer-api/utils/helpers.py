"""Small, dependency-free helpers."""
from __future__ import annotations

import ipaddress
import math
import re
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Request

from core.constants import IST_OFFSET_MINUTES

IST = timezone(timedelta(minutes=IST_OFFSET_MINUTES))


def utcnow() -> datetime:
    """Naive UTC timestamp — matches the schema's TIMESTAMP (without time zone) columns."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def now_ist() -> datetime:
    return datetime.now(IST)


def client_ip(request: Request | None) -> str | None:
    """Best-effort client IP, validated so it is safe for an INET column."""
    if request is None:
        return None
    forwarded = request.headers.get("x-forwarded-for")
    candidate = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else None)
    if not candidate:
        return None
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError:
        return None


def user_agent(request: Request | None) -> str | None:
    if request is None:
        return None
    ua = request.headers.get("user-agent")
    return ua[:500] if ua else None


def device_type_from_ua(ua: str | None) -> str:
    """Maps a user-agent to the schema's W/M/T/O device codes."""
    if not ua:
        return "O"
    low = ua.lower()
    if "ipad" in low or "tablet" in low:
        return "T"
    if "mobi" in low or "android" in low or "iphone" in low:
        return "M"
    if "mozilla" in low or "chrome" in low or "safari" in low:
        return "W"
    return "O"


def slugify(value: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9]+", "-", value.strip().lower()).strip("-")
    return value or "item"


def random_code(length: int = 8) -> str:
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no ambiguous characters
    return "".join(secrets.choice(alphabet) for _ in range(length))


def mask_name(first: str, last: str | None) -> str:
    return f"{first} {last[0]}." if last else first


def mask_email(email: str) -> str:
    local, _, domain = email.partition("@")
    return f"{local[:2]}{'*' * max(len(local) - 2, 1)}@{domain}"


def ceil_div(a: int, b: int) -> int:
    return math.ceil(a / b) if b else 0
