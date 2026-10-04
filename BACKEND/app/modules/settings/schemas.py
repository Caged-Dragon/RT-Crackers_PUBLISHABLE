from pydantic import BaseModel
class SettingIn(BaseModel): value:str; value_type:str='S'; description:str|None=None; is_public:bool=False
