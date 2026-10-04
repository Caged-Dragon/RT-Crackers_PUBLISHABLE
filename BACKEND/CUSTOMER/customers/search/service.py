from __future__ import annotations

import logging
import math
from datetime import timedelta

from fastapi import Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import PRODUCT_ACTIVE
from core.database import async_session_factory, get_db
from customers.categories.models import Category
from customers.products.models import Brand, Product, SearchLog
from customers.products.repository import ProductRepository, _PRIMARY_IMAGE, escape_like
from customers.products.schemas import ProductFilters
from customers.products.service import to_card
from customers.search.schemas import FacetOption, SearchFacets, SearchResponse, SuggestedLink, SuggestedProduct, SuggestionsResponse
from utils.helpers import utcnow
from utils.pagination import PageParams

logger = logging.getLogger("rtcrackers.search")


class SearchService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.products = ProductRepository(session)

    async def search(self, filters: ProductFilters, page: PageParams) -> SearchResponse:
        filters.q = (filters.q or "").strip()[:100] or None
        if filters.q is None and filters.sort == "relevance":
            filters.sort = "popular"
        rows, total = await self.products.list_cards(filters, page)
        facets = await self.products.facets(filters)
        return SearchResponse(
            query=filters.q, sort=filters.sort, items=[to_card(r) for r in rows], total=total, page=page.page, page_size=page.page_size,
            pages=math.ceil(total / page.page_size) if total else 0,
            facets=SearchFacets(categories=[FacetOption(id=i, name=n, count=c) for i, n, c in facets["categories"]],
                                brands=[FacetOption(id=i, name=n, count=c) for i, n, c in facets["brands"]],
                                price_min=facets["price_min"], price_max=facets["price_max"]))

    async def suggestions(self, q: str, limit: int) -> SuggestionsResponse:
        q = q.strip()[:60]
        like_start, like_any = f"{escape_like(q.lower())}%", f"%{escape_like(q.lower())}%"
        name = func.lower(Product.product_name)
        prod_stmt = (select(Product.product_id, Product.product_name, Product.slug, _PRIMARY_IMAGE, Product.selling_price)
                     .join(Category, Category.category_id == Product.category_id)
                     .where(Product.status == PRODUCT_ACTIVE, Category.is_active.is_(True), name.like(like_any, escape="\\"))
                     .order_by(name.like(like_start, escape="\\").desc(), Product.sales_count.desc(), Product.product_id).limit(limit))
        products = (await self.session.execute(prod_stmt)).all()
        cats = (await self.session.execute(
            select(Category.category_id, Category.category_name, Category.slug).where(Category.is_active.is_(True), func.lower(Category.category_name).like(like_any, escape="\\")).limit(4))).all()
        brands = (await self.session.execute(
            select(Brand.brand_id, Brand.brand_name, Brand.slug).where(Brand.is_active.is_(True), func.lower(Brand.brand_name).like(like_any, escape="\\")).limit(4))).all()
        since = utcnow() - timedelta(days=30)
        lowered = func.lower(SearchLog.search_query)
        popular = (await self.session.execute(
            select(lowered).where(SearchLog.created_at >= since, SearchLog.results_count > 0, lowered.like(like_start, escape="\\"))
            .group_by(lowered).order_by(func.count().desc()).limit(5))).scalars().all()
        return SuggestionsResponse(
            query=q, products=[SuggestedProduct(product_id=r[0], name=r[1], slug=r[2], image=r[3], selling_price=r[4]) for r in products],
            categories=[SuggestedLink(id=i, name=n, slug=s) for i, n, s in cats], brands=[SuggestedLink(id=i, name=n, slug=s) for i, n, s in brands],
            popular_searches=list(popular))


async def log_search_background(query: str, results: int, user_id: int | None, anonymous_id: str | None, ip: str | None) -> None:
    try:
        async with async_session_factory() as session:
            session.add(SearchLog(search_query=query[:255], results_count=results, user_id=user_id, anonymous_id=anonymous_id, ip_address=ip))
            await session.commit()
    except Exception:  # noqa: BLE001 - analytics must never break a request
        logger.exception("Failed to log search")


def get_search_service(session: AsyncSession = Depends(get_db)) -> SearchService:
    return SearchService(session)
