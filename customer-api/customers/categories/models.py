from __future__ import annotations

from sqlalchemy import Boolean, ForeignKey, Identity, Integer, SmallInteger, String, Text, text
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class Category(Base, TimestampMixin):
    __tablename__ = "categories"
    category_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    category_name: Mapped[str] = mapped_column(String(100), unique=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True)
    description: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(500))
    display_order: Mapped[int] = mapped_column(SmallInteger, server_default=text("0"))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))


class SubCategory(Base, TimestampMixin):
    __tablename__ = "subcategories"
    subcategory_id: Mapped[int] = mapped_column(Integer, Identity(always=True), primary_key=True)
    category_id: Mapped[int] = mapped_column(Integer, ForeignKey("categories.category_id"))
    subcategory_name: Mapped[str] = mapped_column(String(100))
    slug: Mapped[str] = mapped_column(String(120), unique=True)
    description: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(500))
    display_order: Mapped[int] = mapped_column(SmallInteger, server_default=text("0"))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))
