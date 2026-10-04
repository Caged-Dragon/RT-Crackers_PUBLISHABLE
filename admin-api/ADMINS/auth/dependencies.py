from __future__ import annotations
from fastapi import Depends, Request
from fastapi.security import HTTPBearer,HTTPAuthorizationCredentials
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db,set_audit_user
from core.exceptions import UnauthorizedError,ForbiddenError
from core.security import decode_token
from ADMINS.auth.models import Admin,User
from ADMINS.permissions.models import Permission,RolePermission,AdminPermission
from ADMINS.roles.models import AdminRole,Role
bearer=HTTPBearer(auto_error=False)
class CurrentAdmin:
 def __init__(self,admin_id,user_id,admin):self.admin_id=admin_id;self.user_id=user_id;self.admin=admin
async def get_current_admin(request:Request,creds:HTTPAuthorizationCredentials=Depends(bearer),db:AsyncSession=Depends(get_db)):
 if not creds and request.cookies.get("rtc_admin_access_token"):
  creds=HTTPAuthorizationCredentials(scheme="Bearer",credentials=request.cookies["rtc_admin_access_token"])
 if not creds:raise UnauthorizedError('Authentication required',code='auth_required')
 p=decode_token(creds.credentials,'admin_access'); aid=int(p['sub']); sid=p.get('sid'); row=(await db.execute(select(Admin,User).join(User,User.user_id==Admin.user_id).where(Admin.admin_id==aid))).first()
 if not row or row[0].status!='A' or row[1].status!='A' or row[1].account_locked:raise UnauthorizedError('Admin account is inactive',code='admin_inactive')
 
 from ADMINS.auth.models import Session
 if sid:
  sess=await db.get(Session,sid)
  from datetime import datetime
  if not sess or sess.ended_at is not None or sess.expires_at <= datetime.utcnow(): raise UnauthorizedError('Session expired',code='session_expired')
 await set_audit_user(db,row[1].user_id)
 return CurrentAdmin(aid,row[1].user_id,row[0])
def require_permission(permission:str):
 async def dep(admin=Depends(get_current_admin),db:AsyncSession=Depends(get_db)):
  direct=(await db.execute(select(AdminPermission.is_granted).join(Permission,Permission.permission_id==AdminPermission.permission_id).where(AdminPermission.admin_id==admin.admin_id,Permission.permission_code==permission.upper()))).scalar_one_or_none()
  if direct is not None:
   if not direct:raise ForbiddenError('Permission denied',code='permission_denied')
   return admin
  stmt=select(RolePermission.permission_id).join(AdminRole,AdminRole.role_id==RolePermission.role_id).join(Permission,Permission.permission_id==RolePermission.permission_id).join(Role,Role.role_id==AdminRole.role_id).where(AdminRole.admin_id==admin.admin_id,Permission.permission_code==permission.upper(),Role.is_active.is_(True))
  if (await db.execute(stmt)).first() is None:raise ForbiddenError('Permission denied',code='permission_denied')
  return admin
 return dep
