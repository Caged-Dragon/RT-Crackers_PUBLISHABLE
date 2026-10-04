from __future__ import annotations

from datetime import datetime

from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import DEFAULT_WISHLIST_NAME, PRODUCT_ACTIVE
from customers.products.models import Product
from customers.wishlist.models import Wishlist, WishlistItem
from utils.pagination import PageParams


class WishlistRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_default(self, user_id: int) -> Wishlist | None:
        stmt = select(Wishlist).where(Wishlist.user_id == user_id, Wishlist.wishlist_name == DEFAULT_WISHLIST_NAME)
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def get_or_create_default(self, user_id: int) -> Wishlist:
        existing = await self.get_default(user_id)
        if existing is not None:
            return existing
        try:
            async with self.session.begin_nested():
                wishlist = Wishlist(user_id=user_id, wishlist_name=DEFAULT_WISHLIST_NAME)
                self.session.add(wishlist)
                await self.session.flush()
            return wishlist
        except IntegrityError:  # uq_wishlists_user_name — lost the race
            existing = await self.get_default(user_id)
            if existing is None:
                raise
            return existing

    async def page(self, wishlist_id: int, page: PageParams) -> tuple[list[tuple[int, datetime]], int]:
        base = (select(WishlistItem.product_id, WishlistItem.created_at)
                .join(Product, Product.product_id == WishlistItem.product_id)
                .where(WishlistItem.wishlist_id == wishlist_id, Product.status == PRODUCT_ACTIVE))
        total = int((await self.session.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
        rows = (await self.session.execute(base.order_by(WishlistItem.created_at.desc(), WishlistItem.product_id)
                                           .limit(page.limit).offset(page.offset))).all()
        return [(r.product_id, r.created_at) for r in rows], total

    async def has(self, wishlist_id: int, product_id: int) -> bool:
        stmt = select(WishlistItem.product_id).where(WishlistItem.wishlist_id == wishlist_id, WishlistItem.product_id == product_id)
        return (await self.session.execute(stmt)).first() is not None

    async def add(self, wishlist_id: int, product_id: int) -> bool:
        """Idempotent insert; returns True when a row was created."""
        if await self.has(wishlist_id, product_id):
            return False
        try:
            async with self.session.begin_nested():
                self.session.add(WishlistItem(wishlist_id=wishlist_id, product_id=product_id))
                await self.session.flush()
            return True
        except IntegrityError:
            return False

    async def remove(self, wishlist_id: int, product_id: int) -> bool:
        result = await self.session.execute(
            delete(WishlistItem).where(WishlistItem.wishlist_id == wishlist_id, WishlistItem.product_id == product_id))
        return (result.rowcount or 0) > 0

    async def clear(self, wishlist_id: int) -> None:
        await self.session.execute(delete(WishlistItem).where(WishlistItem.wishlist_id == wishlist_id))

    async def contains(self, wishlist_id: int, product_ids: list[int]) -> list[int]:
        if not product_ids:
            return []
        stmt = select(WishlistItem.product_id).where(WishlistItem.wishlist_id == wishlist_id, WishlistItem.product_id.in_(product_ids))
        return sorted(int(p) for p in (await self.session.execute(stmt)).scalars())

    async def count_for_user(self, user_id: int) -> int:
        stmt = (select(func.count()).select_from(WishlistItem).join(Wishlist, Wishlist.wishlist_id == WishlistItem.wishlist_id)
                .join(Product, Product.product_id == WishlistItem.product_id)
                .where(Wishlist.user_id == user_id, Product.status == PRODUCT_ACTIVE))
        return int((await self.session.execute(stmt)).scalar_one())
