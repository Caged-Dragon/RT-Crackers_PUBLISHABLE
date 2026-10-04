from ....database.models import ReturnRequest
async def create_return(db,user,b):
 r=ReturnRequest(order_id=b.order_id,order_item_id=b.order_item_id,user_id=user['user_id'],return_type=b.return_type,reason=b.reason,replacement_product_id=b.replacement_product_id); db.add(r); await db.commit(); await db.refresh(r); return r
