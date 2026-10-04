from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, Depends, Header, Query, Request

from customers.auth.dependencies import OptionalUser
from customers.products.schemas import ProductFilters
from customers.search.schemas import SearchResponse, SuggestionsResponse
from customers.search.service import SearchService, get_search_service, log_search_background
from utils.helpers import client_ip
from utils.pagination import PageParams

router = APIRouter(prefix="/search", tags=["Search"])


@router.get("", response_model=SearchResponse, summary="Search products with filters, facets, sorting and pagination")
async def search_products(request: Request, background: BackgroundTasks, user: OptionalUser,
                          q: str | None = Query(None, max_length=100, description="Search text (all words must match)"),
                          filters: ProductFilters = Depends(), page: PageParams = Depends(),
                          anonymous_id: str | None = Header(default=None, alias="X-Anonymous-Id", max_length=64),
                          service: SearchService = Depends(get_search_service)):
    filters.q = q
    result = await service.search(filters, page)
    if result.query and page.page == 1:
        background.add_task(log_search_background, result.query, result.total, user.user_id if user else None, anonymous_id, client_ip(request))
    return result


@router.get("/suggestions", response_model=SuggestionsResponse, summary="Type-ahead suggestions")
async def suggestions(q: str = Query(..., min_length=2, max_length=60), limit: int = Query(6, ge=1, le=15),
                      service: SearchService = Depends(get_search_service)):
    return await service.suggestions(q, limit)
