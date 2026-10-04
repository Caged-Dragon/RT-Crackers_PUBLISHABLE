from __future__ import annotations

from fastapi import APIRouter, Depends, Response

from core.constants import CART_TOKEN_HEADER
from core.schemas import Page
from customers.auth.dependencies import CurrentUser, OptionalUser
from customers.cart.dependencies import CartCtx
from customers.cart.schemas import CartOut
from customers.cart.service import CartService, get_cart_service
from customers.coupons.schemas import CouponApplyRequest, CouponOut, CouponUsageOut, CouponValidateRequest, CouponValidation
from customers.coupons.service import CouponService, get_coupon_service
from utils.pagination import PageParams

router = APIRouter(prefix="/coupons", tags=["Coupons"])


@router.get("", response_model=list[CouponOut], summary="Coupons you can use right now")
async def available_coupons(user: OptionalUser, service: CouponService = Depends(get_coupon_service)):
    return await service.available(user)


@router.post("/validate", response_model=CouponValidation, summary="Check a coupon against an amount (defaults to your cart subtotal)")
async def validate_coupon(body: CouponValidateRequest, ctx: CartCtx, coupons: CouponService = Depends(get_coupon_service),
                          cart: CartService = Depends(get_cart_service)):
    amount = body.order_amount if body.order_amount is not None else await cart.subtotal_for(ctx)
    return await coupons.validate(ctx.user, body.code, amount)


@router.post("/apply", response_model=CartOut, summary="Apply a coupon to the cart")
async def apply_coupon(body: CouponApplyRequest, ctx: CartCtx, response: Response, cart: CartService = Depends(get_cart_service)):
    out = await cart.apply_coupon(ctx, body.code)
    if out.cart_token:
        response.headers[CART_TOKEN_HEADER] = out.cart_token
    return out


@router.delete("/apply", response_model=CartOut, summary="Remove the applied coupon from the cart")
async def remove_coupon(ctx: CartCtx, response: Response, cart: CartService = Depends(get_cart_service)):
    out = await cart.remove_coupon(ctx)
    if out.cart_token:
        response.headers[CART_TOKEN_HEADER] = out.cart_token
    return out


@router.get("/usage", response_model=Page[CouponUsageOut], summary="My coupon usage history")
async def coupon_usage(user: CurrentUser, page: PageParams = Depends(), service: CouponService = Depends(get_coupon_service)):
    return await service.usage_history(user, page)
