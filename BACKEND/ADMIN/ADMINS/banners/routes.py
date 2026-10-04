from fastapi import APIRouter,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission,CurrentAdmin
from ADMINS.banners.schemas import Create,Update
from ADMINS.banners.service import Service
router=APIRouter(prefix='/banners',tags=['Admin Banners'])
@router.get('')
async def list_items(page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('banners.read')),db:AsyncSession=Depends(get_db)):
    items,total=await Service(db,admin.admin_id).list(page,page_size); return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.get('/{id}')
async def get_item(id:int,admin=Depends(require_permission('banners.read')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).get(id)
@router.post('',status_code=201)
async def create(payload:Create,admin=Depends(require_permission('banners.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).create(payload.data)
@router.patch('/{id}')
async def update(id:int,payload:Update,admin=Depends(require_permission('banners.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).update(id,payload.data)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('banners.delete')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).delete(id)
