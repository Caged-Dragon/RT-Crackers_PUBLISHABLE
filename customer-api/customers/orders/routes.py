from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query, Response, status

from core.schemas import Page
from customers.auth.dependencies import CurrentUser
from customers.checkout.schemas import CheckoutRequest
from customers.orders.schemas import CancelOrderRequest, OrderDetailOut, OrderSummaryOut, ReorderOut
from customers.orders.service import OrderService, get_order_service
from utils.pagination import PageParams

router = APIRouter(prefix="/orders", tags=["Orders"])
Service = Annotated[OrderService, Depends(get_order_service)]
OrderRef = Annotated[str, Path(min_length=1, max_length=25, description="Order number (RTC...) or numeric order id")]


@router.post("", response_model=OrderDetailOut, status_code=status.HTTP_201_CREATED,
             summary="Place an order from the cart (Cash on Delivery)")
async def create_order(body: CheckoutRequest, user: CurrentUser, service: Service) -> OrderDetailOut:
    return await service.place(user, body)


@router.get("", response_model=Page[OrderSummaryOut], summary="My orders, newest first")
async def list_orders(user: CurrentUser, service: Service, page: Annotated[PageParams, Depends()],
                      status_code: Annotated[str | None, Query(alias="status", pattern="^[PCKSODXR]$", description="Filter by order status code")] = None
                      ) -> Page[OrderSummaryOut]:
    return await service.list(user, page, status_code)


@router.get("/{order_ref}", response_model=OrderDetailOut, summary="Order details")
async def get_order(order_ref: OrderRef, user: CurrentUser, service: Service) -> OrderDetailOut:
    return await service.get(user, order_ref)


@router.post("/{order_ref}/cancel", response_model=OrderDetailOut, summary="Cancel an order that is still placed or confirmed")
async def cancel_order(order_ref: OrderRef, body: CancelOrderRequest, user: CurrentUser, service: Service) -> OrderDetailOut:
    return await service.cancel(user, order_ref, body.reason)


@router.post("/{order_ref}/reorder", response_model=ReorderOut, summary="Add the items of a past order to the cart")
async def reorder(order_ref: OrderRef, user: CurrentUser, service: Service) -> ReorderOut:
    return await service.reorder(user, order_ref)


@router.get("/{order_ref}/invoice", summary="Download the invoice as a PDF",
            responses={200: {"content": {"application/pdf": {}}, "description": "Invoice PDF"}})
async def download_invoice(order_ref: OrderRef, user: CurrentUser, service: Service) -> Response:
    filename, pdf = await service.invoice_pdf(user, order_ref)
    return Response(content=pdf, media_type="application/pdf", headers={"Content-Disposition": f'attachment; filename="{filename}"'})
