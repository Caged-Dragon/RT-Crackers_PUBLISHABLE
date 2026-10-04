from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from core.constants import NOTIFICATION_TYPE_LABELS
from core.schemas import MessageResponse, Page
from customers.auth.dependencies import CurrentUser
from customers.notifications.schemas import NotificationOut, UnreadCount
from customers.notifications.service import NotificationService, get_notification_service
from customers.profiles.schemas import NotificationPreferences, NotificationPreferencesUpdate
from customers.profiles.service import ProfileService, get_profile_service
from utils.pagination import PageParams

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", response_model=Page[NotificationOut], summary="In-app notifications (newest first)")
async def list_notifications(user: CurrentUser, unread_only: bool = False,
                             type: str | None = Query(default=None, pattern="^[OPSF]$", description="O order, P promotion, S system, F festival"),
                             page: PageParams = Depends(), service: NotificationService = Depends(get_notification_service)):
    return await service.list(user, page, unread_only, type)


@router.get("/types", response_model=dict[str, str], summary="Notification type codes and labels")
async def notification_types():
    return NOTIFICATION_TYPE_LABELS


@router.get("/unread-count", response_model=UnreadCount, summary="Unread badge count")
async def unread_count(user: CurrentUser, service: NotificationService = Depends(get_notification_service)):
    return await service.unread(user)


@router.post("/read-all", response_model=UnreadCount, summary="Mark everything as read")
async def read_all(user: CurrentUser, service: NotificationService = Depends(get_notification_service)):
    return await service.mark_all_read(user)


@router.get("/preferences", response_model=NotificationPreferences, summary="E-mail / SMS / WhatsApp opt-ins (same data as /profile)")
async def get_preferences(user: CurrentUser, service: ProfileService = Depends(get_profile_service)):
    return await service.get_preferences(user)


@router.put("/preferences", response_model=NotificationPreferences, summary="Update channel opt-ins")
async def update_preferences(body: NotificationPreferencesUpdate, user: CurrentUser, service: ProfileService = Depends(get_profile_service)):
    return await service.update_preferences(user, body)


@router.post("/{notification_id}/read", response_model=UnreadCount, summary="Mark one notification as read")
async def mark_read(notification_id: int, user: CurrentUser, service: NotificationService = Depends(get_notification_service)):
    return await service.mark_read(user, notification_id)


@router.delete("/{notification_id}", response_model=MessageResponse, summary="Delete one notification")
async def delete_notification(notification_id: int, user: CurrentUser, service: NotificationService = Depends(get_notification_service)):
    await service.delete(user, notification_id)
    return MessageResponse(message="Notification deleted")


@router.delete("", response_model=MessageResponse, summary="Delete all my notifications")
async def delete_all(user: CurrentUser, service: NotificationService = Depends(get_notification_service)):
    await service.delete_all(user)
    return MessageResponse(message="Notifications cleared")
