from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import delete, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import CHANNEL_IN_APP
from customers.notifications.models import Notification, UserNotification
from utils.helpers import utcnow
from utils.pagination import PageParams


def _visible(user_id: int, now: datetime):
    return (UserNotification.user_id == user_id, UserNotification.channel == CHANNEL_IN_APP,
            or_(Notification.expires_at.is_(None), Notification.expires_at > now))


class NotificationRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def add_notification(self, **fields: Any) -> Notification:
        notification = Notification(**fields)
        self.session.add(notification)
        await self.session.flush()
        return notification

    async def add_delivery_row(self, *, notification_id: int, user_id: int, channel: str, status: str) -> UserNotification:
        row = UserNotification(notification_id=notification_id, user_id=user_id, channel=channel, delivery_status=status)
        self.session.add(row)
        await self.session.flush()
        return row

    async def page(self, user_id: int, page: PageParams, *, unread_only: bool, ntype: str | None) -> tuple[list[Any], int]:
        conds = list(_visible(user_id, utcnow()))
        if unread_only:
            conds.append(UserNotification.is_read.is_(False))
        if ntype:
            conds.append(Notification.notification_type == ntype)
        base = (select(UserNotification, Notification).join(Notification, Notification.notification_id == UserNotification.notification_id)
                .where(*conds))
        total = int((await self.session.execute(select(func.count()).select_from(base.subquery()))).scalar_one())
        rows = (await self.session.execute(base.order_by(UserNotification.created_at.desc(), UserNotification.user_notification_id.desc())
                                           .limit(page.limit).offset(page.offset))).all()
        return list(rows), total

    async def unread_count(self, user_id: int) -> int:
        stmt = (select(func.count()).select_from(UserNotification)
                .join(Notification, Notification.notification_id == UserNotification.notification_id)
                .where(*_visible(user_id, utcnow()), UserNotification.is_read.is_(False)))
        return int((await self.session.execute(stmt)).scalar_one())

    async def get_owned(self, user_notification_id: int, user_id: int) -> UserNotification | None:
        stmt = select(UserNotification).where(UserNotification.user_notification_id == user_notification_id,
                                              UserNotification.user_id == user_id, UserNotification.channel == CHANNEL_IN_APP)
        return (await self.session.execute(stmt)).scalar_one_or_none()

    async def mark_read(self, row: UserNotification) -> None:
        if not row.is_read:
            row.is_read = True
            row.read_at = utcnow()
            await self.session.flush()

    async def mark_all_read(self, user_id: int) -> int:
        result = await self.session.execute(
            update(UserNotification).where(UserNotification.user_id == user_id, UserNotification.channel == CHANNEL_IN_APP,
                                           UserNotification.is_read.is_(False)).values(is_read=True, read_at=utcnow()))
        return int(result.rowcount or 0)

    async def delete(self, row: UserNotification) -> None:
        await self.session.delete(row)
        await self.session.flush()

    async def delete_all(self, user_id: int) -> None:
        await self.session.execute(delete(UserNotification).where(UserNotification.user_id == user_id, UserNotification.channel == CHANNEL_IN_APP))
