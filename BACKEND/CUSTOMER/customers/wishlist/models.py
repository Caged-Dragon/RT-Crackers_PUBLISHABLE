from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Identity, String, func, text
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class Wishlist(Base, TimestampMixin):
    __tablename__ = "wishlists"
    wishlist_id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"))
    wishlist_name: Mapped[str] = mapped_column(String(80), server_default=text("'My Wishlist'"))


class WishlistItem(Base):
    __tablename__ = "wishlist_items"
    wishlist_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("wishlists.wishlist_id"), primary_key=True)
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
