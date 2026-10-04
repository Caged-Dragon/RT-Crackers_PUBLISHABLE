from __future__ import annotations

from datetime import date, datetime

from pydantic import Field, field_validator

from core.schemas import BaseSchema, Money
from customers.cart.schemas import CartOut, SkippedLine


class OrderItemOut(BaseSchema):
    order_item_id: int
    product_id: int
    variant_id: int | None = None
    sku: str
    name: str
    image: str | None = None
    quantity: int
    mrp: Money
    unit_price: Money
    gst_percentage: Money
    discount_amount: Money
    tax_amount: Money
    line_total: Money
    can_review: bool = Field(description="True once the order is delivered")


class AddressSnapshotOut(BaseSchema):
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
    postal_code: str
    delivery_instructions: str | None = None


class OrderSummaryOut(BaseSchema):
    order_id: int
    order_number: str
    order_status: str
    status_label: str
    status_display: str
    payment_status: str
    payment_status_label: str
    total_amount: Money
    item_count: int
    items_preview: list[str]
    image: str | None = None
    placed_at: datetime
    expected_delivery_date: date | None = None
    delivery_date: date | None = None
    can_cancel: bool


class InvoiceOut(BaseSchema):
    invoice_number: str
    invoice_date: date
    status: str
    status_label: str
    download_path: str


class OrderDetailOut(OrderSummaryOut):
    subtotal: Money
    discount_amount: Money
    tax_amount: Money
    shipping_amount: Money
    coupon_code: str | None = None
    shipping_method: str
    payment_method: str
    tracking_number: str | None = None
    cancellation_reason: str | None = None
    notes: str | None = None
    receipt_number: str | None = None
    shipping_address: AddressSnapshotOut
    billing_address: AddressSnapshotOut
    items: list[OrderItemOut]
    invoice: InvoiceOut | None = None
    updated_at: datetime


class CancelOrderRequest(BaseSchema):
    reason: str = Field(min_length=3, max_length=255, description="Why the order is being cancelled")

    @field_validator("reason")
    @classmethod
    def _strip(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 3:
            raise ValueError("Please give a reason")
        return v


class ReorderOut(BaseSchema):
    cart: CartOut
    added_lines: int
    skipped: list[SkippedLine] = []
