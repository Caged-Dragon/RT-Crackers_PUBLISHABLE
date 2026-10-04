from __future__ import annotations

from datetime import date, datetime

from pydantic import Field, field_validator

from core.constants import GENDERS
from core.schemas import BaseSchema
from utils.validators import normalize_phone, validate_adult, validate_password_strength


class ProfileOut(BaseSchema):
    user_id: int
    email: str
    phone: str
    first_name: str
    middle_name: str | None = None
    last_name: str | None = None
    full_name: str
    gender: str | None = None
    dob: date | None = None
    profile_image: str | None = None
    email_verified: bool
    phone_verified: bool
    preferred_language: str
    preferred_currency: str
    referral_code: str
    last_login: datetime | None = None
    created_at: datetime
    display_name: str | None = None
    bio: str | None = None
    alternate_phone: str | None = None
    whatsapp_number: str | None = None
    occupation: str | None = None
    timezone: str = "Asia/Kolkata"
    age_verified: bool = False


class ProfileUpdate(BaseSchema):
    first_name: str | None = Field(default=None, min_length=1, max_length=60)
    middle_name: str | None = Field(default=None, max_length=60)
    last_name: str | None = Field(default=None, max_length=60)
    gender: str | None = None
    dob: date | None = None
    preferred_language: str | None = Field(default=None, min_length=2, max_length=2)
    display_name: str | None = Field(default=None, max_length=100)
    bio: str | None = Field(default=None, max_length=2000)
    alternate_phone: str | None = None
    whatsapp_number: str | None = None
    occupation: str | None = Field(default=None, max_length=80)
    timezone: str | None = Field(default=None, max_length=50)

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

    @field_validator("alternate_phone", "whatsapp_number")
    @classmethod
    def _phones(cls, v: str | None) -> str | None:
        return normalize_phone(v) if v else None

    @field_validator("preferred_language")
    @classmethod
    def _lang(cls, v: str | None) -> str | None:
        return v.lower() if v else v


class ChangePasswordRequest(BaseSchema):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def _pw(cls, v: str) -> str:
        return validate_password_strength(v)


class NotificationPreferences(BaseSchema):
    email_opt_in: bool
    sms_opt_in: bool
    whatsapp_opt_in: bool


class NotificationPreferencesUpdate(BaseSchema):
    email_opt_in: bool | None = None
    sms_opt_in: bool | None = None
    whatsapp_opt_in: bool | None = None


class AvatarResponse(BaseSchema):
    profile_image: str
