from sqlalchemy import select
from ADMINS.auth.models import User,Admin
class Repository:
 def __init__(self,s):self.s=s
 async def by_id(self,id):return (await self.s.execute(select(Admin,User).join(User,User.user_id==Admin.user_id).where(Admin.admin_id==id))).first()
 async def by_email(self,e):return (await self.s.execute(select(User).where(User.email==e))).scalar_one_or_none()
 async def list(self,offset,limit):return list((await self.s.execute(select(Admin,User).join(User,User.user_id==Admin.user_id).order_by(Admin.admin_id.desc()).offset(offset).limit(limit))).all())
 async def count(self):
  from sqlalchemy import func;return (await self.s.execute(select(func.count()).select_from(Admin))).scalar_one()
