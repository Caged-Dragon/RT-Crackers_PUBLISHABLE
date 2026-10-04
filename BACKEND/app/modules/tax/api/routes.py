from fastapi import APIRouter,Depends
from decimal import Decimal,ROUND_HALF_UP
from pydantic import BaseModel
from sqlalchemy import text
from ....core.database import get_db
from ....core.security import require_roles
from ....database.models import HSNCode
class TaxIn(BaseModel): amount:Decimal; gst_percentage:Decimal; intra_state:bool=True
router=APIRouter(prefix='/tax',tags=['Tax'])
@router.post('/calculate')
async def calculate(b:TaxIn):
 tax=(b.amount*b.gst_percentage/100).quantize(Decimal('0.01'),rounding=ROUND_HALF_UP); half=(tax/2).quantize(Decimal('0.01')); return {'success':True,'data':{'tax':tax,'cgst':half if b.intra_state else Decimal(0),'sgst':half if b.intra_state else Decimal(0),'igst':Decimal(0) if b.intra_state else tax,'total':b.amount+tax}}
@router.get('/hsn/{code}')
async def hsn(code:str,db=Depends(get_db)):
 r=(await db.execute(text('select code,description,gst_percentage,cess_percentage,is_active from rtc_hsn_codes where code=:c'),{'c':code})).mappings().first(); return {'success':True,'data':dict(r) if r else None}
@router.get('/report')
async def report(db=Depends(get_db),_=Depends(require_roles('A','ADMIN'))):
 r=(await db.execute(text("select date_trunc('month',created_at) month,coalesce(sum(tax_amount),0) tax,coalesce(sum(subtotal),0) taxable_value from orders group by 1 order by 1 desc limit 24"))).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
