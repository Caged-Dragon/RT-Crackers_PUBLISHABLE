from fastapi import APIRouter,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission,CurrentAdmin
from ADMINS.coupons.schemas import Create,Update
from ADMINS.coupons.service import Service
router=APIRouter(prefix='/coupons',tags=['Admin Coupons'])
@router.get('')
async def list_items(page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('coupons.read')),db:AsyncSession=Depends(get_db)):
    items,total=await Service(db,admin.admin_id).list(page,page_size); return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.get('/{id}')
async def get_item(id:int,admin=Depends(require_permission('coupons.read')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).get(id)
@router.post('',status_code=201)
async def create(payload:Create,admin=Depends(require_permission('coupons.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).create(payload.data)
@router.patch('/{id}')
async def update(id:int,payload:Update,admin=Depends(require_permission('coupons.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).update(id,payload.data)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('coupons.delete')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).delete(id)

@router.post('/{id}/activate')
async def activate(id:int,admin=Depends(require_permission('coupons.write')),db:AsyncSession=Depends(get_db)):
 from ADMINS.coupons.models import Coupon
 o=await db.get(Coupon,id)
 if not o: from core.exceptions import NotFoundError; raise NotFoundError('Coupon not found')
 o.is_active=True;await db.commit();return o
@router.post('/{id}/deactivate')
async def deactivate(id:int,admin=Depends(require_permission('coupons.write')),db:AsyncSession=Depends(get_db)):
 from ADMINS.coupons.models import Coupon
 o=await db.get(Coupon,id)
 if not o: from core.exceptions import NotFoundError; raise NotFoundError('Coupon not found')
 o.is_active=False;await db.commit();return o
