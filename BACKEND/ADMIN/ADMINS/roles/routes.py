from fastapi import APIRouter,Depends
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission
from ADMINS.roles.schemas import *
from ADMINS.roles.service import Service
router=APIRouter(prefix='/roles',tags=['Admin Roles'])
@router.get('')
async def list_roles(admin=Depends(require_permission('ROLES.READ')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).list()
@router.post('',status_code=201)
async def create(p:RoleCreate,admin=Depends(require_permission('ROLES.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).create(p)
@router.patch('/{id}')
async def update(id:int,p:RoleUpdate,admin=Depends(require_permission('ROLES.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).update(id,p)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('ROLES.DELETE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).delete(id)
@router.put('/{id}/permissions')
async def perms(id:int,p:PermissionAssignment,admin=Depends(require_permission('ROLES.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).permissions(id,p.permission_ids)
