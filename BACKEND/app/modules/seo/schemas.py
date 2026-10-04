from pydantic import BaseModel
class SEOIn(BaseModel): entity_type:str; entity_id:str; meta_title:str|None=None; meta_description:str|None=None; canonical_url:str|None=None; robots:str='index,follow'; og_image:str|None=None
