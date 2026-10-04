from __future__ import annotations

from decimal import Decimal
from typing import Any

from sqlalchemy import Select, and_, case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import PRODUCT_ACTIVE
from customers.categories.models import Category
from customers.products.models import (
    AttributeValue, Brand, Inventory, InventoryMovement, Product, ProductAttribute, ProductImage, ProductVariant, ProductView,
)
from customers.products.schemas import ProductFilters
from utils.pagination import PageParams


def escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


_PRIMARY_IMAGE = (select(ProductImage.image_url).where(ProductImage.product_id == Product.product_id)
                  .order_by(ProductImage.is_primary.desc(), ProductImage.display_order, ProductImage.product_image_id)
                  .limit(1).correlate(Product).scalar_subquery())
_HAS_VARIANTS = (select(func.count()).select_from(ProductVariant)
                 .where(ProductVariant.product_id == Product.product_id, ProductVariant.is_active.is_(True))
                 .correlate(Product).scalar_subquery())


class ProductRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # ------------------------------------------------------------- listing
    @staticmethod
    def _card_columns() -> tuple:
        return (Product, _PRIMARY_IMAGE.label("primary_image"), Brand.brand_name.label("brand_name"),
                Category.category_name.label("category_name"), (_HAS_VARIANTS > 0).label("has_variants"))

    @staticmethod
    def _joined(stmt: Select) -> Select:
        return (stmt.join(Category, Category.category_id == Product.category_id)
                .outerjoin(Brand, Brand.brand_id == Product.brand_id)
                .where(Product.status == PRODUCT_ACTIVE, Category.is_active.is_(True)))

    @staticmethod
    def _apply_filters(stmt: Select, f: ProductFilters) -> Select:
        conds: list[Any] = []
        if f.category_id:
            conds.append(Product.category_id == f.category_id)
        if f.subcategory_id:
            conds.append(Product.subcategory_id == f.subcategory_id)
        if f.brand_id:
            conds.append(Product.brand_id == f.brand_id)
        if f.min_price is not None:
            conds.append(Product.selling_price >= f.min_price)
        if f.max_price is not None:
            conds.append(Product.selling_price <= f.max_price)
        if f.min_rating is not None:
            conds.append(Product.rating_average >= Decimal(str(f.min_rating)))
        if f.in_stock:
            conds.append(Product.stock_quantity > 0)
        if f.featured is not None:
            conds.append(Product.is_featured.is_(f.featured))
        if f.trending is not None:
            conds.append(Product.is_trending.is_(f.trending))
        if f.new_arrival is not None:
            conds.append(Product.is_new_arrival.is_(f.new_arrival))
        if f.q:
            for token in f.q.lower().split()[:6]:
                pat = f"%{escape_like(token)}%"
                conds.append(or_(Product.product_name.ilike(pat, escape="\\"), Product.sku.ilike(pat, escape="\\"),
                                 Product.short_description.ilike(pat, escape="\\"), Product.meta_keywords.ilike(pat, escape="\\"),
                                 Brand.brand_name.ilike(pat, escape="\\"), Category.category_name.ilike(pat, escape="\\")))
        return stmt.where(and_(*conds)) if conds else stmt

    @staticmethod
    def _order(stmt: Select, f: ProductFilters) -> Select:
        sort = f.sort
        if sort == "relevance" and not f.q:
            sort = "popular"
        if sort == "relevance":
            q = (f.q or "").lower().strip()
            name = func.lower(Product.product_name)
            rank = case((name == q, 0), (name.like(f"{escape_like(q)}%", escape="\\"), 1), (name.like(f"%{escape_like(q)}%", escape="\\"), 2), else_=3)
            return stmt.order_by(rank, Product.sales_count.desc(), Product.product_id)
        orders = {
            "newest": (Product.created_at.desc(), Product.product_id.desc()),
            "price_asc": (Product.selling_price.asc(), Product.product_id),
            "price_desc": (Product.selling_price.desc(), Product.product_id),
            "popular": (Product.sales_count.desc(), Product.view_count.desc(), Product.product_id),
            "rating": (Product.rating_average.desc(), Product.rating_count.desc(), Product.product_id),
            "discount": (Product.discount_percentage.desc(), Product.product_id),
            "name_asc": (func.lower(Product.product_name).asc(), Product.product_id),
        }
        return stmt.order_by(*orders.get(sort, orders["newest"]))

    async def list_cards(self, filters: ProductFilters, page: PageParams) -> tuple[list[Any], int]:
        base = self._apply_filters(self._joined(select(Product.product_id)), filters)
        total = int((await self.session.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
        stmt = self._order(self._apply_filters(self._joined(select(*self._card_columns())), filters), filters)
        rows = (await self.session.execute(stmt.limit(page.limit).offset(page.offset))).all()
        return list(rows), total

    async def top_cards(self, filters: ProductFilters, limit: int) -> list[Any]:
        stmt = self._order(self._apply_filters(self._joined(select(*self._card_columns())), filters), filters).limit(limit)
        return list((await self.session.execute(stmt)).all())

    async def cards_by_ids(self, ids: list[int]) -> list[Any]:
        if not ids:
            return []
        stmt = self._joined(select(*self._card_columns())).where(Product.product_id.in_(ids))
        return list((await self.session.execute(stmt)).all())

    async def facets(self, filters: ProductFilters) -> dict[str, Any]:
        """Counts for the category/brand facets and the price range, computed on the *filtered* result set."""
        sub = self._apply_filters(self._joined(select(Product.product_id, Product.category_id, Product.brand_id, Product.selling_price)), filters).subquery()
        cats = (await self.session.execute(
            select(Category.category_id, Category.category_name, func.count()).join(sub, sub.c.category_id == Category.category_id)
            .group_by(Category.category_id, Category.category_name).order_by(func.count().desc()))).all()
        brands = (await self.session.execute(
            select(Brand.brand_id, Brand.brand_name, func.count()).join(sub, sub.c.brand_id == Brand.brand_id)
            .group_by(Brand.brand_id, Brand.brand_name).order_by(func.count().desc()))).all()
        price = (await self.session.execute(select(func.min(sub.c.selling_price), func.max(sub.c.selling_price)))).one()
        return {"categories": cats, "brands": brands, "price_min": price[0], "price_max": price[1]}

    # -------------------------------------------------------------- detail
    async def get_active(self, identifier: str) -> tuple[Product, Category, Brand | None] | None:
        stmt = (select(Product, Category, Brand).join(Category, Category.category_id == Product.category_id)
                .outerjoin(Brand, Brand.brand_id == Product.brand_id)
                .where(Product.status == PRODUCT_ACTIVE, Category.is_active.is_(True)))
        stmt = stmt.where(Product.product_id == int(identifier)) if identifier.isdigit() else stmt.where(Product.slug == identifier)
        row = (await self.session.execute(stmt)).first()
        return (row[0], row[1], row[2]) if row else None

    async def get_by_id(self, product_id: int) -> Product | None:
        return (await self.session.execute(select(Product).where(Product.product_id == product_id, Product.status == PRODUCT_ACTIVE))).scalar_one_or_none()

    async def images(self, product_id: int) -> list[ProductImage]:
        stmt = select(ProductImage).where(ProductImage.product_id == product_id).order_by(ProductImage.is_primary.desc(), ProductImage.display_order, ProductImage.product_image_id)
        return list((await self.session.execute(stmt)).scalars())

    async def variants(self, product_id: int, *, active_only: bool = True) -> list[tuple[ProductVariant, int]]:
        avail = func.coalesce(func.sum(Inventory.quantity_on_hand - Inventory.reserved_quantity), 0)
        stmt = (select(ProductVariant, avail)
                .outerjoin(Inventory, and_(Inventory.product_id == ProductVariant.product_id, Inventory.variant_id == ProductVariant.variant_id))
                .where(ProductVariant.product_id == product_id).group_by(ProductVariant.variant_id)
                .order_by(ProductVariant.selling_price, ProductVariant.variant_id))
        if active_only:
            stmt = stmt.where(ProductVariant.is_active.is_(True))
        return [(v, int(a)) for v, a in (await self.session.execute(stmt)).all()]

    async def get_variant(self, product_id: int, variant_id: int) -> ProductVariant | None:
        stmt = select(ProductVariant).where(ProductVariant.product_id == product_id, ProductVariant.variant_id == variant_id)
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def attributes(self, product_id: int) -> list[tuple[ProductAttribute, AttributeValue]]:
        stmt = (select(ProductAttribute, AttributeValue).join(AttributeValue, AttributeValue.attribute_id == ProductAttribute.attribute_id)
                .where(AttributeValue.product_id == product_id).order_by(ProductAttribute.display_order, ProductAttribute.attribute_id))
        return [(a, v) for a, v in (await self.session.execute(stmt)).all()]

    async def related(self, product: Product, limit: int) -> list[Any]:
        same_sub = case((and_(Product.subcategory_id.is_not(None), Product.subcategory_id == product.subcategory_id), 0), else_=1)
        stmt = (self._joined(select(*self._card_columns()))
                .where(Product.category_id == product.category_id, Product.product_id != product.product_id)
                .order_by(same_sub, Product.is_featured.desc(), Product.sales_count.desc(), Product.product_id).limit(limit))
        return list((await self.session.execute(stmt)).all())

    # ----------------------------------------------------------- inventory
    async def available_quantity(self, product_id: int, variant_id: int | None) -> int:
        stmt = select(func.coalesce(func.sum(Inventory.quantity_on_hand - Inventory.reserved_quantity), 0)).where(Inventory.product_id == product_id)
        stmt = stmt.where(Inventory.variant_id == variant_id) if variant_id is not None else stmt.where(Inventory.variant_id.is_(None))
        return int((await self.session.execute(stmt)).scalar_one())

    async def lock_inventory(self, keys: list[tuple[int, int | None]]) -> dict[tuple[int, int | None], Inventory]:
        """Row-locks the inventory rows (sorted to avoid deadlocks) and returns them keyed by (product, variant)."""
        if not keys:
            return {}
        conds = [and_(Inventory.product_id == p, Inventory.variant_id == v if v is not None else Inventory.variant_id.is_(None)) for p, v in keys]
        stmt = select(Inventory).where(or_(*conds)).order_by(Inventory.inventory_id).with_for_update()
        return {(i.product_id, i.variant_id): i for i in (await self.session.execute(stmt)).scalars()}

    async def add_movement(self, movement: InventoryMovement) -> None:
        self.session.add(movement)
        await self.session.flush()

    async def record_view(self, product_id: int, user_id: int | None, anonymous_id: str | None) -> None:
        self.session.add(ProductView(product_id=product_id, user_id=user_id, anonymous_id=anonymous_id))
        await self.session.flush()
