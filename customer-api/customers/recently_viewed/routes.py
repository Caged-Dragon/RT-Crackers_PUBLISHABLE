from __future__ import annotations

from fastapi import APIRouter, Depends, Query, status

from core.schemas import MessageResponse
from customers.auth.dependencies import CurrentUser
from customers.recently_viewed.schemas import RecentlyViewedCreate, RecentlyViewedItem
from customers.recently_viewed.service import RecentlyViewedService, get_recently_viewed_service

router = APIRouter(prefix="/recently-viewed", tags=["Recently Viewed"])


@router.post("", response_model=MessageResponse, status_code=status.HTTP_201_CREATED, summary="Store a product view")
async def store_view(body: RecentlyViewedCreate, user: CurrentUser, service: RecentlyViewedService = Depends(get_recently_viewed_service)):
    await service.record(user.user_id, body.product_id)
    return MessageResponse(message="Recorded")


@router.get("", response_model=list[RecentlyViewedItem], summary="List recently viewed products (newest first)")
async def list_recent(user: CurrentUser, limit: int = Query(20, ge=1, le=50), service: RecentlyViewedService = Depends(get_recently_viewed_service)):
    return await service.list(user.user_id, limit)


@router.delete("/{product_id}", response_model=MessageResponse, summary="Remove one product from history")
async def remove_one(product_id: int, user: CurrentUser, service: RecentlyViewedService = Depends(get_recently_viewed_service)):
    await service.remove(user.user_id, product_id)
    return MessageResponse(message="Removed")


@router.delete("", response_model=MessageResponse, summary="Clear history")
async def clear(user: CurrentUser, service: RecentlyViewedService = Depends(get_recently_viewed_service)):
    await service.clear(user.user_id)
    return MessageResponse(message="History cleared")
