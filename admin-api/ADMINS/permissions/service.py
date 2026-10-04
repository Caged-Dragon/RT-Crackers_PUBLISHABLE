from core.exceptions import NotFoundError,ConflictError
from ADMINS.permissions.repository import Repository
from ADMINS.permissions.models import Permission
class Service:
 def __init__(self,s,aid):self.s=s;self.r=Repository(s)
 async def list(self):return await self.r.list()
 async def create(self,p):o=Permission(permission_code=p.permission_code.upper(),module_name=p.module_name,description=p.description);self.s.add(o);await self.s.commit();return o
 async def update(self,id,p):
  o=await self.r.get(id)
  if not o:raise NotFoundError('Permission not found')
  for k,v in p.model_dump(exclude_none=True).items():setattr(o,k,v)
  await self.s.commit();return o
 async def delete(self,id):
  o=await self.r.get(id)
  if not o:raise NotFoundError('Permission not found')
  await self.s.delete(o);await self.s.commit()
