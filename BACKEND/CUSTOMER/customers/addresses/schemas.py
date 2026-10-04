from __future__ import annotations

from datetime import datetime

from pydantic import Field, field_validator, model_validator

from core.schemas import BaseSchema
from utils.validators import normalize_phone, validate_pincode

ADDRESS_LABELS = {"HOME", "OFFICE", "WAREHOUSE", "OTHER"}
_LEGACY_TYPE_TO_LABEL = {"H": "HOME", "W": "OFFICE", "O": "OTHER"}


def _label(value: str) -> str:
    value = value.strip().upper()
    value = _LEGACY_TYPE_TO_LABEL.get(value, value)
    if value not in ADDRESS_LABELS:
        raise ValueError("address_label must be one of HOME, OFFICE, WAREHOUSE, OTHER")
    return value


class AddressBase(BaseSchema):
    recipient_name: str = Field(min_length=2, max_length=120)
    recipient_phone: str
    house_no: str = Field(min_length=1, max_length=30)
    street: str = Field(min_length=1, max_length=150)
    area: str = Field(min_length=1, max_length=100)
    landmark: str | None = Field(default=None, max_length=150)
    postal_code: str = Field(description="City, district and state are derived from the postal code")
    city: str | None = Field(default=None, max_length=80, description="Ignored: the city comes from the postal code")
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    address_label: str = "HOME"
    address_type: str | None = Field(default=None, description="Legacy H/W/O alias of address_label")
    delivery_instructions: str | None = Field(default=None, max_length=500)
    contact_person: str | None = Field(default=None, min_length=1, max_length=120)
    contact_phone: str | None = None

    @field_validator("recipient_phone")
    @classmethod
    def _phone(cls, v: str) -> str:
        return normalize_phone(v)

    @field_validator("contact_phone")
    @classmethod
    def _contact_phone(cls, v: str | None) -> str | None:
        return normalize_phone(v) if v else None

    @field_validator("postal_code")
    @classmethod
    def _pin(cls, v: str) -> str:
        return validate_pincode(v)

    @model_validator(mode="after")
    def _normalise(self):
        if self.address_type and "address_label" not in self.model_fields_set:
            self.address_label = self.address_type
        self.address_label = _label(self.address_label)
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("latitude and longitude must be supplied together")
        return self


class AddressCreate(AddressBase):
    is_default: bool = False


class AddressUpdate(BaseSchema):
    recipient_name: str | None = Field(default=None, min_length=2, max_length=120)
    recipient_phone: str | None = None
    house_no: str | None = Field(default=None, min_length=1, max_length=30)
    street: str | None = Field(default=None, min_length=1, max_length=150)
    area: str | None = Field(default=None, min_length=1, max_length=100)
    landmark: str | None = Field(default=None, max_length=150)
    postal_code: str | None = None
    city: str | None = Field(default=None, max_length=80, description="Ignored: the city comes from the postal code")
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    address_label: str | None = None
    address_type: str | None = Field(default=None, description="Legacy H/W/O alias of address_label")
    delivery_instructions: str | None = Field(default=None, max_length=500)
    contact_person: str | None = Field(default=None, min_length=1, max_length=120)
    contact_phone: str | None = None
    is_default: bool | None = None

    @field_validator("recipient_phone", "contact_phone")
    @classmethod
    def _phone(cls, v: str | None) -> str | None:
        return normalize_phone(v) if v else v

    @field_validator("postal_code")
    @classmethod
    def _pin(cls, v: str | None) -> str | None:
        return validate_pincode(v) if v else v

    @model_validator(mode="after")
    def _normalise(self):
        if self.address_type and not self.address_label:
            self.address_label = self.address_type
        if self.address_label:
            self.address_label = _label(self.address_label)
        return self


class AddressOut(BaseSchema):
    address_id: int
    recipient_name: str
    recipient_phone: str
    house_no: str
    street: str
    area: str
    landmark: str | None = None
    city: str
    district: str
    state: str
    country: str
    postal_code: str
    latitude: float | None = None
    longitude: float | None = None
    address_label: str
    address_type: str
    address_type_label: str
    delivery_instructions: str | None = None
    contact_person: str | None = None
    contact_phone: str | None = None
    is_verified: bool
    is_default: bool
    is_serviceable: bool
    cod_available: bool
    created_at: datetime
    updated_at: datetime


class PincodeCheck(BaseSchema):
    pincode: str
    city: str
    district: str
    state: str
    country: str
    is_serviceable: bool
    cod_available: bool
    zone_code: str | None = None
