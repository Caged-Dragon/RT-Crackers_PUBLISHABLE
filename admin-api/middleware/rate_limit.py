"""Sliding-window rate limiter (per client IP, stricter on /auth).

State is in-process: with several workers/instances each keeps its own window. Put a shared limiter
(API gateway / Redis) in front if you need a global limit.
"""
from __future__ import annotations

import time
from collections import defaultdict, deque

from starlette.datastructures import Headers
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send

from core.config import settings
from middleware.request_id import get_request_id


class RateLimitMiddleware:
    WINDOW = 60.0

    def __init__(self, app: ASGIApp) -> None:
        self.app = app
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._last_sweep = time.monotonic()

    def _key_and_limit(self, scope: Scope) -> tuple[str, int]:
        headers = Headers(scope=scope)
        fwd = headers.get("x-forwarded-for")
        ip = fwd.split(",")[0].strip() if fwd else (scope["client"][0] if scope.get("client") else "unknown")
        if scope["path"].startswith(f"{settings.API_V1_PREFIX}/auth"):
            return f"auth:{ip}", settings.RATE_LIMIT_AUTH_PER_MINUTE
        return f"api:{ip}", settings.RATE_LIMIT_PER_MINUTE

    def _sweep(self, now: float) -> None:
        if now - self._last_sweep < 300:
            return
        self._last_sweep = now
        for key in [k for k, q in self._hits.items() if not q or q[-1] < now - self.WINDOW]:
            del self._hits[key]

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or not settings.RATE_LIMIT_ENABLED or scope["path"] in ("/health", "/ready"):
            await self.app(scope, receive, send)
            return
        key, limit = self._key_and_limit(scope)
        now = time.monotonic()
        self._sweep(now)
        window = self._hits[key]
        while window and window[0] <= now - self.WINDOW:
            window.popleft()
        if len(window) >= limit:
            retry = max(1, int(self.WINDOW - (now - window[0])))
            body = {"error": {"code": "rate_limited", "message": "Too many requests, slow down"}, "request_id": get_request_id()}
            await JSONResponse(body, status_code=429, headers={"Retry-After": str(retry)})(scope, receive, send)
            return
        window.append(now)
        await self.app(scope, receive, send)
