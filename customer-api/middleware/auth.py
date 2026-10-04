"""Lightweight auth-context middleware.

Decodes a bearer token *without touching the database* purely to attach `user_id` to the request
state (for logging / rate-limit keys). Authorization itself is enforced by the `get_current_user`
dependency, which also validates the session row.
"""
from __future__ import annotations

import jwt
from starlette.datastructures import Headers
from starlette.types import ASGIApp, Receive, Scope, Send

from core.config import settings


class AuthContextMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "http":
            state = scope.setdefault("state", {})
            state["user_id"] = None
            auth = Headers(scope=scope).get("authorization", "")
            if auth.lower().startswith("bearer "):
                try:
                    payload = jwt.decode(auth[7:].strip(), settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
                    if payload.get("type") == "access":
                        state["user_id"] = int(payload["sub"])
                except (jwt.PyJWTError, ValueError, KeyError):
                    pass
        await self.app(scope, receive, send)
