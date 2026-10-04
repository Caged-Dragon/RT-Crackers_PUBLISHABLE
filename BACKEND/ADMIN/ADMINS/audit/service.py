from __future__ import annotations

from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from ADMINS.audit.models import AdminActivityLog
from ADMINS.audit.repository import Repository


async def audit(
    session: AsyncSession,
    admin_id: int,
    action: str,
    module: str,
    entity_type: str,
    entity_id: str,
    details: dict[str, Any] | None,
) -> None:
    session.add(
        AdminActivityLog(
            admin_id=admin_id,
            action=action,
            module_name=module,
            entity_type=entity_type,
            entity_id=entity_id,
            details=details,
        )
    )
    await session.flush()


class Service:
    """CRUD facade used by the audit router; detailed audit streams remain read-mostly."""

    def __init__(self, session: AsyncSession, admin_id: int):
        self.session = session
        self.admin_id = admin_id
        self.repo = Repository(session)

    async def list(self, page: int, page_size: int):
        offset = (page - 1) * page_size
        items = await self.repo.list(offset, page_size, AdminActivityLog.created_at.desc())
        total = await self.repo.count()
        return items, total

    async def get(self, record_id: int):
        return await self.repo.get(record_id)

    async def create(self, values: dict[str, Any]):
        values = dict(values)
        values["admin_id"] = self.admin_id
        return await self.repo.create(values)

    async def update(self, record_id: int, values: dict[str, Any]):
        return await self.repo.update(record_id, values)

    async def delete(self, record_id: int):
        return await self.repo.delete(record_id)
