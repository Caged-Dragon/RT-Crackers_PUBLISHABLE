"""In-app, e-mail and SMS notifications.

`NotificationService.create()` only writes rows (so it is part of the caller's transaction) and returns the
channel deliveries to perform; call `schedule()` *after* the commit so a rolled-back order never sends a mail.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

from fastapi import BackgroundTasks, Depends
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import (
    CHANNEL_EMAIL, CHANNEL_IN_APP, CHANNEL_SMS, DELIVERY_FAILED, DELIVERY_QUEUED, DELIVERY_SENT, MARKETING_NOTIFICATION_TYPES,
    NOTIFICATION_TYPE_LABELS,
)
from core.database import async_session_factory, get_db
from core.exceptions import NotFoundError
from core.schemas import Page
from customers.auth.models import User
from customers.notifications.models import UserNotification
from customers.notifications.repository import NotificationRepository
from customers.notifications.schemas import NotificationOut, UnreadCount
from customers.profiles.models import UserProfile
from utils.email import safe_send_template_email
from utils.pagination import PageParams, paginate
from utils.sms import safe_send_sms

logger = logging.getLogger("rtcrackers.notifications")


@dataclass
class Delivery:
    user_notification_id: int
    channel: str
    email: str | None = None
    phone: str | None = None
    template: str = "GENERIC"
    context: dict[str, Any] = field(default_factory=dict)
    sms_text: str | None = None


async def deliver(deliveries: list[Delivery]) -> None:
    """Background task: sends each queued delivery and records the outcome. Never raises."""
    if not deliveries:
        return
    try:
        async with async_session_factory() as session:
            for d in deliveries:
                ok = False
                try:
                    if d.channel == CHANNEL_EMAIL and d.email:
                        ok = await safe_send_template_email(d.email, d.template, d.context)
                    elif d.channel == CHANNEL_SMS and d.phone and d.sms_text:
                        ok = await safe_send_sms(d.phone, d.sms_text)
                except Exception:  # noqa: BLE001
                    logger.exception("Delivery %s failed", d.user_notification_id)
                await session.execute(update(UserNotification).where(UserNotification.user_notification_id == d.user_notification_id)
                                      .values(delivery_status=DELIVERY_SENT if ok else DELIVERY_FAILED))
            await session.commit()
    except Exception:  # noqa: BLE001 - notifications must never break the request that triggered them
        logger.exception("Notification delivery batch failed")


class NotificationService:
    def __init__(self, session: AsyncSession, background: BackgroundTasks | None = None):
        self.session = session
        self.repo = NotificationRepository(session)
        self.bg = background

    # ------------------------------------------------------------ create
    async def create(self, user: User, ntype: str, title: str, message: str, *, reference_type: str | None = None,
                     reference_id: str | int | None = None, email_template: str | None = None,
                     email_context: dict[str, Any] | None = None, sms_text: str | None = None) -> list[Delivery]:
        profile = (await self.session.execute(select(UserProfile).where(UserProfile.user_id == user.user_id))).scalar_one_or_none()
        marketing = ntype in MARKETING_NOTIFICATION_TYPES
        email_ok = bool(user.email) and (not marketing or profile is None or profile.email_opt_in)
        sms_ok = bool(sms_text) and bool(user.phone) and (not marketing or profile is None or profile.sms_opt_in)

        notification = await self.repo.add_notification(
            title=title[:150], message=message, notification_type=ntype, reference_type=reference_type,
            reference_id=str(reference_id) if reference_id is not None else None)
        await self.repo.add_delivery_row(notification_id=notification.notification_id, user_id=user.user_id,
                                         channel=CHANNEL_IN_APP, status=DELIVERY_SENT)
        deliveries: list[Delivery] = []
        context = {"first_name": user.first_name, "title": title, "message": message, **(email_context or {})}
        if email_ok:
            row = await self.repo.add_delivery_row(notification_id=notification.notification_id, user_id=user.user_id,
                                                   channel=CHANNEL_EMAIL, status=DELIVERY_QUEUED)
            deliveries.append(Delivery(row.user_notification_id, CHANNEL_EMAIL, email=user.email,
                                       template=email_template or "GENERIC", context=context))
        if sms_ok:
            row = await self.repo.add_delivery_row(notification_id=notification.notification_id, user_id=user.user_id,
                                                   channel=CHANNEL_SMS, status=DELIVERY_QUEUED)
            deliveries.append(Delivery(row.user_notification_id, CHANNEL_SMS, phone=user.phone, sms_text=sms_text))
        return deliveries

    def schedule(self, deliveries: list[Delivery]) -> None:
        if deliveries and self.bg is not None:
            self.bg.add_task(deliver, deliveries)

    # ------------------------------------------------------------- reads
    @staticmethod
    def _out(un: UserNotification, n) -> NotificationOut:
        return NotificationOut(id=un.user_notification_id, title=n.title, message=n.message, type=n.notification_type,
                               type_label=NOTIFICATION_TYPE_LABELS.get(n.notification_type, "system"), reference_type=n.reference_type,
                               reference_id=n.reference_id, is_read=un.is_read, read_at=un.read_at, created_at=un.created_at)

    async def list(self, user: User, page: PageParams, unread_only: bool, ntype: str | None) -> Page[NotificationOut]:
        rows, total = await self.repo.page(user.user_id, page, unread_only=unread_only, ntype=ntype)
        return paginate([self._out(un, n) for un, n in rows], total, page)

    async def unread(self, user: User) -> UnreadCount:
        return UnreadCount(unread=await self.repo.unread_count(user.user_id))

    async def mark_read(self, user: User, notification_id: int) -> UnreadCount:
        row = await self.repo.get_owned(notification_id, user.user_id)
        if row is None:
            raise NotFoundError("Notification not found", code="notification_not_found")
        await self.repo.mark_read(row)
        await self.session.commit()
        return await self.unread(user)

    async def mark_all_read(self, user: User) -> UnreadCount:
        await self.repo.mark_all_read(user.user_id)
        await self.session.commit()
        return UnreadCount(unread=0)

    async def delete(self, user: User, notification_id: int) -> None:
        row = await self.repo.get_owned(notification_id, user.user_id)
        if row is None:
            raise NotFoundError("Notification not found", code="notification_not_found")
        await self.repo.delete(row)
        await self.session.commit()

    async def delete_all(self, user: User) -> None:
        await self.repo.delete_all(user.user_id)
        await self.session.commit()


def get_notification_service(background: BackgroundTasks, session: AsyncSession = Depends(get_db)) -> NotificationService:
    return NotificationService(session, background)
