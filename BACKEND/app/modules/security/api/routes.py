from fastapi import APIRouter,Depends,Request,HTTPException
from sqlalchemy import text,select
from ....core.database import get_db
from ....core.security import current_user,decode_token
from ....database.models import SecurityEvent,RevokedToken
from datetime import datetime
router=APIRouter(prefix='/security',tags=['Security'])
@router.get('/sessions')
async def sessions(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(text('select session_id,ip_address,user_agent,device_type,last_activity_at,expires_at,ended_at from sessions where user_id=:u order by created_at desc'),{'u':user['user_id']})).mappings().all(); return {'success':True,'data':[dict(x) for x in r]}
@router.post('/sessions/{session_id}/revoke')
async def revoke(session_id:str,user=Depends(current_user),db=Depends(get_db)):
 await db.execute(text('update sessions set ended_at=now() where session_id=:s and user_id=:u'),{'s':session_id,'u':user['user_id']}); await db.commit(); return {'success':True}
@router.get('/events')
async def events(user=Depends(current_user),db=Depends(get_db)):
 r=(await db.execute(select(SecurityEvent).where(SecurityEvent.user_id==user['user_id']).order_by(SecurityEvent.created_at.desc()).limit(100))).scalars().all(); return {'success':True,'data':[x.__dict__ for x in r]}
@router.post('/password-policy/check')
async def password_policy(password:str):
 import re
 ok=len(password)>=12 and bool(re.search('[A-Z]',password)) and bool(re.search('[a-z]',password)) and bool(re.search(r'\d',password)) and bool(re.search(r'[^A-Za-z0-9]',password)); return {'success':True,'data':{'valid':ok}}
@router.post('/token/revoke')
async def revoke_token(request:Request,user=Depends(current_user),db=Depends(get_db)):
 from fastapi.security import HTTPAuthorizationCredentials
 from ...core.security import bearer,decode_token
 creds=await bearer(request)
 if not creds: raise HTTPException(401,'Authentication required')
 p=decode_token(creds.credentials); from ...database.models import RevokedToken
 if p.get('jti'): db.add(RevokedToken(jti=p['jti'],expires_at=datetime.fromtimestamp(p['exp']))); await db.commit()
 return {'success':True}
