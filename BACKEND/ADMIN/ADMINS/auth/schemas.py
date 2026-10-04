from pydantic import EmailStr,Field,model_validator
from ADMINS.base import Schema,Message
class LoginRequest(Schema): email:EmailStr; password:str=Field(min_length=8,max_length=128)
class TokenPair(Schema): access_token:str; refresh_token:str; token_type:str='bearer'; expires_in:int
class RefreshRequest(Schema): refresh_token:str=Field(min_length=20)
class ChangePasswordRequest(Schema): current_password:str; new_password:str=Field(min_length=12,max_length=128)
class ForgotPasswordRequest(Schema): email:EmailStr
class ResetPasswordRequest(Schema): token:str; new_password:str=Field(min_length=12,max_length=128)
class AdminOut(Schema): admin_id:int; user_id:int; employee_code:str; department:str|None=None; designation:str|None=None; status:str
