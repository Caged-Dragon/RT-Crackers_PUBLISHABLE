"""Address + geography tables (schema upgrade v2: countries > states > districts > cities > postal_codes)."""
from __future__ import annotations

from datetime import datetime, time

from sqlalchemy import BigInteger, Boolean, DateTime, Float, ForeignKey, Identity, Integer, SmallInteger, String, Time, text
from sqlalchemy.dialects.postgresql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class DeliveryZone(Base, TimestampMixin):
    __tablename__ = "delivery_zones"
    zone_id: Mapped[int] = mapped_column(SmallInteger, Identity(always=True), primary_key=True)
    zone_code: Mapped[str] = mapped_column(String(10), unique=True)
    zone_name: Mapped[str] = mapped_column(String(80), unique=True)
    description: Mapped[str | None] = mapped_column(String(255))
    order_cutoff_time: Mapped[time] = mapped_column(Time, server_default=text("'16:00'"))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class Country(Base, TimestampMixin):
    __tablename__ = "countries"
    country_id: Mapped[int] = mapped_column(SmallInteger, Identity(always=True), primary_key=True)
    country_code: Mapped[str] = mapped_column(CHAR(2), unique=True)
    country_name: Mapped[str] = mapped_column(String(80), unique=True)
    phone_code: Mapped[str | None] = mapped_column(String(6))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class State(Base, TimestampMixin):
    __tablename__ = "states"
    state_id: Mapped[int] = mapped_column(SmallInteger, Identity(always=True), primary_key=True)
    country_id: Mapped[int] = mapped_column(SmallInteger, ForeignKey("countries.country_id"))
    state_name: Mapped[str] = mapped_column(String(80))
    state_code: Mapped[str | None] = mapped_column(String(5))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class District(Base, TimestampMixin):
    __tablename__ = "districts"
    district_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    state_id: Mapped[int] = mapped_column(SmallInteger, ForeignKey("states.state_id"))
    district_name: Mapped[str] = mapped_column(String(80))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class City(Base, TimestampMixin):
    __tablename__ = "cities"
    city_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    district_id: Mapped[int] = mapped_column(Integer, ForeignKey("districts.district_id"))
    city_name: Mapped[str] = mapped_column(String(80))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class PostalCode(Base, TimestampMixin):
    __tablename__ = "postal_codes"
    postal_code_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    postal_code: Mapped[str] = mapped_column(CHAR(6), unique=True)
    city_id: Mapped[int] = mapped_column(Integer, ForeignKey("cities.city_id"))
    zone_id: Mapped[int] = mapped_column(SmallInteger, ForeignKey("delivery_zones.zone_id"))
    is_serviceable: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    cod_available: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class Address(Base, TimestampMixin):
    __tablename__ = "addresses"
    address_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    recipient_name: Mapped[str] = mapped_column(String(120))
    recipient_phone: Mapped[str] = mapped_column(CHAR(10))
    house_no: Mapped[str] = mapped_column(String(30))
    street: Mapped[str] = mapped_column(String(150))
    area: Mapped[str] = mapped_column(String(100))
    landmark: Mapped[str | None] = mapped_column(String(150))
    postal_code_id: Mapped[int] = mapped_column(Integer, ForeignKey("postal_codes.postal_code_id"))
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)
    address_label: Mapped[str] = mapped_column(String(10), server_default="HOME")
    delivery_instructions: Mapped[str | None] = mapped_column(String(500))
    is_verified: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    verification_date: Mapped[datetime | None] = mapped_column(DateTime)
    contact_person: Mapped[str | None] = mapped_column(String(120))
    contact_phone: Mapped[str | None] = mapped_column(CHAR(10))
    is_default: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    is_archived: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
