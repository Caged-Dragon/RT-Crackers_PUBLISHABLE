"""Async SQLAlchemy engine/session wired for Supabase (SSL + PgBouncer aware)."""
from __future__ import annotations

import importlib
import logging
from collections.abc import AsyncIterator
from datetime import datetime

from sqlalchemy import DateTime, func, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.pool import NullPool

from core.config import settings

logger = logging.getLogger("rtcrackers.db")

try:
    import asyncpg  # noqa: F401
    ASYNCPG_AVAILABLE = True
except ImportError:
    ASYNCPG_AVAILABLE = False


class Base(DeclarativeBase):
    # Re-read server-generated values (generated columns, defaults, triggers) in the same round-trip.
    __mapper_args__ = {"eager_defaults": True}


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)


def _build_engine():
    kwargs: dict = {"echo": settings.DB_ECHO, "connect_args": settings.asyncpg_connect_args(), "pool_pre_ping": True}
    if settings.DB_NULL_POOL:
        kwargs["poolclass"] = NullPool
    else:
        kwargs.update(
            pool_size=settings.DB_POOL_SIZE,
            max_overflow=settings.DB_MAX_OVERFLOW,
            pool_timeout=settings.DB_POOL_TIMEOUT,
            pool_recycle=settings.DB_POOL_RECYCLE,
        )
    return create_async_engine(settings.async_database_url, **kwargs)


engine = _build_engine() if ASYNCPG_AVAILABLE else None
async_session_factory = (
    async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False, autoflush=False)
    if engine is not None else None
)


async def get_db() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency: one session per request. Services own commit/rollback."""
    if async_session_factory is None:
        raise RuntimeError("asyncpg is not installed. Run: pip install -r requirements.txt")
    async with async_session_factory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise


async def set_audit_user(session: AsyncSession, user_id: int | None) -> None:
    """Expose the acting user to the schema's audit triggers (transaction-local, PgBouncer safe)."""
    await session.execute(text("SELECT set_config('app.current_user_id', :uid, true)"), {"uid": str(user_id or "")})


def soft_delete(entity, user_id: int | None = None) -> None:
    """Apply the database-standard soft-delete columns to a mapped entity."""
    if hasattr(entity, "is_deleted"):
        entity.is_deleted = True
    if hasattr(entity, "deleted_at"):
        entity.deleted_at = datetime.utcnow()
    if hasattr(entity, "deleted_by"):
        entity.deleted_by = user_id


async def check_database() -> None:
    if engine is None:
        raise RuntimeError("asyncpg is not installed. Run: pip install -r requirements.txt")
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))


def import_all_models() -> None:
    """Import every model module so SQLAlchemy can resolve the full mapper registry."""
    for mod in (
        "core.system_models", "customers.auth.models", "customers.profiles.models", "customers.addresses.models",
        "customers.categories.models", "customers.products.models", "customers.cart.models",
        "customers.wishlist.models", "customers.orders.models", "customers.reviews.models",
        "customers.coupons.models", "customers.referrals.models", "customers.notifications.models",
        "customers.recently_viewed.models", "customers.platform.models",
    ):
        importlib.import_module(mod)
