from pydantic import BaseModel,Field
class ReturnCreate(BaseModel): order_id:int; order_item_id:int|None=None; return_type:str='refund'; reason:str=Field(min_length=3,max_length=500); replacement_product_id:int|None=None
class ReturnUpdate(BaseModel): status:str; tracking_number:str|None=None; notes:str|None=None
