from sqlalchemy import select
from ADMINS.permissions.models import Permission
class Repository:
 def __init__(self,s):self.s=s
 async def list(self):return list((await self.s.execute(select(Permission).order_by(Permission.module_name,Permission.permission_code))).scalars())
 async def get(self,id):return await self.s.get(Permission,id)
