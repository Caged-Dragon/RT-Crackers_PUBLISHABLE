from __future__ import annotations

import logging

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import RECENTLY_VIEWED_CAP
from core.database import async_session_factory, get_db
from core.exceptions import NotFoundError
from customers.products.repository import ProductRepository
from customers.products.service import to_card
from customers.recently_viewed.repository import RecentlyViewedRepository
from customers.recently_viewed.schemas import RecentlyViewedItem

logger = logging.getLogger("rtcrackers.recently_viewed")


class RecentlyViewedService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = RecentlyViewedRepository(session)
        self.products = ProductRepository(session)

    async def record(self, user_id: int, product_id: int) -> None:
        if await self.products.get_by_id(product_id) is None:
            raise NotFoundError("Product not found", code="product_not_found")
        await self.repo.upsert(user_id, product_id)
        await self.repo.trim(user_id, RECENTLY_VIEWED_CAP)
        await self.session.commit()

    async def list(self, user_id: int, limit: int) -> list[RecentlyViewedItem]:
        return [RecentlyViewedItem(product=to_card(row), view_count=count, last_viewed_at=at) for row, count, at in await self.repo.list(user_id, limit)]

    async def remove(self, user_id: int, product_id: int) -> None:
        await self.repo.remove(user_id, product_id)
        await self.session.commit()

    async def clear(self, user_id: int) -> None:
        await self.repo.clear(user_id)
        await self.session.commit()


async def track_view_background(product_id: int, user_id: int | None, anonymous_id: str | None) -> None:
    """Runs after the response: logs the product view (a DB trigger bumps view_count) and refreshes recently-viewed."""
    try:
        async with async_session_factory() as session:
            await ProductRepository(session).record_view(product_id, user_id, anonymous_id)
            if user_id is not None:
                repo = RecentlyViewedRepository(session)
                await repo.upsert(user_id, product_id)
                await repo.trim(user_id, RECENTLY_VIEWED_CAP)
            await session.commit()
    except Exception:  # noqa: BLE001 - analytics must never break a request
        logger.exception("Failed to track product view %s", product_id)


def get_recently_viewed_service(session: AsyncSession = Depends(get_db)) -> RecentlyViewedService:
    return RecentlyViewedService(session)
