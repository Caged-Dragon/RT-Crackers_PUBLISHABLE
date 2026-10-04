from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, func, text
from sqlalchemy.orm import Mapped, mapped_column

from core.database import Base, TimestampMixin


class RecentlyViewedProduct(Base, TimestampMixin):
    __tablename__ = "recently_viewed_products"
    user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("users.user_id"), primary_key=True)
    product_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("products.product_id"), primary_key=True)
    view_count: Mapped[int] = mapped_column(Integer, server_default=text("1"))
    last_viewed_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
