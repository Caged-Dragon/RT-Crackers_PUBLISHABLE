from __future__ import annotations

from datetime import datetime

from core.schemas import BaseSchema


class NotificationOut(BaseSchema):
    id: int
    title: str
    message: str
    type: str
    type_label: str
    reference_type: str | None = None
    reference_id: str | None = None
    is_read: bool
    read_at: datetime | None = None
    created_at: datetime


class UnreadCount(BaseSchema):
    unread: int
