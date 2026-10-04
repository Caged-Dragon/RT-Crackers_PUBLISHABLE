from sqlalchemy import delete
from ADMINS.roles.repository import Repository
from ADMINS.permissions.models import RolePermission
from core.exceptions import NotFoundError,ConflictError
class Service:
 def __init__(self,s,admin_id):self.s=s;self.admin_id=admin_id;self.r=Repository(s)
 async def list(self):return await self.r.list()
 async def create(self,v):
  o=await self.r.create(role_code=v.role_code.upper(),role_name=v.role_name,description=v.description,is_active=v.is_active);await self.s.commit();return o
 async def update(self,id,v):
  o=await self.r.get(id)
  if not o:raise NotFoundError('Role not found')
  for k,val in v.model_dump(exclude_none=True).items():setattr(o,k,val)
  await self.s.commit();return o
 async def delete(self,id):
  o=await self.r.get(id)
  if not o:raise NotFoundError('Role not found')
  if o.is_system:raise ConflictError('System role cannot be deleted')
  await self.s.delete(o);await self.s.commit()
 async def permissions(self,id,ids):
  o=await self.r.get(id)
  if not o:raise NotFoundError('Role not found')
  await self.s.execute(delete(RolePermission).where(RolePermission.role_id==id))
  for pid in ids:self.s.add(RolePermission(role_id=id,permission_id=pid))
  await self.s.commit();return await self.r.permissions(id)
