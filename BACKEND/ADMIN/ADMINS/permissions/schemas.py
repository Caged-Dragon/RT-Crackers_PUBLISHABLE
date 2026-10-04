from ADMINS.base import Schema
class PermissionCreate(Schema): permission_code:str; module_name:str; description:str|None=None
class PermissionUpdate(Schema): module_name:str|None=None; description:str|None=None
