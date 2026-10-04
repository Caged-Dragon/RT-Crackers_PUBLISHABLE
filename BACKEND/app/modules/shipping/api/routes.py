from fastapi import APIRouter,Depends,HTTPException
from ....core.database import get_db
from ..schemas import ShippingQuote
from ..services.service import quote
router=APIRouter(prefix='/shipping',tags=['Shipping'])
@router.post('/quote')
async def shipping_quote(b:ShippingQuote,db=Depends(get_db)):
 try:return {'success':True,'data':await quote(db,b)}
 except Exception as e: raise HTTPException(400,str(e))
