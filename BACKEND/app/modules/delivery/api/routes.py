from fastapi import APIRouter,Depends,HTTPException
from sqlalchemy import text
from ....core.database import get_db
router=APIRouter(prefix='/delivery',tags=['Delivery'])
@router.get('/pincode/{pincode}')
async def pincode(pincode:str,db=Depends(get_db)):
 if len(pincode)!=6 or not pincode.isdigit(): raise HTTPException(400,'Invalid pincode')
 r=(await db.execute(text('select postal_code,zone_id,is_serviceable,cod_available from postal_codes where postal_code=:p'),{'p':pincode})).mappings().first()
 if not r: r=(await db.execute(text('select pincode,zone_id,is_serviceable,cod_available from pincodes where pincode=:p'),{'p':pincode})).mappings().first()
 return {'success':True,'data':dict(r) if r else {'postal_code':pincode,'is_serviceable':False,'cod_available':False}}
@router.get('/zones')
async def zones(db=Depends(get_db)):
 r=(await db.execute(text('select * from delivery_zones where is_active=true order by zone_name'))).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
