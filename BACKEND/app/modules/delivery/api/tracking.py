from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import text
from ....core.database import get_db
router=APIRouter(prefix='/delivery',tags=['Delivery Tracking'])
@router.get('/tracking/{tracking_number}')
async def tracking(tracking_number:str,db=Depends(get_db)):
 r=(await db.execute(text('select o.order_number,o.order_status,o.expected_delivery_date,s.carrier_awb_number,s.delivery_partner from orders o left join shipments s on s.order_id=o.order_id where o.tracking_number=:t or s.carrier_awb_number=:t'),{'t':tracking_number})).mappings().first()
 if not r: raise HTTPException(404,'Tracking number not found')
 e=(await db.execute(text('select status,description,location,event_time from order_tracking_events e join orders o on o.order_id=e.order_id where o.tracking_number=:t order by event_time'),{'t':tracking_number})).mappings().all(); return {'success':True,'data':{'shipment':dict(r),'events':[dict(x) for x in e]}}
