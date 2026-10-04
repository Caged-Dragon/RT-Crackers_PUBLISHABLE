from fastapi import APIRouter,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission,CurrentAdmin
from ADMINS.shipping.schemas import Create,Update
from ADMINS.shipping.service import Service
router=APIRouter(prefix='/shipping',tags=['Admin Shipping'])
@router.get('')
async def list_items(page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('shipping.read')),db:AsyncSession=Depends(get_db)):
    items,total=await Service(db,admin.admin_id).list(page,page_size); return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.get('/{id}')
async def get_item(id:int,admin=Depends(require_permission('shipping.read')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).get(id)
@router.post('',status_code=201)
async def create(payload:Create,admin=Depends(require_permission('shipping.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).create(payload.data)
@router.patch('/{id}')
async def update(id:int,payload:Update,admin=Depends(require_permission('shipping.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).update(id,payload.data)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('shipping.delete')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).delete(id)

@router.get('/rates')
async def rates(admin=Depends(require_permission('shipping.read')),db:AsyncSession=Depends(get_db)):
    from sqlalchemy import select
    from ADMINS.shipping.models import ZoneShippingRate
    return list((await db.execute(select(ZoneShippingRate))).scalars())
@router.put('/rates')
async def upsert_rate(zone_id:int,shipping_method_id:int,base_charge:float=0,per_kg_charge:float=0,free_shipping_threshold:float|None=None,is_active:bool=True,admin=Depends(require_permission('shipping.write')),db:AsyncSession=Depends(get_db)):
    from ADMINS.shipping.models import ZoneShippingRate
    o=await db.get(ZoneShippingRate,(zone_id,shipping_method_id))
    if o is None:o=ZoneShippingRate(zone_id=zone_id,shipping_method_id=shipping_method_id,base_charge=base_charge,per_kg_charge=per_kg_charge,free_shipping_threshold=free_shipping_threshold,is_active=is_active);db.add(o)
    else:o.base_charge=base_charge;o.per_kg_charge=per_kg_charge;o.free_shipping_threshold=free_shipping_threshold;o.is_active=is_active
    await db.commit();return o
