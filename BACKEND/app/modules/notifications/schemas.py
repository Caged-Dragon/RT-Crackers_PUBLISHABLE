from pydantic import BaseModel,Field
class NotificationSend(BaseModel): user_id:int|None=None; channel:str; destination:str; template:str; data:dict={}
