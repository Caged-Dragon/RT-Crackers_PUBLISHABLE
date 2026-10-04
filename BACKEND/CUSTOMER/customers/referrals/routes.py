from __future__ import annotations

from fastapi import APIRouter, Depends

from customers.auth.dependencies import CurrentUser
from customers.referrals.schemas import ReferralCodeOut, ReferralHistoryItem, ReferralStats, RewardOut
from customers.referrals.service import ReferralService, get_referral_service

router = APIRouter(prefix="/referrals", tags=["Referrals"])


@router.get("/code", response_model=ReferralCodeOut, summary="My referral code, share link and reward amounts")
async def my_code(user: CurrentUser, service: ReferralService = Depends(get_referral_service)):
    return await service.code(user)


@router.get("/history", response_model=list[ReferralHistoryItem], summary="People who signed up with my code")
async def history(user: CurrentUser, service: ReferralService = Depends(get_referral_service)):
    return await service.history(user)


@router.get("/rewards", response_model=list[RewardOut], summary="My referral rewards (granted ones include the coupon code)")
async def rewards(user: CurrentUser, service: ReferralService = Depends(get_referral_service)):
    return await service.rewards(user)


@router.get("/stats", response_model=ReferralStats, summary="Referral totals")
async def stats(user: CurrentUser, service: ReferralService = Depends(get_referral_service)):
    return await service.stats(user)
