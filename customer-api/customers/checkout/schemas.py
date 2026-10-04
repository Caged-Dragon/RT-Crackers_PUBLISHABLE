from __future__ import annotations

from datetime import date

from pydantic import Field, field_validator

from core.constants import COD_METHOD_CODE
from core.schemas import BaseSchema, Money
from customers.addresses.schemas import AddressOut
from customers.cart.schemas import CartCouponOut, CartLineOut
from utils.validators import normalize_coupon_code


class CheckoutRequest(BaseSchema):
    shipping_address_id: int = Field(gt=0, description="One of the caller's saved addresses")
    billing_address_id: int | None = Field(default=None, gt=0, description="Defaults to the shipping address")
    shipping_method: str = Field(default="STD", min_length=2, max_length=10, description="Shipping method code, see /checkout/shipping-options")
    payment_method: str = Field(default=COD_METHOD_CODE, min_length=2, max_length=3, description="Only COD (cash on delivery) is supported")
    coupon_code: str | None = Field(default=None, max_length=30, description="Overrides the coupon saved on the cart for this checkout")
    notes: str | None = Field(default=None, max_length=500, description="Delivery note for the order")

    @field_validator("shipping_method", "payment_method")
    @classmethod
    def _upper(cls, v: str) -> str:
        return v.strip().upper()

    @field_validator("coupon_code")
    @classmethod
    def _coupon(cls, v: str | None) -> str | None:
        return normalize_coupon_code(v) if v and v.strip() else None

    @field_validator("notes")
    @classmethod
    def _notes(cls, v: str | None) -> str | None:
        return v.strip() or None if v else None


class ShippingOption(BaseSchema):
    method_code: str
    method_name: str
    description: str | None = None
    available: bool
    reason: str | None = Field(default=None, description="Why the option cannot be used for this address")
    charge: Money
    is_free: bool
    free_shipping_threshold: Money | None = None
    min_delivery_days: int
    max_delivery_days: int
    expected_delivery_date: date | None = Field(default=None, description="Latest expected delivery date, honouring the zone's order cut-off time")


class ShippingOptionsOut(BaseSchema):
    address_id: int
    postal_code: str
    is_serviceable: bool
    cod_available: bool
    options: list[ShippingOption]


class PaymentOut(BaseSchema):
    method_code: str
    method_name: str
    available: bool
    reason: str | None = None
    amount_payable_on_delivery: Money


class CheckoutTotals(BaseSchema):
    subtotal: Money
    discount: Money
    tax: Money
    shipping: Money
    total: Money
    mrp_savings: Money
    item_count: int


class CheckoutSummary(BaseSchema):
    items: list[CartLineOut]
    totals: CheckoutTotals
    coupon: CartCouponOut | None = None
    shipping_address: AddressOut
    billing_address: AddressOut
    shipping: ShippingOption
    payment: PaymentOut
    warnings: list[str] = []
    blocking_issues: list[str] = []
    can_place_order: bool
