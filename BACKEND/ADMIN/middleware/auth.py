from __future__ import annotations
import jwt
from starlette.datastructures import Headers
from starlette.types import ASGIApp,Receive,Scope,Send
from core.config import settings
class AuthContextMiddleware:
    def __init__(self,app:ASGIApp): self.app=app
    async def __call__(self,scope:Scope,receive:Receive,send:Send):
        if scope["type"]=="http":
            state=scope.setdefault("state",{}); state["admin_id"]=None
            auth=Headers(scope=scope).get("authorization","")
            if auth.lower().startswith("bearer "):
                try:
                    payload=jwt.decode(auth[7:].strip(),settings.JWT_SECRET_KEY,algorithms=[settings.JWT_ALGORITHM],options={"verify_exp":True})
                    if payload.get("type")=="admin_access": state["admin_id"]=int(payload["sub"])
                except (jwt.PyJWTError,ValueError,KeyError):
                    state["admin_id"]=None
        await self.app(scope,receive,send)
