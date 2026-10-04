from __future__ import annotations

from typing import Any

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.exceptions import NotFoundError
from core.schemas import Page
from customers.products.repository import ProductRepository
from customers.products.schemas import (
    AttributeOut, BrandRef, CategoryRef, ProductCard, ProductDetail, ProductFilters, ProductImageOut, VariantOut,
)
from utils.pagination import PageParams, paginate


def to_card(row: Any) -> ProductCard:
    p = row.Product
    return ProductCard(
        product_id=p.product_id, sku=p.sku, slug=p.slug, name=p.product_name, short_description=p.short_description, mrp=p.mrp,
        selling_price=p.selling_price, discount_percentage=p.discount_percentage, primary_image=row.primary_image,
        brand_name=row.brand_name, category_id=p.category_id, category_name=row.category_name, rating_average=p.rating_average,
        rating_count=p.rating_count, in_stock=p.stock_quantity > 0, is_featured=p.is_featured, is_trending=p.is_trending,
        is_new_arrival=p.is_new_arrival, has_variants=bool(row.has_variants))


class ProductService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = ProductRepository(session)

    async def list_products(self, filters: ProductFilters, page: PageParams) -> Page[ProductCard]:
        rows, total = await self.repo.list_cards(filters, page)
        return paginate([to_card(r) for r in rows], total, page)

    async def _curated(self, limit: int, sort: str, **flags: bool) -> list[ProductCard]:
        rows = await self.repo.top_cards(ProductFilters(sort=sort, **flags), limit)
        return [to_card(r) for r in rows]

    async def featured(self, limit: int) -> list[ProductCard]:
        return await self._curated(limit, "popular", featured=True)

    async def trending(self, limit: int) -> list[ProductCard]:
        return await self._curated(limit, "popular", trending=True)

    async def new_arrivals(self, limit: int) -> list[ProductCard]:
        return await self._curated(limit, "newest", new_arrival=True)

    async def _require(self, identifier: str):
        found = await self.repo.get_active(identifier)
        if found is None:
            raise NotFoundError("Product not found", code="product_not_found")
        return found

    async def get_detail(self, identifier: str) -> ProductDetail:
        product, category, brand = await self._require(identifier)
        images = await self.repo.images(product.product_id)
        variants = await self.repo.variants(product.product_id)
        attrs = await self.repo.attributes(product.product_id)
        available = sum(a for _, a in variants) if variants else await self.repo.available_quantity(product.product_id, None)
        primary = images[0].image_url if images else None
        card = to_card(type("R", (), {"Product": product, "primary_image": primary, "brand_name": brand.brand_name if brand else None,
                                      "category_name": category.category_name, "has_variants": bool(variants)})())
        card_data = card.model_dump()
        card_data["in_stock"] = available > 0
        return ProductDetail(
            **card_data, description=product.description, safety_instructions=product.safety_instructions, weight=product.weight,
            length=product.length, width=product.width, height=product.height, gst_percentage=product.gst_percentage,
            country_of_origin=product.country_of_origin, manufacturer=product.manufacturer, subcategory_id=product.subcategory_id,
            available_quantity=available, view_count=product.view_count, sales_count=product.sales_count, meta_title=product.meta_title,
            meta_description=product.meta_description, created_at=product.created_at,
            category=CategoryRef(category_id=category.category_id, name=category.category_name, slug=category.slug),
            brand=BrandRef(brand_id=brand.brand_id, name=brand.brand_name, slug=brand.slug) if brand else None,
            images=[ProductImageOut.model_validate(i) for i in images],
            variants=[self._variant_out(v, a) for v, a in variants],
            attributes=[AttributeOut(attribute_code=a.attribute_code, name=a.attribute_name, value=v.value_text, unit=a.unit, variant_id=v.variant_id)
                        for a, v in attrs])

    @staticmethod
    def _variant_out(v, available: int) -> VariantOut:
        discount = round((v.mrp - v.selling_price) * 100 / v.mrp, 2) if v.mrp else 0
        return VariantOut(variant_id=v.variant_id, sku=v.variant_sku, name=v.variant_name, pack_size=v.pack_size, mrp=v.mrp,
                          selling_price=v.selling_price, discount_percentage=discount, weight=v.weight, in_stock=available > 0,
                          available_quantity=available)

    async def images(self, identifier: str):
        product, _, _ = await self._require(identifier)
        return [ProductImageOut.model_validate(i) for i in await self.repo.images(product.product_id)]

    async def variants(self, identifier: str) -> list[VariantOut]:
        product, _, _ = await self._require(identifier)
        return [self._variant_out(v, a) for v, a in await self.repo.variants(product.product_id)]

    async def attributes(self, identifier: str) -> list[AttributeOut]:
        product, _, _ = await self._require(identifier)
        return [AttributeOut(attribute_code=a.attribute_code, name=a.attribute_name, value=v.value_text, unit=a.unit, variant_id=v.variant_id)
                for a, v in await self.repo.attributes(product.product_id)]

    async def related(self, identifier: str, limit: int) -> list[ProductCard]:
        product, _, _ = await self._require(identifier)
        return [to_card(r) for r in await self.repo.related(product, limit)]

    async def product_id_for(self, identifier: str) -> int:
        return (await self._require(identifier))[0].product_id


def get_product_service(session: AsyncSession = Depends(get_db)) -> ProductService:
    return ProductService(session)
