from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

from fastapi import Query

from core.schemas import BaseSchema, Money

SORT_OPTIONS = ("relevance", "newest", "price_asc", "price_desc", "popular", "rating", "discount", "name_asc")


@dataclass
class ProductFilters:
    category_id: int | None = Query(None, ge=1, description="Filter by category")
    subcategory_id: int | None = Query(None, ge=1, description="Filter by subcategory")
    brand_id: int | None = Query(None, ge=1, description="Filter by brand")
    min_price: Decimal | None = Query(None, ge=0, description="Minimum selling price")
    max_price: Decimal | None = Query(None, ge=0, description="Maximum selling price")
    min_rating: float | None = Query(None, ge=0, le=5, description="Minimum average rating")
    in_stock: bool | None = Query(None, description="Only products that are in stock")
    featured: bool | None = Query(None)
    trending: bool | None = Query(None)
    new_arrival: bool | None = Query(None)
    sort: str = Query("newest", pattern=f"^({'|'.join(SORT_OPTIONS)})$", description="Sort order")
    q: str | None = None  # populated by the search router only


class ProductCard(BaseSchema):
    product_id: int
    sku: str
    slug: str
    name: str
    short_description: str | None = None
    mrp: Money
    selling_price: Money
    discount_percentage: Money
    primary_image: str | None = None
    brand_name: str | None = None
    category_id: int
    category_name: str
    rating_average: Money
    rating_count: int
    in_stock: bool
    is_featured: bool
    is_trending: bool
    is_new_arrival: bool
    has_variants: bool = False


class ProductImageOut(BaseSchema):
    product_image_id: int
    image_url: str
    alt_text: str | None = None
    is_primary: bool
    display_order: int


class VariantOut(BaseSchema):
    variant_id: int
    sku: str
    name: str
    pack_size: int
    mrp: Money
    selling_price: Money
    discount_percentage: Money
    weight: Money
    in_stock: bool
    available_quantity: int


class AttributeOut(BaseSchema):
    attribute_code: str
    name: str
    value: str
    unit: str | None = None
    variant_id: int | None = None


class CategoryRef(BaseSchema):
    category_id: int
    name: str
    slug: str


class BrandRef(BaseSchema):
    brand_id: int
    name: str
    slug: str


class ProductDetail(ProductCard):
    description: str | None = None
    safety_instructions: str | None = None
    weight: Money
    length: Money
    width: Money
    height: Money
    gst_percentage: Money
    country_of_origin: str
    manufacturer: str | None = None
    subcategory_id: int | None = None
    available_quantity: int
    view_count: int
    sales_count: int
    meta_title: str | None = None
    meta_description: str | None = None
    category: CategoryRef
    brand: BrandRef | None = None
    images: list[ProductImageOut]
    variants: list[VariantOut]
    attributes: list[AttributeOut]
    created_at: datetime
