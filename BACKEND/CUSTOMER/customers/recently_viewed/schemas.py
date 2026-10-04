from __future__ import annotations

from datetime import datetime

from core.schemas import BaseSchema
from customers.products.schemas import ProductCard


class RecentlyViewedCreate(BaseSchema):
    product_id: int


class RecentlyViewedItem(BaseSchema):
    product: ProductCard
    view_count: int
    last_viewed_at: datetime
