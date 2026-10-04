from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from customers.auth.dependencies import CurrentUser
from customers.dashboard.schemas import DashboardOut
from customers.dashboard.service import DashboardService, get_dashboard_service

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("", response_model=DashboardOut, summary="Account overview: order counts, wishlist, recent orders, addresses, referrals")
async def dashboard(user: CurrentUser, service: Annotated[DashboardService, Depends(get_dashboard_service)]) -> DashboardOut:
    return await service.overview(user)
