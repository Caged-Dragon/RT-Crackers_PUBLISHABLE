from decimal import Decimal
from pydantic import BaseModel, Field
class CreatePayment(BaseModel):
    order_id:int
    amount:Decimal=Field(gt=0)
    method:str='COD'
    currency:str='INR'
class VerifyPayment(BaseModel):
    transaction_id:int
class RefundCreate(BaseModel):
    order_id:int
    amount:Decimal=Field(gt=0)
    reason:str=Field(min_length=3,max_length=500)
