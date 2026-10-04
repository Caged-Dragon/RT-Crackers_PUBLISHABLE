from __future__ import annotations

from datetime import date, datetime

from pydantic import Field, field_validator

from core.schemas import BaseSchema
from utils.validators import normalize_phone


class TrackingStep(BaseSchema):
    status: str
    label: str
    completed: bool
    current: bool
    reached_at: datetime | None = None


class TrackingEventOut(BaseSchema):
    status: str
    label: str
    description: str | None = None
    location: str | None = None
    event_time: datetime


class ShipmentInfo(BaseSchema):
    delivery_partner: str | None = None
    carrier_awb_number: str | None = None
    shipped_at: datetime | None = None
    notes: str | None = None


class TrackingOut(BaseSchema):
    order_number: str
    order_status: str
    status_label: str
    status_display: str
    is_terminal: bool
    tracking_number: str | None = None
    expected_delivery_date: date | None = None
    delivery_date: date | None = None
    cancellation_reason: str | None = None
    shipment: ShipmentInfo | None = None
    steps: list[TrackingStep] = Field(description="The delivery journey with the time each stage was reached")
    events: list[TrackingEventOut] = Field(description="Tracking notes, newest first")


class TrackingLookup(BaseSchema):
    order_number: str = Field(min_length=5, max_length=25)
    phone: str = Field(description="Phone number on the order's delivery address")

    @field_validator("order_number")
    @classmethod
    def _order_number(cls, v: str) -> str:
        return v.strip().upper()

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str) -> str:
        return normalize_phone(v)
