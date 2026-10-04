from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import select
from ....core.database import get_db
from ....utils.orm import to_dict
from ....core.security import current_user,require_roles
from ....database.models import RefundRequest,PaymentTransaction
from ..schemas import RefundRequestIn,RefundStatusIn
from ..services.service import request_refund
router=APIRouter(prefix='/refunds',tags=['Refunds'])
@router.post('')
async def create(b:RefundRequestIn,user=Depends(current_user),db=Depends(get_db)):
 try:return {'success':True,'data':to_dict(await request_refund(db,user,b))}
 except Exception as e: raise HTTPException(400,str(e))
@router.get('')
async def list_refunds(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(select(RefundRequest).where(RefundRequest.user_id==user['user_id']).order_by(RefundRequest.created_at.desc()))).scalars().all(); return {'success':True,'data':[to_dict(x) for x in r]}
@router.patch('/{refund_id}')
async def update(refund_id:int,b:RefundStatusIn,user=Depends(require_roles('A','ADMIN')),db=Depends(get_db)):
 r=await db.get(RefundRequest,refund_id)
 if not r: raise HTTPException(404,'Refund not found')
 r.status=b.status; r.provider_refund_id=b.provider_refund_id or r.provider_refund_id; r.notes=b.notes or r.notes
 if b.status == 'processing':
  r.status = 'processing'
 r.updated_at=__import__('datetime').datetime.utcnow(); await db.commit(); return {'success':True,'data':to_dict(r)}
