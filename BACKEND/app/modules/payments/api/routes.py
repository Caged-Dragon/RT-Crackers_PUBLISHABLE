from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from ....core.database import get_db
from ....core.security import current_user
from ....utils.orm import to_dict
from ....database.models import PaymentTransaction
from ..schemas import CreatePayment

router = APIRouter(prefix="/payments", tags=["Payments"])

@router.post("/create")
async def create_online_payment_disabled(user=Depends(current_user), db=Depends(get_db)):
    raise HTTPException(status_code=410, detail="Online payments are disabled. Cash on Delivery is the only supported payment method.")

@router.post("/verify")
async def verify_online_payment_disabled(user=Depends(current_user)):
    raise HTTPException(status_code=410, detail="Online payment verification is disabled. Cash on Delivery is the only supported payment method.")

@router.get("/transactions")
async def transactions(user=Depends(current_user), db=Depends(get_db)):
    rows=(await db.execute(select(PaymentTransaction).where(PaymentTransaction.user_id==user["user_id"]).order_by(PaymentTransaction.created_at.desc()))).scalars().all()
    return {"success":True,"data":[to_dict(x) for x in rows]}

@router.post("/webhooks/razorpay")
async def disabled_webhook():
    raise HTTPException(status_code=410, detail="Razorpay webhooks are disabled. Cash on Delivery is the only supported payment method.")

@router.post("/cod")
async def cod(body:CreatePayment,user=Depends(current_user),db=Depends(get_db)):
    if body.currency.upper() != "INR":
        raise HTTPException(422, "COD currency must be INR")
    if body.method.upper() not in {"COD", "CASH_ON_DELIVERY"}:
        raise HTTPException(422, "Only Cash on Delivery is supported")
    from sqlalchemy import text
    order = (await db.execute(text("select order_id,total_amount,user_id from orders where order_id=:o and user_id=:u"), {"o":body.order_id,"u":user["user_id"]})).mappings().first()
    if not order:
        raise HTTPException(404, "Order not found")
    if round(float(order["total_amount"]),2) != round(float(body.amount),2):
        raise HTTPException(409, "COD amount does not match the order total")
    await db.execute(text("insert into cod_transactions(order_id,amount_collected,status) values(:o,0,'P') on conflict(order_id) do nothing"), {"o":body.order_id})
    await db.commit()
    return {"success":True,"data":{"order_id":body.order_id,"status":"pending","payment_method":"COD"}}

@router.post("/{transaction_id}/retry")
async def retry_disabled(transaction_id:int,user=Depends(current_user)):
    raise HTTPException(status_code=410, detail="Online payment retries are disabled. Cash on Delivery is the only supported payment method.")
