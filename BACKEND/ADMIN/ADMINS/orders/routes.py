from fastapi import APIRouter,BackgroundTasks,Depends,Query
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db
from ADMINS.auth.dependencies import require_permission,CurrentAdmin
from ADMINS.orders.schemas import Create,Update
from ADMINS.orders.service import Service
router=APIRouter(prefix='/orders',tags=['Admin Orders'])
@router.get('')
async def list_items(background:BackgroundTasks, page:int=Query(1,ge=1),page_size:int=Query(50,ge=1,le=200),admin=Depends(require_permission('orders.read')),db:AsyncSession=Depends(get_db)):
    items,total=await Service(db,admin.admin_id,background).list(page,page_size); return {'items':items,'total':total,'page':page,'page_size':page_size,'pages':(total+page_size-1)//page_size}
@router.get('/{id}')
async def get_item(id:int,background:BackgroundTasks,admin=Depends(require_permission('orders.read')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id,background).get(id)
@router.post('',status_code=201)
async def create(payload:Create,background:BackgroundTasks,admin=Depends(require_permission('orders.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id,background).create(payload.data)
@router.patch('/{id}')
async def update(id:int,payload:Update,background:BackgroundTasks,admin=Depends(require_permission('orders.write')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id,background).update(id,payload.data)
@router.delete('/{id}')
async def delete(id:int,background:BackgroundTasks,admin=Depends(require_permission('orders.delete')),db:AsyncSession=Depends(get_db)): return await Service(db,admin.admin_id,background).delete(id)

@router.post('/{id}/confirm')
async def confirm(id:int,background:BackgroundTasks,admin=Depends(require_permission('orders.write')),db:AsyncSession=Depends(get_db)):
    return await Service(db,admin.admin_id,background).confirm(id)

@router.post('/{id}/status')
async def status(id:int,status:str,background:BackgroundTasks,remarks:str|None=None,admin=Depends(require_permission('orders.write')),db:AsyncSession=Depends(get_db)):
    return await Service(db, admin.admin_id, background).set_status(id, status, remarks)

@router.post('/{id}/cancel')
async def cancel(id:int,reason:str,admin=Depends(require_permission('orders.write')),db:AsyncSession=Depends(get_db)):
    return await Service(db, admin.admin_id, None).set_status(id, 'X', reason)

@router.get('/{id}/timeline')
async def timeline(id:int,admin=Depends(require_permission('orders.read')),db:AsyncSession=Depends(get_db)):
    from sqlalchemy import select
    from ADMINS.orders.models import OrderStatusHistory
    return list((await db.execute(select(OrderStatusHistory).where(OrderStatusHistory.order_id==id).order_by(OrderStatusHistory.created_at))).scalars())
@router.post('/{id}/refund')
async def refund(id:int,refund_amount:float,refund_method:str='C',reason:str|None=None,admin=Depends(require_permission('orders.write')),db:AsyncSession=Depends(get_db)):
    from datetime import datetime
    from ADMINS.orders.models import Order,Refund
    from core.exceptions import NotFoundError,ConflictError
    o=await db.get(Order,id)
    if not o: raise NotFoundError('Order not found')
    if refund_amount<=0 or refund_amount>float(o.total_amount): raise ConflictError('Invalid refund amount')
    r=Refund(order_id=id,refund_amount=refund_amount,refund_method=refund_method,reason=reason,status='A',processed_by=admin.admin_id,processed_at=datetime.utcnow());db.add(r);o.payment_status='R' if refund_amount==float(o.total_amount) else 'Q';await db.commit();return r
@router.get('/{id}/invoice')
async def invoice(id:int,admin=Depends(require_permission('orders.read')),db:AsyncSession=Depends(get_db)):
    from fastapi.responses import StreamingResponse
    from io import BytesIO
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas
    from ADMINS.orders.models import Order
    from core.exceptions import NotFoundError
    o=await db.get(Order,id)
    if not o: raise NotFoundError('Order not found')
    buf=BytesIO(); c=canvas.Canvas(buf,pagesize=A4); c.setFont('Helvetica-Bold',16);c.drawString(50,800,'RT Crackers Invoice');c.setFont('Helvetica',10);c.drawString(50,780,f'Order: {o.order_number}');c.drawString(50,765,f'Total: INR {o.total_amount}');c.drawString(50,750,f'Status: {o.order_status}');c.showPage();c.save();buf.seek(0);return StreamingResponse(buf,media_type='application/pdf',headers={'Content-Disposition':f'inline; filename="{o.order_number}.pdf"'})
