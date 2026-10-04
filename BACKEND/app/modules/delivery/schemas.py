from pydantic import BaseModel
class PincodeOut(BaseModel): pincode:str; serviceable:bool; cod_available:bool; zone_id:int|None=None
