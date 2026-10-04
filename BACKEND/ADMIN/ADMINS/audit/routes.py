from fastapi import APIRouter,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission,CurrentAdmin
from ADMINS.audit.schemas import Create,Update
from ADMINS.audit.service import Service
router=APIRouter(prefix='/audit',tags=['Admin Audit'])
@router.get('')
async def list_items(page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('audit.read')),db:AsyncSession=Depends(get_db)):
    items,total=await Service(db,admin.admin_id).list(page,page_size); return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.get('/{id}')
async def get_item(id:int,admin=Depends(require_permission('audit.read')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).get(id)
@router.post('',status_code=201)
async def create(payload:Create,admin=Depends(require_permission('audit.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).create(payload.data)
@router.patch('/{id}')
async def update(id:int,payload:Update,admin=Depends(require_permission('audit.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).update(id,payload.data)
@router.delete('/{id}')
async def delete(id:int,admin=Depends(require_permission('audit.delete')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id).delete(id)

@router.get('/login-history')
async def login_history(admin=Depends(require_permission('AUDIT.READ')),db:AsyncSession=Depends(get_db)):
    from sqlalchemy import select
    from ADMINS.audit.models import LoginHistory
    return list((await db.execute(select(LoginHistory).order_by(LoginHistory.created_at.desc()).limit(500))).scalars())
@router.get('/system-audit')
async def system_audit(admin=Depends(require_permission('AUDIT.READ')),db:AsyncSession=Depends(get_db)):
    from sqlalchemy import select
    from ADMINS.audit.models import AuditLog
    return list((await db.execute(select(AuditLog).order_by(AuditLog.created_at.desc()).limit(500))).scalars())

@router.get('/product-changes')
async def product_changes(admin=Depends(require_permission('AUDIT.READ')),db:AsyncSession=Depends(get_db)):
 from sqlalchemy import text
 return list((await db.execute(text('SELECT * FROM product_audit_logs ORDER BY changed_at DESC LIMIT 500'))).mappings())
@router.get('/inventory-changes')
async def inventory_changes(admin=Depends(require_permission('AUDIT.READ')),db:AsyncSession=Depends(get_db)):
 from sqlalchemy import select
 from ADMINS.inventory.models import InventoryMovement
 return list((await db.execute(select(InventoryMovement).order_by(InventoryMovement.created_at.desc()).limit(500))).scalars())
@router.get('/order-changes')
async def order_changes(admin=Depends(require_permission('AUDIT.READ')),db:AsyncSession=Depends(get_db)):
 from sqlalchemy import select
 from ADMINS.orders.models import OrderStatusHistory
 return list((await db.execute(select(OrderStatusHistory).order_by(OrderStatusHistory.created_at.desc()).limit(500))).scalars())
