from pydantic import BaseModel,Field
class ShippingQuote(BaseModel): pincode:str=Field(pattern=r'^\d{6}$'); order_amount:float=0; weight_kg:float=1; shipping_method_id:int|None=None
