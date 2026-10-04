from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from pydantic import Field

from core.schemas import BaseSchema


class CouponOut(BaseSchema):
    coupon_id: int
    code: str
    description: str | None = None
    discount_type: str
    discount_type_label: str
    discount_percentage: Decimal | None = None
    discount_amount: Decimal | None = None
    max_discount_amount: Decimal | None = None
    min_order_amount: Decimal = Decimal("0")
    valid_from: datetime
    valid_until: datetime
    first_order_only: bool
    headline: str


class CouponValidation(BaseSchema):
    valid: bool
    code: str
    message: str
    reason_code: str | None = None
    order_amount: Decimal
    discount_amount: Decimal = Decimal("0")
    coupon: CouponOut | None = None


class CouponValidateRequest(BaseSchema):
    code: str = Field(min_length=1, max_length=30)
    order_amount: Decimal | None = Field(default=None, ge=0)


class CouponApplyRequest(BaseSchema):
    code: str = Field(min_length=1, max_length=30)


class CouponUsageOut(BaseSchema):
    coupon_usage_id: int
    order_id: int
    order_number: str | None = None
    coupon_code: str
    discount_applied: Decimal
    status: str
    status_label: str
    used_at: datetime
