from __future__ import annotations

from datetime import datetime

from pydantic import Field

from core.constants import MAX_CART_LINE_QTY
from core.schemas import BaseSchema
from customers.products.schemas import ProductCard


class WishlistAdd(BaseSchema):
    product_id: int = Field(gt=0)


class WishlistMoveToCart(BaseSchema):
    variant_id: int | None = Field(default=None, gt=0)
    quantity: int = Field(default=1, ge=1, le=MAX_CART_LINE_QTY)
    remove_from_wishlist: bool = True


class WishlistItemOut(BaseSchema):
    product: ProductCard
    added_at: datetime


class WishlistCount(BaseSchema):
    count: int


class WishlistContains(BaseSchema):
    product_ids: list[int]
