from sqlalchemy import select,update
from sqlalchemy.ext.asyncio import AsyncSession
from ADMINS.auth.models import User,Admin,Session,RefreshToken,PasswordResetToken
class Repository:
 def __init__(self,s:AsyncSession):self.s=s
 async def admin_by_email(self,email):
  q=select(Admin,User).join(User,User.user_id==Admin.user_id).where(User.email==email.lower())
  return (await self.s.execute(q)).first()
 async def admin(self,admin_id):
  q=select(Admin,User).join(User,User.user_id==Admin.user_id).where(Admin.admin_id==admin_id); return (await self.s.execute(q)).first()
 async def active_refresh(self,h): return (await self.s.execute(select(RefreshToken).where(RefreshToken.token_hash==h,RefreshToken.revoked_at.is_(None)))).scalar_one_or_none()
 async def revoke_refresh(self,h): await self.s.execute(update(RefreshToken).where(RefreshToken.token_hash==h).values(revoked_at=__import__('datetime').datetime.utcnow()))
