from __future__ import annotations

from fastapi import APIRouter, Depends

from core.schemas import Page
from customers.categories.schemas import CategoryOut, SubcategoryOut
from customers.categories.service import CategoryService, get_category_service
from customers.products.schemas import ProductCard, ProductFilters
from utils.pagination import PageParams

router = APIRouter(prefix="/categories", tags=["Categories"])


@router.get("", response_model=list[CategoryOut], summary="All categories with their subcategories")
async def list_categories(service: CategoryService = Depends(get_category_service)):
    return await service.tree()


@router.get("/{identifier}", response_model=CategoryOut, summary="One category (id or slug)")
async def get_category(identifier: str, service: CategoryService = Depends(get_category_service)):
    return await service.get(identifier)


@router.get("/{identifier}/subcategories", response_model=list[SubcategoryOut], summary="Subcategories of a category")
async def get_subcategories(identifier: str, service: CategoryService = Depends(get_category_service)):
    return await service.subcategories(identifier)


@router.get("/{identifier}/products", response_model=Page[ProductCard], summary="Products in a category (optionally one subcategory)")
async def category_products(identifier: str, filters: ProductFilters = Depends(), page: PageParams = Depends(),
                            service: CategoryService = Depends(get_category_service)):
    return await service.products(identifier, filters, page)
