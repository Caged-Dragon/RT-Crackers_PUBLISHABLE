from __future__ import annotations
from typing import Any, Generic, TypeVar
from sqlalchemy import select,func,delete
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException
from core.exceptions import NotFoundError,ConflictError
T=TypeVar('T')
class GenericRepository(Generic[T]):
    model:T
    def __init__(self,session:AsyncSession): self.session=session
    async def get(self,pk):
        obj=await self.session.get(self.model,pk)
        if obj is None: raise NotFoundError(f'{self.model.__tablename__} record not found')
        return obj
    async def list(self,offset=0,limit=50,order_by=None):
        stmt=select(self.model)
        if order_by is not None: stmt=stmt.order_by(order_by)
        stmt=stmt.offset(offset).limit(limit)
        return list((await self.session.execute(stmt)).scalars())
    async def count(self):return (await self.session.execute(select(func.count()).select_from(self.model))).scalar_one()
    async def create(self,values:dict[str,Any]):
        obj=self.model(**values); self.session.add(obj); await self.session.flush(); return obj
    async def update(self,pk,values):
        obj=await self.get(pk)
        for k,v in values.items():
            if v is not None and hasattr(obj,k):setattr(obj,k,v)
        await self.session.flush(); return obj
    async def delete(self,pk):
        obj=await self.get(pk); await self.session.delete(obj); await self.session.flush()
        return obj
async def commit(session):
    try: await session.commit()
    except Exception: await session.rollback(); raise
