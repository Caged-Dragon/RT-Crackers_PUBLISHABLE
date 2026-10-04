"""Access logging with latency."""
from __future__ import annotations

import logging
import time

from starlette.types import ASGIApp, Message, Receive, Scope, Send

logger = logging.getLogger("rtcrackers.access")


class AccessLogMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        start = time.perf_counter()
        status = {"code": 500}

        async def send_wrapper(message: Message) -> None:
            if message["type"] == "http.response.start":
                status["code"] = message["status"]
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            elapsed = (time.perf_counter() - start) * 1000
            user_id = scope.get("state", {}).get("user_id")
            logger.info("%s %s -> %s (%.1f ms) user=%s", scope["method"], scope["path"], status["code"], elapsed, user_id or "-")


# Backward-compatible descriptive name used by application bootstrap.
RequestLoggingMiddleware = AccessLogMiddleware
