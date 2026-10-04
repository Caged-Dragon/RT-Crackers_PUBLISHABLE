from __future__ import annotations

from fastapi import APIRouter, Depends, Query, status

from core.schemas import MessageResponse, Page
from customers.auth.dependencies import CurrentUser
from customers.cart.schemas import CartOut
from customers.wishlist.schemas import WishlistAdd, WishlistContains, WishlistCount, WishlistItemOut, WishlistMoveToCart
from customers.wishlist.service import WishlistService, get_wishlist_service
from utils.pagination import PageParams

router = APIRouter(prefix="/wishlist", tags=["Wishlist"])


@router.get("", response_model=Page[WishlistItemOut], summary="List my wishlist (newest first)")
async def list_wishlist(user: CurrentUser, page: PageParams = Depends(), service: WishlistService = Depends(get_wishlist_service)):
    return await service.list(user, page)


@router.get("/count", response_model=WishlistCount, summary="Number of products in my wishlist")
async def wishlist_count(user: CurrentUser, service: WishlistService = Depends(get_wishlist_service)):
    return await service.count(user)


@router.get("/contains", response_model=WishlistContains, summary="Which of these product ids are wishlisted? (?product_ids=1&product_ids=2)")
async def wishlist_contains(user: CurrentUser, product_ids: list[int] = Query(default=[]), service: WishlistService = Depends(get_wishlist_service)):
    return await service.contains(user, product_ids)


@router.post("", response_model=WishlistCount, status_code=status.HTTP_201_CREATED, summary="Add a product (idempotent)")
async def add_to_wishlist(body: WishlistAdd, user: CurrentUser, service: WishlistService = Depends(get_wishlist_service)):
    return await service.add(user, body.product_id)


@router.delete("/{product_id}", response_model=WishlistCount, summary="Remove a product")
async def remove_from_wishlist(product_id: int, user: CurrentUser, service: WishlistService = Depends(get_wishlist_service)):
    return await service.remove(user, product_id)


@router.delete("", response_model=MessageResponse, summary="Empty my wishlist")
async def clear_wishlist(user: CurrentUser, service: WishlistService = Depends(get_wishlist_service)):
    await service.clear(user)
    return MessageResponse(message="Wishlist cleared")


@router.post("/{product_id}/move-to-cart", response_model=CartOut, summary="Move a wishlisted product into the cart")
async def move_to_cart(product_id: int, user: CurrentUser, body: WishlistMoveToCart | None = None,
                       service: WishlistService = Depends(get_wishlist_service)):
    return await service.move_to_cart(user, product_id, body or WishlistMoveToCart())
