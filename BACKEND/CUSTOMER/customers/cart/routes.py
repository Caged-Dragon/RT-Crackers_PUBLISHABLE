from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Header, Response

from core.constants import CART_TOKEN_HEADER
from customers.auth.dependencies import CurrentUser
from customers.cart.dependencies import CartCtx
from customers.cart.schemas import CartCount, CartCouponRequest, CartItemAdd, CartItemUpdate, CartMergeOut, CartOut
from customers.cart.service import CartService, get_cart_service

router = APIRouter(prefix="/cart", tags=["Cart"])


def _emit(response: Response, cart: CartOut) -> CartOut:
    """Guest carts hand the refreshed token back in the body *and* the X-Cart-Token response header."""
    if cart.cart_token:
        response.headers[CART_TOKEN_HEADER] = cart.cart_token
    return cart


@router.get("", response_model=CartOut, summary="Get the cart (guest via X-Cart-Token, customer via Bearer token)")
async def get_cart(ctx: CartCtx, response: Response, service: CartService = Depends(get_cart_service)):
    return _emit(response, await service.get(ctx))


@router.get("/count", response_model=CartCount, summary="Lightweight item/line counts for the header badge")
async def cart_count(ctx: CartCtx, service: CartService = Depends(get_cart_service)):
    return await service.counts(ctx)


@router.get("/summary", response_model=CartOut, summary="Cart summary with totals, savings and minimum-order status")
async def cart_summary(ctx: CartCtx, response: Response, service: CartService = Depends(get_cart_service)):
    return _emit(response, await service.get(ctx))


@router.post("/items", response_model=CartOut, summary="Add an item (quantities add up if the line exists)")
async def add_item(body: CartItemAdd, ctx: CartCtx, response: Response, service: CartService = Depends(get_cart_service)):
    return _emit(response, await service.add_item(ctx, body))


@router.patch("/items/{line_key}", response_model=CartOut, summary="Set the quantity of a cart line")
async def update_item(line_key: str, body: CartItemUpdate, ctx: CartCtx, response: Response, service: CartService = Depends(get_cart_service)):
    return _emit(response, await service.update_item(ctx, line_key, body.quantity))


@router.delete("/items/{line_key}", response_model=CartOut, summary="Remove a cart line")
async def remove_item(line_key: str, ctx: CartCtx, response: Response, service: CartService = Depends(get_cart_service)):
    return _emit(response, await service.remove_item(ctx, line_key))


@router.delete("", response_model=CartOut, summary="Empty the cart")
async def clear_cart(ctx: CartCtx, response: Response, service: CartService = Depends(get_cart_service)):
    return _emit(response, await service.clear(ctx))


@router.post("/coupon", response_model=CartOut, summary="Apply a coupon to the cart")
async def apply_coupon(body: CartCouponRequest, ctx: CartCtx, response: Response, service: CartService = Depends(get_cart_service)):
    return _emit(response, await service.apply_coupon(ctx, body.code))


@router.delete("/coupon", response_model=CartOut, summary="Remove the applied coupon")
async def remove_coupon(ctx: CartCtx, response: Response, service: CartService = Depends(get_cart_service)):
    return _emit(response, await service.remove_coupon(ctx))


@router.post("/merge", response_model=CartMergeOut, summary="After login: merge the guest cart (X-Cart-Token) into the customer cart")
async def merge_guest_cart(user: CurrentUser,
                           x_cart_token: Annotated[str | None, Header(alias=CART_TOKEN_HEADER)] = None,
                           service: CartService = Depends(get_cart_service)):
    return await service.merge(user, x_cart_token)
