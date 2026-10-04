from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger, Boolean, Computed, DateTime, ForeignKey, Identity, Integer, Numeric, SmallInteger, String, Text, func, text,
)
from sqlalchemy.dialects.postgresql import CHAR, INET
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class Brand(Base, TimestampMixin):
    __tablename__ = "brands"
    brand_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    brand_name: Mapped[str] = mapped_column(String(100), unique=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True)
    logo_url: Mapped[str | None] = mapped_column(String(500))
    description: Mapped[str | None] = mapped_column(Text)
    website_url: Mapped[str | None] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class Product(Base, TimestampMixin):
    __tablename__ = "products"
    product_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    category_id: Mapped[int] = mapped_column(Integer, ForeignKey("categories.category_id"))
    subcategory_id: Mapped[int | None] = mapped_column(Integer)
    brand_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("brands.brand_id"))
    sku: Mapped[str] = mapped_column(String(40), unique=True)
    barcode: Mapped[str | None] = mapped_column(String(32))
    slug: Mapped[str] = mapped_column(String(200), unique=True)
    product_name: Mapped[str] = mapped_column(String(200))
    short_description: Mapped[str | None] = mapped_column(String(500))
    description: Mapped[str | None] = mapped_column(Text)
    mrp: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    selling_price: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    cost_price: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    discount_percentage: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), Computed("ROUND((mrp - selling_price) * 100 / NULLIF(mrp, 0), 2)", persisted=True))
    weight: Mapped[Decimal] = mapped_column(Numeric(10, 3), server_default=text("0"))
    length: Mapped[Decimal] = mapped_column(Numeric(8, 2), server_default=text("0"))
    width: Mapped[Decimal] = mapped_column(Numeric(8, 2), server_default=text("0"))
    height: Mapped[Decimal] = mapped_column(Numeric(8, 2), server_default=text("0"))
    gst_percentage: Mapped[Decimal] = mapped_column(Numeric(5, 2), server_default=text("18.00"))
    country_of_origin: Mapped[str] = mapped_column(String(60), server_default="India")
    manufacturer: Mapped[str | None] = mapped_column(String(150))
    warranty_period: Mapped[int] = mapped_column(SmallInteger, server_default=text("0"))
    safety_instructions: Mapped[str | None] = mapped_column(Text)
    stock_quantity: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    min_stock_level: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    max_stock_level: Mapped[int] = mapped_column(Integer, server_default=text("1000"))
    is_featured: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    is_trending: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    is_new_arrival: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    status: Mapped[str] = mapped_column(CHAR(1), server_default="D")
    meta_title: Mapped[str | None] = mapped_column(String(160))
    meta_description: Mapped[str | None] = mapped_column(String(320))
    meta_keywords: Mapped[str | None] = mapped_column(String(255))
    view_count: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    sales_count: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    rating_average: Mapped[Decimal] = mapped_column(Numeric(3, 2), server_default=text("0"))
    rating_count: Mapped[int] = mapped_column(Integer, server_default=text("0"))


class ProductImage(Base, TimestampMixin):
    __tablename__ = "product_images"
    product_image_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"))
    image_url: Mapped[str] = mapped_column(String(500))
    alt_text: Mapped[str | None] = mapped_column(String(200))
    is_primary: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    display_order: Mapped[int] = mapped_column(SmallInteger, server_default=text("0"))


class ProductVariant(Base, TimestampMixin):
    __tablename__ = "product_variants"
    variant_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"))
    variant_sku: Mapped[str] = mapped_column(String(40), unique=True)
    barcode: Mapped[str | None] = mapped_column(String(32))
    variant_name: Mapped[str] = mapped_column(String(120))
    pack_size: Mapped[int] = mapped_column(SmallInteger, server_default=text("1"))
    mrp: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    selling_price: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    cost_price: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    weight: Mapped[Decimal] = mapped_column(Numeric(10, 3), server_default=text("0"))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class ProductAttribute(Base, TimestampMixin):
    __tablename__ = "product_attributes"
    attribute_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    attribute_code: Mapped[str] = mapped_column(String(40), unique=True)
    attribute_name: Mapped[str] = mapped_column(String(80), unique=True)
    data_type: Mapped[str] = mapped_column(CHAR(1), server_default="T")
    unit: Mapped[str | None] = mapped_column(String(20))
    is_filterable: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    display_order: Mapped[int] = mapped_column(SmallInteger, server_default=text("0"))


class AttributeValue(Base, TimestampMixin):
    __tablename__ = "attribute_values"
    attribute_value_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"))
    variant_id: Mapped[int | None] = mapped_column(BigInteger)
    attribute_id: Mapped[int] = mapped_column(Integer, ForeignKey("product_attributes.attribute_id"))
    value_text: Mapped[str] = mapped_column(String(255))


class Inventory(Base, TimestampMixin):
    __tablename__ = "inventory"
    inventory_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"))
    variant_id: Mapped[int | None] = mapped_column(BigInteger)
    quantity_on_hand: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    reserved_quantity: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    rack_location: Mapped[str | None] = mapped_column(String(40))
    last_restocked_at: Mapped[datetime | None] = mapped_column(DateTime)

    @property
    def available(self) -> int:
        return max(self.quantity_on_hand - self.reserved_quantity, 0)


class InventoryMovement(Base):
    __tablename__ = "inventory_movements"
    movement_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    inventory_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("inventory.inventory_id"))
    movement_type: Mapped[str] = mapped_column(CHAR(1))  # P purchase, S sale, R return, A adjust, D damage, C cancel-restock
    quantity_change: Mapped[int] = mapped_column(Integer)
    unit_cost: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    reference_type: Mapped[str | None] = mapped_column(CHAR(1))  # O order
    reference_id: Mapped[int | None] = mapped_column(BigInteger)
    notes: Mapped[str | None] = mapped_column(String(255))
    performed_by: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class ProductView(Base):
    __tablename__ = "product_views"
    product_view_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"))
    user_id: Mapped[int | None] = mapped_column(BigInteger)
    session_id: Mapped[str | None] = mapped_column(String(36))
    anonymous_id: Mapped[str | None] = mapped_column(String(64))
    duration_seconds: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class SearchLog(Base):
    __tablename__ = "search_logs"
    search_log_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    user_id: Mapped[int | None] = mapped_column(BigInteger)
    anonymous_id: Mapped[str | None] = mapped_column(String(64))
    search_query: Mapped[str] = mapped_column(String(255))
    results_count: Mapped[int] = mapped_column(Integer, server_default=text("0"))
    clicked_product_id: Mapped[int | None] = mapped_column(BigInteger)
    ip_address: Mapped[str | None] = mapped_column(INET)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
