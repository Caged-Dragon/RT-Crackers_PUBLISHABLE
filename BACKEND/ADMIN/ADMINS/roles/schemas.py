from typing import Any
from ADMINS.base import Schema
class RoleCreate(Schema): role_code:str; role_name:str; description:str|None=None; is_active:bool=True
class RoleUpdate(Schema): role_name:str|None=None; description:str|None=None; is_active:bool|None=None
class PermissionAssignment(Schema): permission_ids:list[int]
