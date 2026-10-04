"""Reusable validators (shared by Pydantic schemas and services)."""
from __future__ import annotations

import re
from datetime import date

PHONE_RE = re.compile(r"^[6-9][0-9]{9}$")
PINCODE_RE = re.compile(r"^[1-9][0-9]{5}$")
COUPON_RE = re.compile(r"^[A-Z0-9_-]{3,30}$")
MIN_AGE_YEARS = 18


def normalize_phone(value: str) -> str:
    digits = re.sub(r"[\s\-()]", "", value)
    if digits.startswith("+91"):
        digits = digits[3:]
    elif digits.startswith("91") and len(digits) == 12:
        digits = digits[2:]
    elif digits.startswith("0") and len(digits) == 11:
        digits = digits[1:]
    if not PHONE_RE.match(digits):
        raise ValueError("Enter a valid 10-digit Indian mobile number")
    return digits


def validate_pincode(value: str) -> str:
    value = value.strip()
    if not PINCODE_RE.match(value):
        raise ValueError("Pincode must be 6 digits and cannot start with 0")
    return value


def validate_password_strength(value: str) -> str:
    problems = []
    if len(value) < 8:
        problems.append("at least 8 characters")
    if len(value) > 128:
        problems.append("at most 128 characters")
    if not re.search(r"[a-z]", value):
        problems.append("a lowercase letter")
    if not re.search(r"[A-Z]", value):
        problems.append("an uppercase letter")
    if not re.search(r"\d", value):
        problems.append("a digit")
    if problems:
        raise ValueError("Password must contain " + ", ".join(problems))
    return value


def validate_adult(value: date | None) -> date | None:
    if value is None:
        return value
    today = date.today()
    age = today.year - value.year - ((today.month, today.day) < (value.month, value.day))
    if age < MIN_AGE_YEARS:
        raise ValueError("You must be at least 18 years old to buy fireworks")
    if age > 120:
        raise ValueError("Enter a valid date of birth")
    return value


def normalize_coupon_code(value: str) -> str:
    code = value.strip().upper()
    if not COUPON_RE.match(code):
        raise ValueError("Invalid coupon code format")
    return code
