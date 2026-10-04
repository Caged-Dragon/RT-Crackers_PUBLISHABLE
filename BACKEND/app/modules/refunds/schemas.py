from pydantic import BaseModel,Field
from decimal import Decimal
class RefundRequestIn(BaseModel): order_id:int; amount:Decimal=Field(gt=0); reason:str=Field(min_length=3,max_length=500)
class RefundStatusIn(BaseModel): status:str; provider_refund_id:str|None=None; notes:str|None=None
