from datetime import date
from pydantic import EmailStr,Field
from ADMINS.base import Schema
class AdminCreate(Schema): email:EmailStr; phone:str=Field(min_length=10,max_length=10); first_name:str; last_name:str|None=None; password:str=Field(min_length=12,max_length=128); employee_code:str; department:str|None=None; designation:str|None=None; hired_date:date|None=None; role_ids:list[int]=[]
class AdminUpdate(Schema): department:str|None=None; designation:str|None=None; hired_date:date|None=None; status:str|None=None
class RoleAssignment(Schema): role_ids:list[int]
class PermissionAssignment(Schema): permission_ids:list[int]
