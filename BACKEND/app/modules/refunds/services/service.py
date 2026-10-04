from datetime import datetime
from sqlalchemy import select
from ....database.models import RefundRequest,PaymentTransaction
async def request_refund(db,user,b):
 tx=(await db.execute(select(PaymentTransaction).where(PaymentTransaction.order_id==b.order_id,PaymentTransaction.user_id==user['user_id'],PaymentTransaction.status=='captured').order_by(PaymentTransaction.created_at.desc()))).scalars().first()
 if not tx: raise ValueError('No captured payment found')
 if b.amount>tx.amount: raise ValueError('Refund exceeds captured amount')
 r=RefundRequest(order_id=b.order_id,payment_transaction_id=tx.id,user_id=user['user_id'],amount=b.amount,reason=b.reason); db.add(r); await db.commit(); await db.refresh(r); return r
