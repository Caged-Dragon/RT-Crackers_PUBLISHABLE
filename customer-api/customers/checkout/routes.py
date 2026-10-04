from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from customers.auth.dependencies import CurrentUser
from customers.checkout.schemas import CheckoutRequest, CheckoutSummary, ShippingOptionsOut
from customers.checkout.service import CheckoutService, get_checkout_service

router = APIRouter(prefix="/checkout", tags=["Checkout"])
Service = Annotated[CheckoutService, Depends(get_checkout_service)]


@router.get("/shipping-options", response_model=ShippingOptionsOut, summary="Shipping methods, charges and delivery dates for a saved address")
async def shipping_options(user: CurrentUser, service: Service, address_id: Annotated[int, Query(gt=0)]) -> ShippingOptionsOut:
    return await service.shipping_options(user, address_id)


@router.post("/summary", response_model=CheckoutSummary,
             summary="Order summary: address, shipping, coupon validation, tax and total (nothing is saved)")
async def summary(body: CheckoutRequest, user: CurrentUser, service: Service) -> CheckoutSummary:
    return await service.summary_for(user, body)
