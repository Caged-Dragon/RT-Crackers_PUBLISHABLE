from fastapi import APIRouter,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission,CurrentAdmin
from ADMINS.inventory.schemas import Create,Update
from ADMINS.inventory.service import Service
router=APIRouter(prefix='/inventory',tags=['Admin Inventory'])
@router.get('')
async def list_items(page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('inventory.read')),db:AsyncSession=Depends(get_db)):
    items,total=await Service(db,admin.admin_id).list(page,page_size); return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.get('/{id}')
async def get_item(id:int,admin=Depends(require_permission('inventory.read')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).get(id)
@router.post('',status_code=201)
async def create(payload:Create,admin=Depends(require_permission('inventory.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).create(payload.data)
@router.patch('/{id}')
async def update(id:int,payload:Update,admin=Depends(require_permission('inventory.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).update(id,payload.data)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('inventory.delete')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).delete(id)

@router.post('/{id}/stock-in')
async def stock_in(id:int,quantity:int,admin=Depends(require_permission('inventory.write')),db:AsyncSession=Depends(get_db)):
    from datetime import datetime
    from ADMINS.inventory.models import Inventory,InventoryMovement
    inv=await db.get(Inventory,id)
    if not inv: from core.exceptions import NotFoundError; raise NotFoundError('Inventory record not found')
    if quantity<=0: from core.exceptions import ConflictError; raise ConflictError('Quantity must be positive')
    inv.quantity_on_hand+=quantity;inv.last_restocked_at=datetime.utcnow();db.add(InventoryMovement(inventory_id=id,movement_type='P',quantity_change=quantity,performed_by=admin.admin_id,created_at=datetime.utcnow()));await db.commit();return inv
@router.post('/{id}/stock-out')
async def stock_out(id:int,quantity:int,admin=Depends(require_permission('inventory.write')),db:AsyncSession=Depends(get_db)):
    from datetime import datetime
    from ADMINS.inventory.models import Inventory,InventoryMovement
    inv=await db.get(Inventory,id)
    if not inv: from core.exceptions import NotFoundError; raise NotFoundError('Inventory record not found')
    if quantity<=0 or inv.quantity_on_hand-inv.reserved_quantity<quantity: from core.exceptions import ConflictError; raise ConflictError('Insufficient available stock')
    inv.quantity_on_hand-=quantity;db.add(InventoryMovement(inventory_id=id,movement_type='D',quantity_change=-quantity,performed_by=admin.admin_id,created_at=datetime.utcnow()));await db.commit();return inv
