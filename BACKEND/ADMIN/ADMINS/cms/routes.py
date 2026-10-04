from fastapi import APIRouter,Depends,Path
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission
from ADMINS.cms.schemas import Create,Update
from ADMINS.cms.service import Service
router=APIRouter(prefix='/cms',tags=['Admin CMS'])
@router.get('/{kind}')
async def list_kind(kind:str,admin=Depends(require_permission('CMS.READ')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).list(kind)
@router.post('/{kind}',status_code=201)
async def create_kind(kind:str,p:Create,admin=Depends(require_permission('CMS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).create(kind,p.data)
@router.patch('/{kind}/{id}')
async def update_kind(kind:str,id:int,p:Update,admin=Depends(require_permission('CMS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).update(kind,id,p.data)
@router.delete('/{kind}/{id}')
async def delete_kind(kind:str,id:int,admin=Depends(require_permission('CMS.DELETE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).delete(kind,id)
