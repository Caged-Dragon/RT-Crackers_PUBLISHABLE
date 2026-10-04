from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from customers.products.repository import ProductRepository
from customers.recently_viewed.models import RecentlyViewedProduct


class RecentlyViewedRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.products = ProductRepository(session)

    async def upsert(self, user_id: int, product_id: int) -> None:
        stmt = insert(RecentlyViewedProduct).values(user_id=user_id, product_id=product_id, view_count=1, last_viewed_at=func.now())
        stmt = stmt.on_conflict_do_update(
            index_elements=["user_id", "product_id"],
            set_={"view_count": RecentlyViewedProduct.view_count + 1, "last_viewed_at": func.now(), "updated_at": func.now()})
        await self.session.execute(stmt)

    async def trim(self, user_id: int, keep: int) -> None:
        stale = (select(RecentlyViewedProduct.product_id).where(RecentlyViewedProduct.user_id == user_id)
                 .order_by(RecentlyViewedProduct.last_viewed_at.desc()).offset(keep))
        await self.session.execute(delete(RecentlyViewedProduct).where(RecentlyViewedProduct.user_id == user_id, RecentlyViewedProduct.product_id.in_(stale)))

    async def list(self, user_id: int, limit: int) -> list[tuple[Any, int, datetime]]:
        """Returns (card_row, view_count, last_viewed_at) for products that are still active."""
        stmt = (select(RecentlyViewedProduct.product_id, RecentlyViewedProduct.view_count, RecentlyViewedProduct.last_viewed_at)
                .where(RecentlyViewedProduct.user_id == user_id).order_by(RecentlyViewedProduct.last_viewed_at.desc()).limit(limit * 2))
        meta = {pid: (vc, at) for pid, vc, at in (await self.session.execute(stmt)).all()}
        cards = {r.Product.product_id: r for r in await self.products.cards_by_ids(list(meta))}
        ordered = [(cards[pid], *meta[pid]) for pid in meta if pid in cards]
        return ordered[:limit]

    async def remove(self, user_id: int, product_id: int) -> None:
        await self.session.execute(delete(RecentlyViewedProduct).where(RecentlyViewedProduct.user_id == user_id, RecentlyViewedProduct.product_id == product_id))

    async def clear(self, user_id: int) -> None:
        await self.session.execute(delete(RecentlyViewedProduct).where(RecentlyViewedProduct.user_id == user_id))
