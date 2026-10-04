from __future__ import annotations
import logging
from collections.abc import AsyncIterator
from datetime import datetime
from sqlalchemy import DateTime, func, text
from sqlalchemy.ext.asyncio import AsyncSession,async_sessionmaker,create_async_engine
from sqlalchemy.orm import DeclarativeBase,Mapped,mapped_column
from sqlalchemy.pool import NullPool
from core.config import settings
logger=logging.getLogger('rtcrackers.admin.db')
try:
 import asyncpg  # noqa: F401
 ASYNCPG_AVAILABLE=True
except ImportError:
 ASYNCPG_AVAILABLE=False
class Base(DeclarativeBase): __mapper_args__={'eager_defaults':True}
class TimestampMixin:
    created_at:Mapped[datetime]=mapped_column(DateTime,server_default=func.now(),nullable=False)
    updated_at:Mapped[datetime]=mapped_column(DateTime,server_default=func.now(),onupdate=func.now(),nullable=False)
kwargs={'echo':settings.DB_ECHO,'connect_args':settings.asyncpg_connect_args(),'pool_pre_ping':True}
if settings.DB_NULL_POOL: kwargs['poolclass']=NullPool
else: kwargs.update(pool_size=settings.DB_POOL_SIZE,max_overflow=settings.DB_MAX_OVERFLOW,pool_timeout=settings.DB_POOL_TIMEOUT,pool_recycle=settings.DB_POOL_RECYCLE)
engine=create_async_engine(settings.async_database_url,**kwargs) if ASYNCPG_AVAILABLE else None
async_session_factory=async_sessionmaker(engine,class_=AsyncSession,expire_on_commit=False,autoflush=False) if engine is not None else None
async def get_db()->AsyncIterator[AsyncSession]:
    if async_session_factory is None: raise RuntimeError('asyncpg is not installed. Run: pip install -r requirements.txt')
    async with async_session_factory() as s:
        try: yield s
        except Exception: await s.rollback(); raise
async def set_audit_user(session:AsyncSession,admin_id:int|None): await session.execute(text("SELECT set_config('app.current_admin_id', :uid, true)"),{'uid':str(admin_id or '')})
async def check_database():
    if engine is None: raise RuntimeError('asyncpg is not installed. Run: pip install -r requirements.txt')
    async with engine.connect() as c: await c.execute(text('SELECT 1'))
