from pydantic import BaseModel,Field
class RedeemIn(BaseModel): points:int=Field(gt=0)
class EarnIn(BaseModel): points:int=Field(gt=0); transaction_type:str; reference_id:str|None=None; description:str|None=None
