from __future__ import annotations

from decimal import Decimal

from pydantic import Field, field_validator

from core.constants import MAX_CART_LINE_QTY
from core.schemas import BaseSchema, Money
from utils.validators import normalize_coupon_code


class CartItemAdd(BaseSchema):
    product_id: int = Field(gt=0)
    variant_id: int | None = Field(default=None, gt=0)
    quantity: int = Field(default=1, ge=1, le=MAX_CART_LINE_QTY)


class CartItemUpdate(BaseSchema):
    quantity: int = Field(ge=1, le=MAX_CART_LINE_QTY, description="New absolute quantity for the line")


class CartCouponRequest(BaseSchema):
    code: str = Field(min_length=3, max_length=30)

    @field_validator("code")
    @classmethod
    def _code(cls, v: str) -> str:
        return normalize_coupon_code(v)


class CartLineOut(BaseSchema):
    line_key: str = Field(description="`<product_id>-<variant_id or 0>`; use it with PATCH/DELETE /cart/items/{line_key}")
    cart_item_id: int | None = None
    product_id: int
    variant_id: int | None = None
    sku: str
    slug: str | None = None
    name: str
    variant_name: str | None = None
    image: str | None = None
    quantity: int
    unit_price: Money
    mrp: Money
    discount_percentage: Money
    gst_percentage: Money
    line_subtotal: Money
    line_discount: Money
    line_tax: Money
    line_total: Money
    available_quantity: int
    in_stock: bool
    purchasable: bool
    issue: str | None = None


class CartCouponOut(BaseSchema):
    code: str
    description: str | None = None
    discount_amount: Money


class CartSummary(BaseSchema):
    line_count: int
    item_count: int
    subtotal: Money
    discount: Money
    tax: Money
    total_before_shipping: Money
    mrp_savings: Money
    total_weight_kg: Money
    min_order_amount: Money
    meets_min_order: bool
    shortfall: Money
    shipping_note: str = "Shipping is calculated at checkout"


class CartOut(BaseSchema):
    is_guest: bool
    items: list[CartLineOut]
    summary: CartSummary
    coupon: CartCouponOut | None = None
    warnings: list[str] = []
    cart_token: str | None = Field(default=None, description="Guest carts only: send it back in the X-Cart-Token header")


class CartCount(BaseSchema):
    line_count: int
    item_count: int
    subtotal: Money


class SkippedLine(BaseSchema):
    product_id: int
    variant_id: int | None = None
    name: str | None = None
    reason: str


class CartMergeOut(BaseSchema):
    cart: CartOut
    merged_lines: int
    skipped: list[SkippedLine] = []
    coupon_applied: bool = False


class ZeroMoney:
    value = Decimal("0.00")
