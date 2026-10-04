from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import FLAG_WISHLIST
from core.database import get_db
from core.exceptions import NotFoundError, ServiceUnavailableError
from core.schemas import Page
from core.system_models import is_feature_enabled
from customers.auth.models import User
from customers.cart.schemas import CartItemAdd, CartOut
from customers.cart.service import CartContext, CartService
from customers.products.repository import ProductRepository
from customers.products.service import to_card
from customers.wishlist.repository import WishlistRepository
from customers.wishlist.schemas import WishlistContains, WishlistCount, WishlistItemOut, WishlistMoveToCart
from utils.pagination import PageParams, paginate


class WishlistService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = WishlistRepository(session)
        self.products = ProductRepository(session)

    async def _ensure_enabled(self) -> None:
        if not await is_feature_enabled(self.session, FLAG_WISHLIST, default=True):
            raise ServiceUnavailableError("The wishlist is currently disabled", code="feature_disabled")

    async def list(self, user: User, page: PageParams) -> Page[WishlistItemOut]:
        await self._ensure_enabled()
        wishlist = await self.repo.get_default(user.user_id)
        if wishlist is None:
            return paginate([], 0, page)
        rows, total = await self.repo.page(wishlist.wishlist_id, page)
        cards = {r.Product.product_id: to_card(r) for r in await self.products.cards_by_ids([pid for pid, _ in rows])}
        items = [WishlistItemOut(product=cards[pid], added_at=added) for pid, added in rows if pid in cards]
        return paginate(items, total, page)

    async def add(self, user: User, product_id: int) -> WishlistCount:
        await self._ensure_enabled()
        if await self.products.get_by_id(product_id) is None:
            raise NotFoundError("Product not found", code="product_not_found")
        wishlist = await self.repo.get_or_create_default(user.user_id)
        await self.repo.add(wishlist.wishlist_id, product_id)
        await self.session.commit()
        return await self.count(user)

    async def remove(self, user: User, product_id: int) -> WishlistCount:
        await self._ensure_enabled()
        wishlist = await self.repo.get_default(user.user_id)
        if wishlist is None or not await self.repo.remove(wishlist.wishlist_id, product_id):
            raise NotFoundError("This product is not in your wishlist", code="wishlist_item_not_found")
        await self.session.commit()
        return await self.count(user)

    async def clear(self, user: User) -> None:
        await self._ensure_enabled()
        wishlist = await self.repo.get_default(user.user_id)
        if wishlist is not None:
            await self.repo.clear(wishlist.wishlist_id)
            await self.session.commit()

    async def count(self, user: User) -> WishlistCount:
        return WishlistCount(count=await self.repo.count_for_user(user.user_id))

    async def contains(self, user: User, product_ids: list[int]) -> WishlistContains:
        wishlist = await self.repo.get_default(user.user_id)
        found = await self.repo.contains(wishlist.wishlist_id, product_ids[:100]) if wishlist else []
        return WishlistContains(product_ids=found)

    async def move_to_cart(self, user: User, product_id: int, data: WishlistMoveToCart) -> CartOut:
        await self._ensure_enabled()
        wishlist = await self.repo.get_default(user.user_id)
        if wishlist is None or not await self.repo.has(wishlist.wishlist_id, product_id):
            raise NotFoundError("This product is not in your wishlist", code="wishlist_item_not_found")
        cart = await CartService(self.session).add_item(
            CartContext(user=user), CartItemAdd(product_id=product_id, variant_id=data.variant_id, quantity=data.quantity))
        if data.remove_from_wishlist:
            await self.repo.remove(wishlist.wishlist_id, product_id)
            await self.session.commit()
        return cart


def get_wishlist_service(session: AsyncSession = Depends(get_db)) -> WishlistService:
    return WishlistService(session)
