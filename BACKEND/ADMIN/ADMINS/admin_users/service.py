from datetime import datetime
from core.security import hash_password
from core.exceptions import ConflictError,NotFoundError
from ADMINS.auth.models import User,Admin
from ADMINS.roles.models import AdminRole
from ADMINS.permissions.models import AdminPermission
from ADMINS.admin_users.repository import Repository
class Service:
 def __init__(self,s,aid):self.s=s;self.aid=aid;self.r=Repository(s)
 async def list(self,p=1,ps=50):return await self.r.list((p-1)*ps,ps),await self.r.count()
 async def create(self,v):
  if await self.r.by_email(v.email.lower()):raise ConflictError('Email already exists')
  u=User(email=v.email.lower(),phone=v.phone,first_name=v.first_name,last_name=v.last_name,password_hash=hash_password(v.password),status='A',email_verified=False,phone_verified=False,failed_login_count=0,account_locked=False,created_at=datetime.utcnow(),updated_at=datetime.utcnow());self.s.add(u);await self.s.flush()
  a=Admin(user_id=u.user_id,employee_code=v.employee_code,department=v.department,designation=v.designation,hired_date=v.hired_date,status='A',created_at=datetime.utcnow(),updated_at=datetime.utcnow());self.s.add(a);await self.s.flush()
  for rid in v.role_ids:self.s.add(AdminRole(admin_id=a.admin_id,role_id=rid,assigned_by=self.aid,created_at=datetime.utcnow(),updated_at=datetime.utcnow()))
  await self.s.commit();return a
 async def get(self,id):row=await self.r.by_id(id);return row if row else (_ for _ in ()).throw(NotFoundError('Admin not found'))
 async def update(self,id,v):
  row=await self.r.by_id(id)
  if not row:raise NotFoundError('Admin not found')
  a,u=row
  for k,val in v.model_dump(exclude_none=True).items():
   if k in {'department','designation','hired_date','status'}:setattr(a,k,val)
  await self.s.commit();return a
 async def roles(self,id,ids):
  a=await self.s.get(Admin,id)
  if not a:raise NotFoundError('Admin not found')
  from sqlalchemy import delete
  await self.s.execute(delete(AdminRole).where(AdminRole.admin_id==id))
  for rid in ids:self.s.add(AdminRole(admin_id=id,role_id=rid,assigned_by=self.aid,created_at=datetime.utcnow(),updated_at=datetime.utcnow()))
  await self.s.commit()
 async def permissions(self,id,ids):
  a=await self.s.get(Admin,id)
  if not a:raise NotFoundError('Admin not found')
  from sqlalchemy import delete
  await self.s.execute(delete(AdminPermission).where(AdminPermission.admin_id==id))
  for pid in ids:self.s.add(AdminPermission(admin_id=id,permission_id=pid,is_granted=True,granted_by=self.aid,created_at=datetime.utcnow(),updated_at=datetime.utcnow()))
  await self.s.commit()
 async def set_status(self,id,status):
  a=await self.s.get(Admin,id)
  if not a:raise NotFoundError('Admin not found')
  a.status=status;await self.s.commit();return a
