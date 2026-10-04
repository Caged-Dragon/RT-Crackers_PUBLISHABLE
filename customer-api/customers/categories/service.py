from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.exceptions import NotFoundError
from core.schemas import Page
from customers.categories.repository import CategoryRepository
from customers.categories.schemas import CategoryOut, SubcategoryOut
from customers.products.repository import ProductRepository
from customers.products.schemas import ProductCard, ProductFilters
from customers.products.service import to_card
from utils.pagination import PageParams, paginate


class CategoryService:
    def __init__(self, session: AsyncSession):
        self.repo = CategoryRepository(session)
        self.products = ProductRepository(session)

    @staticmethod
    def _sub_out(s, counts: dict[int, int]) -> SubcategoryOut:
        return SubcategoryOut(subcategory_id=s.subcategory_id, category_id=s.category_id, name=s.subcategory_name, slug=s.slug,
                              description=s.description, image_url=s.image_url, product_count=counts.get(s.subcategory_id, 0))

    async def tree(self) -> list[CategoryOut]:
        cats = await self.repo.list_active()
        by_cat, by_sub = await self.repo.product_counts()
        subs = await self.repo.subcategories([c.category_id for c in cats])
        grouped: dict[int, list[SubcategoryOut]] = {}
        for s in subs:
            grouped.setdefault(s.category_id, []).append(self._sub_out(s, by_sub))
        return [CategoryOut(category_id=c.category_id, name=c.category_name, slug=c.slug, description=c.description, image_url=c.image_url,
                            product_count=by_cat.get(c.category_id, 0), subcategories=grouped.get(c.category_id, [])) for c in cats]

    async def _require(self, identifier: str):
        cat = await self.repo.get_active(identifier)
        if cat is None:
            raise NotFoundError("Category not found", code="category_not_found")
        return cat

    async def get(self, identifier: str) -> CategoryOut:
        cat = await self._require(identifier)
        by_cat, by_sub = await self.repo.product_counts()
        subs = await self.repo.subcategories([cat.category_id])
        return CategoryOut(category_id=cat.category_id, name=cat.category_name, slug=cat.slug, description=cat.description, image_url=cat.image_url,
                           product_count=by_cat.get(cat.category_id, 0), subcategories=[self._sub_out(s, by_sub) for s in subs])

    async def subcategories(self, identifier: str) -> list[SubcategoryOut]:
        cat = await self._require(identifier)
        _, by_sub = await self.repo.product_counts()
        return [self._sub_out(s, by_sub) for s in await self.repo.subcategories([cat.category_id])]

    async def products(self, identifier: str, filters: ProductFilters, page: PageParams) -> Page[ProductCard]:
        cat = await self._require(identifier)
        if filters.subcategory_id and not await self.repo.get_subcategory(cat.category_id, filters.subcategory_id):
            raise NotFoundError("Subcategory not found in this category", code="subcategory_not_found")
        filters.category_id, filters.q = cat.category_id, None
        rows, total = await self.products.list_cards(filters, page)
        return paginate([to_card(r) for r in rows], total, page)


def get_category_service(session: AsyncSession = Depends(get_db)) -> CategoryService:
    return CategoryService(session)
