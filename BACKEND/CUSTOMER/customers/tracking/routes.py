from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Path

from customers.auth.dependencies import CurrentUser
from customers.tracking.schemas import TrackingLookup, TrackingOut
from customers.tracking.service import TrackingService, get_tracking_service

router = APIRouter(prefix="/tracking", tags=["Tracking"])
Service = Annotated[TrackingService, Depends(get_tracking_service)]


@router.post("/lookup", response_model=TrackingOut, summary="Track an order as a guest (order number + delivery phone number)")
async def lookup(body: TrackingLookup, service: Service) -> TrackingOut:
    return await service.lookup(body)


@router.get("/{order_ref}", response_model=TrackingOut, summary="Status timeline and tracking notes of one of my orders")
async def track(order_ref: Annotated[str, Path(min_length=1, max_length=25)], user: CurrentUser, service: Service) -> TrackingOut:
    return await service.for_user(user, order_ref)
