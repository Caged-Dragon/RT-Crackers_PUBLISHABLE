from __future__ import annotations

from sqlalchemy import BigInteger, ForeignKey, Identity, Integer
from sqlalchemy.dialects.postgresql import CHAR
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class Cart(Base, TimestampMixin):
    __tablename__ = "carts"
    cart_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    coupon_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("coupons.coupon_id"))
    status: Mapped[str] = mapped_column(CHAR(1), server_default="A")  # A active, C converted, X abandoned


class CartItem(Base, TimestampMixin):
    __tablename__ = "cart_items"
    cart_item_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    cart_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("carts.cart_id"))
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"))
    variant_id: Mapped[int | None] = mapped_column(BigInteger)
    quantity: Mapped[int] = mapped_column(Integer, server_default="1")
