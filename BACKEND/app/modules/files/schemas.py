from pydantic import BaseModel
class FileOut(BaseModel): url:str; key:str; size_bytes:int; content_type:str
