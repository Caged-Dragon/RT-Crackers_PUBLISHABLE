from sqlalchemy.ext.asyncio import create_async_engine,async_sessionmaker,AsyncSession
from sqlalchemy.orm import DeclarativeBase
from contextlib import asynccontextmanager
from .config import settings
from sqlalchemy import text
class Base(DeclarativeBase): pass
engine=create_async_engine(settings.DATABASE_URL.replace('postgresql://','postgresql+asyncpg://'),pool_pre_ping=True,pool_size=10,max_overflow=20,pool_recycle=1800)
SessionLocal=async_sessionmaker(engine,class_=AsyncSession,expire_on_commit=False,autoflush=False)
async def get_db():
    async with SessionLocal() as s:
        try: yield s
        except Exception: await s.rollback(); raise
async def check_db():
    async with engine.connect() as c: await c.execute(text('select 1'))
