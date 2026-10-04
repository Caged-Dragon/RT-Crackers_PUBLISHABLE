from sqlalchemy import select,delete
from sqlalchemy.ext.asyncio import AsyncSession
from ADMINS.roles.models import Role,AdminRole
from ADMINS.permissions.models import RolePermission
class Repository:
 def __init__(self,s):self.s=s
 async def list(self):return list((await self.s.execute(select(Role).where(Role.role_scope=='A').order_by(Role.role_name))).scalars())
 async def get(self,id):return await self.s.get(Role,id)
 async def create(self,**v):o=Role(role_scope='A',**v);self.s.add(o);await self.s.flush();return o
 async def permissions(self,id):return list((await self.s.execute(select(RolePermission).where(RolePermission.role_id==id))).scalars())
