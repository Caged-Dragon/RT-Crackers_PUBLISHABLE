from fastapi import APIRouter,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission,CurrentAdmin
from ADMINS.delivery.schemas import Create,Update
from ADMINS.delivery.service import Service
router=APIRouter(prefix='/delivery',tags=['Admin Delivery'])
@router.get('')
async def list_items(page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('delivery.read')),db:AsyncSession=Depends(get_db)):
    items,total=await Service(db,admin.admin_id).list(page,page_size); return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.get('/{id}')
async def get_item(id:int,admin=Depends(require_permission('delivery.read')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).get(id)
@router.post('',status_code=201)
async def create(payload:Create,admin=Depends(require_permission('delivery.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).create(payload.data)
@router.patch('/{id}')
async def update(id:int,payload:Update,admin=Depends(require_permission('delivery.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).update(id,payload.data)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('delivery.delete')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).delete(id)

@router.get('/pincodes')
async def pincodes(admin=Depends(require_permission('delivery.read')),db:AsyncSession=Depends(get_db)):
    from sqlalchemy import select
    from ADMINS.shipping.models import Pincode
    return list((await db.execute(select(Pincode).order_by(Pincode.pincode))).scalars())
@router.patch('/pincodes/{pincode}')
async def update_pincode(pincode:str,is_serviceable:bool|None=None,cod_available:bool|None=None,admin=Depends(require_permission('delivery.write')),db:AsyncSession=Depends(get_db)):
    from core.exceptions import NotFoundError
    from ADMINS.shipping.models import Pincode
    o=await db.get(Pincode,pincode)
    if not o: raise NotFoundError('Pincode not found')
    if is_serviceable is not None:o.is_serviceable=is_serviceable
    if cod_available is not None:o.cod_available=cod_available
    await db.commit(); return o
