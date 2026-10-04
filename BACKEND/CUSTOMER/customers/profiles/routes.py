from __future__ import annotations

from fastapi import APIRouter, Depends, File, UploadFile

from core.schemas import MessageResponse
from customers.auth.dependencies import CurrentUser, Principal, get_principal
from customers.profiles.schemas import (
    AvatarResponse, ChangePasswordRequest, NotificationPreferences, NotificationPreferencesUpdate, ProfileOut, ProfileUpdate,
)
from customers.profiles.service import ProfileService, get_profile_service

router = APIRouter(prefix="/profile", tags=["Profile"])


@router.get("", response_model=ProfileOut, summary="View my profile")
async def get_profile(user: CurrentUser, service: ProfileService = Depends(get_profile_service)):
    return await service.get_profile(user)


@router.put("", response_model=ProfileOut, summary="Edit my profile (only the supplied fields change)")
@router.patch("", response_model=ProfileOut, include_in_schema=False)
async def update_profile(body: ProfileUpdate, user: CurrentUser, service: ProfileService = Depends(get_profile_service)):
    return await service.update_profile(user, body)


@router.post("/avatar", response_model=AvatarResponse, summary="Upload an avatar (JPEG/PNG/WebP, max 5 MB)")
async def upload_avatar(user: CurrentUser, file: UploadFile = File(...), service: ProfileService = Depends(get_profile_service)):
    return await service.upload_avatar(user, file)


@router.delete("/avatar", response_model=MessageResponse, summary="Remove my avatar")
async def remove_avatar(user: CurrentUser, service: ProfileService = Depends(get_profile_service)):
    await service.remove_avatar(user)
    return MessageResponse(message="Avatar removed")


@router.post("/change-password", response_model=MessageResponse, summary="Change password (signs out other devices)")
async def change_password(body: ChangePasswordRequest, principal: Principal = Depends(get_principal), service: ProfileService = Depends(get_profile_service)):
    await service.change_password(principal.user, body, principal.session_id)
    return MessageResponse(message="Password changed")


@router.get("/notification-preferences", response_model=NotificationPreferences, summary="Get notification preferences")
async def get_preferences(user: CurrentUser, service: ProfileService = Depends(get_profile_service)):
    return await service.get_preferences(user)


@router.put("/notification-preferences", response_model=NotificationPreferences, summary="Update notification preferences")
async def update_preferences(body: NotificationPreferencesUpdate, user: CurrentUser, service: ProfileService = Depends(get_profile_service)):
    return await service.update_preferences(user, body)
