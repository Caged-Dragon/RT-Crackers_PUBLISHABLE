from __future__ import annotations

from core.schemas import BaseSchema


class SubcategoryOut(BaseSchema):
    subcategory_id: int
    category_id: int
    name: str
    slug: str
    description: str | None = None
    image_url: str | None = None
    product_count: int = 0


class CategoryOut(BaseSchema):
    category_id: int
    name: str
    slug: str
    description: str | None = None
    image_url: str | None = None
    product_count: int = 0
    subcategories: list[SubcategoryOut] = []
