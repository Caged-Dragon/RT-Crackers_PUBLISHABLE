from pydantic import BaseModel,ConfigDict,Field
from typing import Generic,TypeVar
T=TypeVar('T')
class Schema(BaseModel): model_config=ConfigDict(from_attributes=True,populate_by_name=True,str_strip_whitespace=True)
class Page(Schema,Generic[T]): items:list[T]; total:int; page:int; page_size:int; pages:int
class Message(Schema): message:str
