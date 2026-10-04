import os
os.environ.setdefault('DATABASE_URL','postgresql+asyncpg://x:x@localhost/x'); os.environ.setdefault('JWT_SECRET_KEY','x'*40)
from app.core.security import hash_password,verify_password,create_access_token,decode_token
def test_password():
 h=hash_password('StrongPassword!123'); assert verify_password('StrongPassword!123',h)
def test_jwt():
 t=create_access_token(42); assert decode_token(t)['sub']=='42'
