from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, Depends, Header, Query

from core.schemas import Page
from customers.auth.dependencies import OptionalUser
from customers.products.schemas import AttributeOut, ProductCard, ProductDetail, ProductFilters, ProductImageOut, VariantOut
from customers.products.service import ProductService, get_product_service
from customers.recently_viewed.service import track_view_background
from utils.pagination import PageParams

router = APIRouter(prefix="/products", tags=["Products"])


@router.get("", response_model=Page[ProductCard], summary="Product listing with filters, sorting and pagination")
async def list_products(filters: ProductFilters = Depends(), page: PageParams = Depends(), service: ProductService = Depends(get_product_service)):
    filters.q = None
    return await service.list_products(filters, page)


@router.get("/featured", response_model=list[ProductCard], summary="Featured products")
async def featured(limit: int = Query(12, ge=1, le=50), service: ProductService = Depends(get_product_service)):
    return await service.featured(limit)


@router.get("/trending", response_model=list[ProductCard], summary="Trending products")
async def trending(limit: int = Query(12, ge=1, le=50), service: ProductService = Depends(get_product_service)):
    return await service.trending(limit)


@router.get("/new-arrivals", response_model=list[ProductCard], summary="New arrivals")
async def new_arrivals(limit: int = Query(12, ge=1, le=50), service: ProductService = Depends(get_product_service)):
    return await service.new_arrivals(limit)


@router.get("/{identifier}", response_model=ProductDetail, summary="Product details by id or slug (records a view)")
async def product_detail(identifier: str, background: BackgroundTasks, user: OptionalUser,
                         anonymous_id: str | None = Header(default=None, alias="X-Anonymous-Id", max_length=64),
                         service: ProductService = Depends(get_product_service)):
    detail = await service.get_detail(identifier)
    background.add_task(track_view_background, detail.product_id, user.user_id if user else None, anonymous_id)
    return detail


@router.get("/{identifier}/images", response_model=list[ProductImageOut], summary="Product images")
async def product_images(identifier: str, service: ProductService = Depends(get_product_service)):
    return await service.images(identifier)


@router.get("/{identifier}/variants", response_model=list[VariantOut], summary="Product variants with stock")
async def product_variants(identifier: str, service: ProductService = Depends(get_product_service)):
    return await service.variants(identifier)


@router.get("/{identifier}/attributes", response_model=list[AttributeOut], summary="Product attributes")
async def product_attributes(identifier: str, service: ProductService = Depends(get_product_service)):
    return await service.attributes(identifier)


@router.get("/{identifier}/related", response_model=list[ProductCard], summary="Related products")
async def related_products(identifier: str, limit: int = Query(8, ge=1, le=24), service: ProductService = Depends(get_product_service)):
    return await service.related(identifier, limit)
