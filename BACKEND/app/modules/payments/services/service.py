"""COD-only payment service.

Online gateways are intentionally not implemented. This module exists only to keep
legacy payment-module imports stable while enforcing Cash On Delivery.
"""
from decimal import Decimal
from sqlalchemy import text

async def create_payment(db, user, body):
    method = str(getattr(body, "method", "COD")).upper()
    if method not in {"COD","CASH_ON_DELIVERY"}:
        raise ValueError("Only Cash on Delivery is supported")
    row=(await db.execute(text("""
        SELECT order_id,total_amount,user_id FROM orders
        WHERE order_id=:order_id AND user_id=:user_id
    """),{"order_id":body.order_id,"user_id":user["user_id"]})).mappings().first()
    if not row:
        raise ValueError("Order not found")
    if Decimal(str(row["total_amount"])) != Decimal(str(body.amount)):
        raise ValueError("COD amount does not match the order total")
    await db.execute(text("""
        INSERT INTO cod_transactions(order_id,amount_collected,status)
        VALUES(:order_id,0,'P') ON CONFLICT(order_id) DO NOTHING
    """),{"order_id":body.order_id})
    await db.commit()
    return {"order_id":body.order_id,"status":"pending","payment_method":"COD"}

async def verify_payment(*args, **kwargs):
    raise ValueError("Online payment verification is disabled; use COD collection workflow.")

async def refund(*args, **kwargs):
    raise ValueError("Online payment refunds are disabled; COD refunds are handled by the order/refund workflow.")
