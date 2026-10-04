from __future__ import annotations
import hashlib,secrets,uuid,hmac
from datetime import datetime,timedelta,timezone
from typing import Any
import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError,VerificationError,VerifyMismatchError
from core.config import settings
from core.exceptions import UnauthorizedError
_hasher=PasswordHasher()
def hash_password(p:str)->str:return _hasher.hash(p)
def verify_password(p:str,h:str)->bool:
    try:return _hasher.verify(h,p)
    except (VerifyMismatchError,VerificationError,InvalidHashError):return False
def create_token(sub:str,typ:str,ttl:timedelta,extra:dict[str,Any]|None=None):
    now=datetime.now(timezone.utc); exp=now+ttl; jti=uuid.uuid4().hex; d={'sub':sub,'type':typ,'jti':jti,'iat':now,'exp':exp}; d.update(extra or {}); return jwt.encode(d,settings.JWT_SECRET_KEY,algorithm=settings.JWT_ALGORITHM),jti,exp
def decode_token(token:str,expected_type:str):
    try:p=jwt.decode(token,settings.JWT_SECRET_KEY,algorithms=[settings.JWT_ALGORITHM],options={'require':['exp','sub','type']})
    except jwt.ExpiredSignatureError as e:raise UnauthorizedError('Token has expired',code='token_expired') from e
    except jwt.PyJWTError as e:raise UnauthorizedError('Invalid token',code='invalid_token') from e
    if p.get('type')!=expected_type:raise UnauthorizedError('Invalid token type',code='invalid_token')
    return p
def create_access_token(admin_id:int,session_id:uuid.UUID): return create_token(str(admin_id),'admin_access',timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),{'sid':str(session_id)})
def create_refresh_token(admin_id:int,session_id:uuid.UUID): return create_token(str(admin_id),'admin_refresh',timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),{'sid':str(session_id)})
def hash_token(raw:str):return hashlib.sha256(raw.encode()).hexdigest()
def generate_token(nbytes=32):return secrets.token_urlsafe(nbytes)
def constant_time_equals(a,b):return hmac.compare_digest(a.encode(),b.encode())
