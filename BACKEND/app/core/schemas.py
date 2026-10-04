from pydantic import BaseModel,Field
from typing import Any
class APIResponse(BaseModel): success:bool=True; data:Any=None; message:str='OK'
class Paginated(BaseModel): items:list[Any]; page:int; page_size:int; total:int
class Message(BaseModel): message:str
class IDResponse(BaseModel): id:int
