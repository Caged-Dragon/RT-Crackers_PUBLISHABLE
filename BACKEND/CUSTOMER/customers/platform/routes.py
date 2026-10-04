from __future__ import annotations
from fastapi import APIRouter, Query
from sqlalchemy import select
from core.database import get_db
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from customers.platform.models import SiteRelease, SiteContentRevision

router=APIRouter(prefix="/platform",tags=["Platform"])

@router.get("/release")
async def current_release(accepted: str|None=Query(default=None), db:AsyncSession=Depends(get_db)):
    current=(await db.execute(select(SiteRelease).where(SiteRelease.is_current.is_(True),SiteRelease.status=="PUBLISHED").order_by(SiteRelease.published_at.desc()))).scalars().first()
    if not current:
        return {"version":"1.0.0","name":"RTCrackers","message":"","snapshot":{},"update_available":False}
    return {"version":current.version,"name":current.name,"message":current.message,"snapshot":current.snapshot,
            "update_available": bool(accepted and accepted != current.version)}

@router.get("/content/{content_key:path}")
async def content(content_key:str, db:AsyncSession=Depends(get_db)):
    row=(await db.execute(select(SiteContentRevision).where(
        SiteContentRevision.content_key==content_key,
        SiteContentRevision.status=="PUBLISHED",
    ).order_by(SiteContentRevision.published_at.desc()))).scalars().first()
    return row.payload if row else {}
