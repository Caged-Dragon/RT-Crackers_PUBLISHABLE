"""Order-side tables: orders, items, status history, invoices, COD ledger, shipments and the lookups orders point at."""
from __future__ import annotations

from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import (
    BigInteger, Boolean, Computed, Date, DateTime, FetchedValue, Float, ForeignKey, Identity, Integer, Numeric, SmallInteger,
    String, Text, Time, func, text,
)
from sqlalchemy.dialects.postgresql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class PaymentMethod(Base, TimestampMixin):
    __tablename__ = "payment_methods"
    payment_method_id: Mapped[int] = mapped_column(SmallInteger, Identity(always=True), primary_key=True)
    method_code: Mapped[str] = mapped_column(CHAR(3), unique=True)
    method_name: Mapped[str] = mapped_column(String(60))
    description: Mapped[str | None] = mapped_column(String(255))
    min_order_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), server_default=text("0"))
    max_order_amount: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class ShippingMethod(Base, TimestampMixin):
    __tablename__ = "shipping_methods"
    shipping_method_id: Mapped[int] = mapped_column(SmallInteger, Identity(always=True), primary_key=True)
    method_code: Mapped[str] = mapped_column(String(10), unique=True)
    method_name: Mapped[str] = mapped_column(String(60), unique=True)
    description: Mapped[str | None] = mapped_column(String(255))
    min_delivery_days: Mapped[int] = mapped_column(SmallInteger, server_default=text("1"))
    max_delivery_days: Mapped[int] = mapped_column(SmallInteger, server_default=text("7"))
    slot_start: Mapped[time | None] = mapped_column(Time)
    slot_end: Mapped[time | None] = mapped_column(Time)
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class ZoneShippingRate(Base, TimestampMixin):
    __tablename__ = "zone_shipping_rates"
    zone_id: Mapped[int] = mapped_column(SmallInteger, ForeignKey("delivery_zones.zone_id"), primary_key=True)
    shipping_method_id: Mapped[int] = mapped_column(SmallInteger, ForeignKey("shipping_methods.shipping_method_id"), primary_key=True)
    base_charge: Mapped[Decimal] = mapped_column(Numeric(10, 2), server_default=text("0"))
    per_kg_charge: Mapped[Decimal] = mapped_column(Numeric(10, 2), server_default=text("0"))
    free_shipping_threshold: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class Order(Base, TimestampMixin):
    __tablename__ = "orders"
    order_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    order_number: Mapped[str] = mapped_column(String(20), unique=True, server_default=FetchedValue())
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    billing_address_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("addresses.address_id"))
    shipping_address_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("addresses.address_id"))
    coupon_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("coupons.coupon_id"))
    payment_method_id: Mapped[int] = mapped_column(SmallInteger, ForeignKey("payment_methods.payment_method_id"))
    shipping_method_id: Mapped[int] = mapped_column(SmallInteger, ForeignKey("shipping_methods.shipping_method_id"))
    subtotal: Mapped[Decimal] = mapped_column(Numeric(12, 2), server_default=text("0"))
    discount_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), server_default=text("0"))
    tax_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), server_default=text("0"))
    shipping_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), server_default=text("0"))
    total_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), Computed("subtotal - discount_amount + tax_amount + shipping_amount", persisted=True))
    payment_status: Mapped[str] = mapped_column(CHAR(1), server_default="P")
    order_status: Mapped[str] = mapped_column(CHAR(1), server_default="P")
    tracking_number: Mapped[str | None] = mapped_column(String(40), unique=True)
    expected_delivery_date: Mapped[date | None] = mapped_column(Date)
    delivery_date: Mapped[date | None] = mapped_column(Date)
    cancellation_reason: Mapped[str | None] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(Text)


class OrderItem(Base, TimestampMixin):
    __tablename__ = "order_items"
    order_item_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    order_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("orders.order_id"))
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"))
    variant_id: Mapped[int | None] = mapped_column(BigInteger)
    sku_snapshot: Mapped[str] = mapped_column(String(40))
    product_name_snapshot: Mapped[str] = mapped_column(String(200))
    quantity: Mapped[int] = mapped_column(Integer)
    mrp: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    gst_percentage: Mapped[Decimal] = mapped_column(Numeric(5, 2))
    discount_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), server_default=text("0"))
    tax_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), server_default=text("0"))
    line_total: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), Computed("unit_price * quantity - discount_amount + tax_amount", persisted=True))


class OrderStatusHistory(Base):
    __tablename__ = "order_status_history"
    history_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    order_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("orders.order_id"))
    old_status: Mapped[str | None] = mapped_column(CHAR(1))
    new_status: Mapped[str] = mapped_column(CHAR(1))
    changed_by: Mapped[int | None] = mapped_column(Integer)
    remarks: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class OrderTrackingEvent(Base):
    __tablename__ = "order_tracking_events"
    tracking_event_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    order_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("orders.order_id", ondelete="CASCADE"))
    shipment_id: Mapped[int | None] = mapped_column(BigInteger)
    status: Mapped[str] = mapped_column(CHAR(1))
    description: Mapped[str | None] = mapped_column(String(500))
    location: Mapped[str | None] = mapped_column(String(200))
    event_time: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), nullable=False)


class Invoice(Base, TimestampMixin):
    __tablename__ = "invoices"
    invoice_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    invoice_number: Mapped[str] = mapped_column(String(25), unique=True, server_default=FetchedValue())
    order_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("orders.order_id"), unique=True)
    invoice_date: Mapped[date] = mapped_column(Date, server_default=FetchedValue())
    customer_gstin: Mapped[str | None] = mapped_column(CHAR(15))
    invoice_pdf_url: Mapped[str | None] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(CHAR(1), server_default="G")
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime)
    issued_by: Mapped[int | None] = mapped_column(Integer)


class CodTransaction(Base, TimestampMixin):
    __tablename__ = "cod_transactions"
    cod_transaction_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    order_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("orders.order_id"), unique=True)
    receipt_number: Mapped[str] = mapped_column(String(25), unique=True, server_default=FetchedValue())
    amount_collected: Mapped[Decimal] = mapped_column(Numeric(12, 2), server_default=text("0"))
    status: Mapped[str] = mapped_column(CHAR(1), server_default="P")  # P pending, C collected, F failed/refused, X cancelled
    collected_by: Mapped[int | None] = mapped_column(Integer)
    collected_at: Mapped[datetime | None] = mapped_column(DateTime)
    failure_reason: Mapped[str | None] = mapped_column(String(255))


class Shipment(Base, TimestampMixin):
    __tablename__ = "shipments"
    shipment_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    order_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("orders.order_id"))
    carrier_awb_number: Mapped[str | None] = mapped_column(String(40), unique=True)
    delivery_partner: Mapped[str | None] = mapped_column(String(80))
    delivery_agent_id: Mapped[int | None] = mapped_column(Integer)
    package_count: Mapped[int] = mapped_column(SmallInteger, server_default=text("1"))
    package_weight_kg: Mapped[float | None] = mapped_column(Float)
    packed_at: Mapped[datetime | None] = mapped_column(DateTime)
    shipped_at: Mapped[datetime | None] = mapped_column(DateTime)
    notes: Mapped[str | None] = mapped_column(String(500))
