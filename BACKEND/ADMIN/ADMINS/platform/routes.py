from __future__ import annotations
import json, re
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission, get_current_admin
from ADMINS.platform.models import SiteRelease, SiteContentRevision
from ADMINS.auth.models import User, Admin
from utils.email import safe_send_template_email
from core.config import settings

router=APIRouter(prefix="/platform",tags=["Admin Platform"])

class ReleaseDraft(BaseModel):
    version: str = Field(min_length=1,max_length=40,pattern=r"^[A-Za-z0-9._-]+$")
    name: str = Field(default="RTCrackers update",max_length=160)
    message: str = Field(default="",max_length=1000)
    snapshot: dict = Field(default_factory=dict)

class ContentDraft(BaseModel):
    content_key: str = Field(min_length=1,max_length=180)
    page_path: str = Field(default="/",max_length=240)
    payload: dict = Field(default_factory=dict)
    release_version: str = Field(min_length=1,max_length=40)

def _verify_snapshot(snapshot:dict)->None:
    raw=json.dumps(snapshot,ensure_ascii=False)
    if len(raw)>2_000_000: raise ValueError("Published content snapshot exceeds 2 MB")
    def walk(v):
        if isinstance(v,dict):
            for k,x in v.items():
                if not isinstance(k,str) or len(k)>180: raise ValueError("Invalid content key")
                walk(x)
        elif isinstance(v,list):
            if len(v)>5000: raise ValueError("Content list is too large")
            for x in v: walk(x)
        elif isinstance(v,str) and len(v)>500_000: raise ValueError("Content field is too large")
    walk(snapshot)

@router.get("/releases")
async def releases(admin=Depends(require_permission("CMS.READ")),db:AsyncSession=Depends(get_db)):
    return list((await db.execute(select(SiteRelease).order_by(SiteRelease.release_id.desc()).limit(100))).scalars())

@router.post("/releases",status_code=201)
async def create_release(body:ReleaseDraft,admin=Depends(require_permission("CMS.WRITE")),db:AsyncSession=Depends(get_db)):
    try: _verify_snapshot(body.snapshot)
    except ValueError as e: raise HTTPException(422,str(e))
    existing=(await db.execute(select(SiteRelease).where(SiteRelease.version==body.version))).scalar_one_or_none()
    if existing: raise HTTPException(409,"Release version already exists")
    row=SiteRelease(version=body.version,name=body.name,message=body.message,snapshot=body.snapshot,status="DRAFT",created_by=admin.admin_id)
    db.add(row); await db.commit(); await db.refresh(row); return row

@router.post("/releases/{release_id}/verify")
async def verify_release(release_id:int,admin=Depends(require_permission("CMS.WRITE")),db:AsyncSession=Depends(get_db)):
    row=await db.get(SiteRelease,release_id)
    if not row: raise HTTPException(404,"Release not found")
    try:
        _verify_snapshot(row.snapshot)
        if not row.version: raise ValueError("Missing version")
        row.status="VERIFIED"; row.verified_at=datetime.utcnow(); row.verification_error=None
        await db.commit()
        ok=True; err=""
    except Exception as e:
        row.status="REJECTED"; row.verification_error=str(e); await db.commit(); ok=False; err=str(e)
    recipients=(await db.execute(select(User.email).join(Admin,Admin.user_id==User.user_id).where(Admin.admin_id==admin.admin_id))).scalar_one_or_none()
    recipients=recipients or settings.ORDER_ADMIN_EMAILS.split(",")[0].strip()
    await safe_send_template_email(recipients,"GENERIC",{
        "first_name":"Admin","title":f"RTCrackers release {row.version} {'verified' if ok else 'rejected'}",
        "message":f"Release {row.version} was {'verified successfully.' if ok else 'rejected: '+err} Edited by admin #{admin.admin_id}."
    })
    return {"status":row.status,"version":row.version,"error":err or None}

@router.post("/releases/{release_id}/publish")
async def publish_release(release_id:int,admin=Depends(require_permission("CMS.WRITE")),db:AsyncSession=Depends(get_db)):
    row=await db.get(SiteRelease,release_id)
    if not row: raise HTTPException(404,"Release not found")
    if row.status!="VERIFIED": raise HTTPException(409,"Release must pass verification before publishing")
    await db.execute(update(SiteRelease).where(SiteRelease.is_current.is_(True)).values(is_current=False,status="SUPERSEDED"))
    row.status="PUBLISHED"; row.is_current=True; row.published_at=datetime.utcnow()
    await db.commit()
    recipients=(await db.execute(select(User.email).join(Admin,Admin.user_id==User.user_id).where(Admin.admin_id==admin.admin_id))).scalar_one_or_none()
    recipients=recipients or settings.ORDER_ADMIN_EMAILS.split(",")[0].strip()
    await safe_send_template_email(recipients,"GENERIC",{
        "first_name":"Admin","title":f"RTCrackers release {row.version} published",
        "message":f"The verified release {row.version} was published by admin #{admin.admin_id}. Previous release was retained as SUPERSEDED."
    })
    return row

@router.post("/content")
async def save_content(body:ContentDraft,admin=Depends(require_permission("CMS.WRITE")),db:AsyncSession=Depends(get_db)):
    rel=(await db.execute(select(SiteRelease).where(SiteRelease.version==body.release_version))).scalar_one_or_none()
    if not rel: raise HTTPException(404,"Release not found")
    row=SiteContentRevision(content_key=body.content_key,page_path=body.page_path,payload=body.payload,status="DRAFT",release_id=rel.release_id,edited_by=admin.admin_id)
    snapshot=dict(rel.snapshot or {})
    snapshot.setdefault("content",{})[body.content_key]=body.payload
    rel.snapshot=snapshot
    db.add(row); await db.commit(); await db.refresh(row); return row

@router.get("/content/{content_key:path}")
async def content_history(content_key:str,admin=Depends(require_permission("CMS.READ")),db:AsyncSession=Depends(get_db)):
    return list((await db.execute(select(SiteContentRevision).where(SiteContentRevision.content_key==content_key).order_by(SiteContentRevision.revision_id.desc()).limit(50))).scalars())
