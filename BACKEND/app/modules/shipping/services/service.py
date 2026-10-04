from sqlalchemy import text
from datetime import date,timedelta
async def quote(db,b):
 p=(await db.execute(text('select pincode,zone_id,is_serviceable,cod_available from postal_codes where postal_code=:p'),{'p':b.pincode})).mappings().first()
 if not p: p=(await db.execute(text('select pincode,zone_id,is_serviceable,cod_available from pincodes where pincode=:p'),{'p':b.pincode})).mappings().first()
 if not p or not p['is_serviceable']: raise ValueError('Pincode is not serviceable')
 q=(await db.execute(text('select zone_id,shipping_method_id,base_charge,per_kg_charge,free_shipping_threshold from zone_shipping_rates where zone_id=:z and (:m is null or shipping_method_id=:m) and is_active=true order by shipping_method_id'),{'z':p['zone_id'],'m':b.shipping_method_id})).mappings().all()
 return [{'shipping_method_id':x['shipping_method_id'],'charge':0 if x['free_shipping_threshold'] is not None and b.order_amount>=float(x['free_shipping_threshold']) else float(x['base_charge'])+float(x['per_kg_charge'])*b.weight_kg,'eta_start':str(date.today()+timedelta(days=1)),'eta_end':str(date.today()+timedelta(days=7)),'cod_available':p['cod_available']} for x in q]
