from fastapi import APIRouter,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission
from ADMINS.admin_users.schemas import *
from ADMINS.admin_users.service import Service
router=APIRouter(prefix='/admin-users',tags=['Admin Users'])
@router.get('')
async def list_admins(page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('ADMIN_USERS.READ')),db:AsyncSession=Depends(get_db)):
 items,total=await Service(db,admin.admin_id).list(page,page_size);return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.post('',status_code=201)
async def create(p:AdminCreate,admin=Depends(require_permission('ADMIN_USERS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).create(p)
@router.get('/{id}')
async def get(id:int,admin=Depends(require_permission('ADMIN_USERS.READ')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).get(id)
@router.patch('/{id}')
async def update(id:int,p:AdminUpdate,admin=Depends(require_permission('ADMIN_USERS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).update(id,p)
@router.post('/{id}/enable')
async def enable(id:int,admin=Depends(require_permission('ADMIN_USERS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).set_status(id,'A')
@router.post('/{id}/disable')
async def disable(id:int,admin=Depends(require_permission('ADMIN_USERS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).set_status(id,'I')
@router.put('/{id}/roles')
async def roles(id:int,p:RoleAssignment,admin=Depends(require_permission('ADMIN_USERS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).roles(id,p.role_ids)
@router.put('/{id}/permissions')
async def permissions(id:int,p:PermissionAssignment,admin=Depends(require_permission('ADMIN_USERS.WRITE')),db:AsyncSession=Depends(get_db)):return await Service(db,admin.admin_id).permissions(id,p.permission_ids)
