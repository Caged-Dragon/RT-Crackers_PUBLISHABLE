from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import PRODUCT_ACTIVE
from customers.categories.models import Category, SubCategory
from customers.products.models import Product


class CategoryRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def list_active(self) -> list[Category]:
        stmt = select(Category).where(Category.is_active.is_(True)).order_by(Category.display_order, Category.category_name)
        return list((await self.session.execute(stmt)).scalars())

    async def get_active(self, identifier: str) -> Category | None:
        stmt = select(Category).where(Category.is_active.is_(True))
        stmt = stmt.where(Category.category_id == int(identifier)) if identifier.isdigit() else stmt.where(Category.slug == identifier)
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def subcategories(self, category_ids: list[int] | None = None) -> list[SubCategory]:
        stmt = select(SubCategory).where(SubCategory.is_active.is_(True)).order_by(SubCategory.display_order, SubCategory.subcategory_name)
        if category_ids is not None:
            stmt = stmt.where(SubCategory.category_id.in_(category_ids))
        return list((await self.session.execute(stmt)).scalars())

    async def get_subcategory(self, category_id: int, subcategory_id: int) -> SubCategory | None:
        stmt = select(SubCategory).where(SubCategory.category_id == category_id, SubCategory.subcategory_id == subcategory_id, SubCategory.is_active.is_(True))
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def product_counts(self) -> tuple[dict[int, int], dict[int, int]]:
        base = select(Product.category_id, Product.subcategory_id, func.count()).where(Product.status == PRODUCT_ACTIVE).group_by(Product.category_id, Product.subcategory_id)
        by_cat: dict[int, int] = {}
        by_sub: dict[int, int] = {}
        for cat_id, sub_id, count in (await self.session.execute(base)).all():
            by_cat[cat_id] = by_cat.get(cat_id, 0) + count
            if sub_id is not None:
                by_sub[sub_id] = count
        return by_cat, by_sub
