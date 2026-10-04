from pydantic import BaseModel,Field
class PageIn(BaseModel): slug:str; title:str; content_html:str; status:str='D'; meta_title:str|None=None; meta_description:str|None=None
class FAQIn(BaseModel): question:str; answer_html:str; display_order:int=0; is_active:bool=True
