from fastapi import APIRouter,Depends,HTTPException
from ....core.database import get_db
from ....utils.orm import to_dict
from ....core.security import current_user
from ..schemas import InvoiceGenerate
from ..services.service import generate
router=APIRouter(prefix='/invoices',tags=['Invoices'])
@router.post('/generate')
async def create(b:InvoiceGenerate,user=Depends(current_user),db=Depends(get_db)):
 try:return {'success':True,'data':{'url':await generate(db,b.order_id)}}
 except Exception as e: raise HTTPException(400,str(e))
