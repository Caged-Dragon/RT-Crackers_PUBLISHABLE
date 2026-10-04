from fastapi import APIRouter,Depends
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission
from ADMINS.permissions.schemas import *
from ADMINS.permissions.service import Service
router=APIRouter(prefix='/permissions',tags=['Admin Permissions'])
@router.get('')
async def list_permissions(admin=Depends(require_permission('PERMISSIONS.READ')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).list()
@router.post('',status_code=201)
async def create(p:PermissionCreate,admin=Depends(require_permission('PERMISSIONS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).create(p)
@router.patch('/{id}')
async def update(id:int,p:PermissionUpdate,admin=Depends(require_permission('PERMISSIONS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).update(id,p)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('PERMISSIONS.DELETE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).delete(id)
