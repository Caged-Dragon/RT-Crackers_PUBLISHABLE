from __future__ import annotations
import uuid
from datetime import datetime,timedelta,timezone
from sqlalchemy import select,update
from sqlalchemy.ext.asyncio import AsyncSession
from core.config import settings
from core.exceptions import UnauthorizedError,ConflictError
from core.security import *
from ADMINS.auth.models import User,Admin,Session,RefreshToken,PasswordResetToken
from ADMINS.auth.repository import Repository
class AuthService:
 def __init__(self,s:AsyncSession):self.s=s;self.r=Repository(s)
 async def login(self,email,password,ip=None,ua=None):
  row=await self.r.admin_by_email(str(email).lower())
  if not row:raise UnauthorizedError('Invalid credentials',code='invalid_credentials')
  admin,user=row
  if admin.status!='A' or user.status!='A' or user.account_locked:raise UnauthorizedError('Admin account is inactive',code='admin_inactive')
  if not verify_password(password,user.password_hash):
   user.failed_login_count+=1
   if user.failed_login_count>=settings.MAX_FAILED_LOGINS:user.account_locked=True
   await self.s.commit();raise UnauthorizedError('Invalid credentials',code='invalid_credentials')
  user.failed_login_count=0; user.last_login=datetime.utcnow(); admin.last_admin_login=datetime.utcnow()
  sid=uuid.uuid4(); now=datetime.utcnow(); exp=now+timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
  sess=Session(session_id=sid,user_id=user.user_id,ip_address=ip,user_agent=ua,device_type='W',last_activity_at=now,expires_at=exp,created_at=now,updated_at=now); self.s.add(sess)
  access,_,aexp=create_access_token(admin.admin_id,sid); refresh,_,rexp=create_refresh_token(admin.admin_id,sid); self.s.add(RefreshToken(user_id=user.user_id,session_id=sid,token_hash=hash_token(refresh),expires_at=rexp,created_at=now,updated_at=now)); await self.s.commit()
  return access,refresh,aexp
 async def refresh(self,raw):
  p=decode_token(raw,'admin_refresh'); h=hash_token(raw); rt=await self.r.active_refresh(h)
  if not rt or rt.expires_at<=datetime.utcnow():raise UnauthorizedError('Refresh token invalid',code='invalid_refresh')
  row=await self.r.admin(p['sub']); admin,user=row; await self.r.revoke_refresh(h)
  access,_,aexp=create_access_token(admin.admin_id,rt.session_id); new,_,rexp=create_refresh_token(admin.admin_id,rt.session_id); self.s.add(RefreshToken(user_id=user.user_id,session_id=rt.session_id,token_hash=hash_token(new),expires_at=rexp,created_at=datetime.utcnow(),updated_at=datetime.utcnow())); await self.s.commit(); return access,new,aexp
 async def change_password(self,admin_id,current,new):
  row=await self.r.admin(admin_id); admin,user=row
  if not verify_password(current,user.password_hash):raise UnauthorizedError('Current password is incorrect',code='invalid_password')
  user.password_hash=hash_password(new); user.last_password_change=datetime.utcnow(); await self.s.execute(update(RefreshToken).where(RefreshToken.user_id==user.user_id).values(revoked_at=datetime.utcnow())); await self.s.commit()
 async def forgot(self,email,ip=None):
  row=await self.r.admin_by_email(str(email).lower())
  if not row:return
  _,user=row; raw=generate_token(); self.s.add(PasswordResetToken(user_id=user.user_id,token_hash=hash_token(raw),requested_ip=ip,expires_at=datetime.utcnow()+timedelta(minutes=settings.PASSWORD_RESET_EXPIRE_MINUTES),created_at=datetime.utcnow())); await self.s.commit(); return raw
 async def reset(self,raw,new):
  row=(await self.s.execute(select(PasswordResetToken).where(PasswordResetToken.token_hash==hash_token(raw),PasswordResetToken.used_at.is_(None)))).scalar_one_or_none()
  if not row or row.expires_at<=datetime.utcnow():raise UnauthorizedError('Reset token invalid or expired',code='invalid_reset_token')
  user=await self.s.get(User,row.user_id); user.password_hash=hash_password(new); user.last_password_change=datetime.utcnow(); row.used_at=datetime.utcnow(); await self.s.execute(update(RefreshToken).where(RefreshToken.user_id==user.user_id).values(revoked_at=datetime.utcnow())); await self.s.commit()
