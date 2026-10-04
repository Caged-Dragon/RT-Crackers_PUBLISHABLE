import asyncio,os
from datetime import datetime
from sqlalchemy import select
from core.database import async_session_factory
from core.security import hash_password
from ADMINS.auth.models import User,Admin
from ADMINS.roles.models import Role,AdminRole
async def main():
 email=os.environ['ADMIN_EMAIL'].lower(); password=os.environ['ADMIN_PASSWORD']; phone=os.environ['ADMIN_PHONE']; employee=os.environ.get('ADMIN_EMPLOYEE_CODE','ADMIN001')
 async with async_session_factory() as s:
  exists=(await s.execute(select(User).where(User.email==email))).scalar_one_or_none()
  if exists: raise SystemExit('User already exists')
  now=datetime.utcnow();u=User(email=email,phone=phone,first_name=os.environ.get('ADMIN_FIRST_NAME','Admin'),last_name=os.environ.get('ADMIN_LAST_NAME'),password_hash=hash_password(password),status='A',email_verified=True,phone_verified=True,failed_login_count=0,account_locked=False,created_at=now,updated_at=now);s.add(u);await s.flush()
  a=Admin(user_id=u.user_id,employee_code=employee,status='A',created_at=now,updated_at=now);s.add(a);await s.flush();r=(await s.execute(select(Role).where(Role.role_code=='SUPER_ADMIN'))).scalar_one();s.add(AdminRole(admin_id=a.admin_id,role_id=r.role_id,created_at=now,updated_at=now));await s.commit();print(f'Created admin {a.admin_id}')
if __name__=='__main__':asyncio.run(main())
