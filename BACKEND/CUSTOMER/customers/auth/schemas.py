from __future__ import annotations

from datetime import date, datetime

from pydantic import EmailStr, Field, field_validator

from core.constants import GENDERS
from core.schemas import BaseSchema
from utils.validators import normalize_phone, validate_adult, validate_password_strength


class RegisterRequest(BaseSchema):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    phone: str
    first_name: str = Field(min_length=1, max_length=60)
    middle_name: str | None = Field(default=None, max_length=60)
    last_name: str | None = Field(default=None, max_length=60)
    gender: str | None = None
    dob: date | None = None
    referral_code: str | None = Field(default=None, max_length=12)

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return v.lower()

    @field_validator("password")
    @classmethod
    def _password(cls, v: str) -> str:
        return validate_password_strength(v)

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str) -> str:
        return normalize_phone(v)

    @field_validator("gender")
    @classmethod
    def _gender(cls, v: str | None) -> str | None:
        if v is not None and v.upper() not in GENDERS:
            raise ValueError("gender must be one of M, F, O")
        return v.upper() if v else v

    @field_validator("dob")
    @classmethod
    def _dob(cls, v: date | None) -> date | None:
        return validate_adult(v)

    @field_validator("referral_code")
    @classmethod
    def _ref(cls, v: str | None) -> str | None:
        return v.strip().upper() if v else None


class LoginRequest(BaseSchema):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return v.lower()


class RefreshRequest(BaseSchema):
    refresh_token: str


class LogoutRequest(BaseSchema):
    all_devices: bool = False


class ForgotPasswordRequest(BaseSchema):
    email: EmailStr

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return v.lower()


class ResetPasswordRequest(BaseSchema):
    token: str = Field(min_length=10)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def _password(cls, v: str) -> str:
        return validate_password_strength(v)


class VerifyEmailRequest(BaseSchema):
    token: str


class VerifyOtpRequest(BaseSchema):
    code: str = Field(min_length=4, max_length=8, pattern=r"^\d+$")


class AuthUser(BaseSchema):
    user_id: int
    email: str
    phone: str
    first_name: str
    middle_name: str | None = None
    last_name: str | None = None
    gender: str | None = None
    dob: date | None = None
    profile_image: str | None = None
    email_verified: bool
    phone_verified: bool
    referral_code: str
    preferred_language: str
    preferred_currency: str
    created_at: datetime


class TokenPair(BaseSchema):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = Field(description="Access-token lifetime in seconds")


class AuthResponse(BaseSchema):
    user: AuthUser
    tokens: TokenPair


class OtpSentResponse(BaseSchema):
    message: str
    phone_masked: str
    expires_in: int
    resend_after: int
