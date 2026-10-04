from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.responses import PlainTextResponse
from starlette.types import ASGIApp, Receive, Scope, Send, Message

REQUESTS = Counter('rtcrackers_http_requests_total', 'HTTP requests', ['method', 'path', 'status'])
LATENCY = Histogram('rtcrackers_http_request_duration_seconds', 'HTTP request latency', ['method', 'path'])

class MetricsMiddleware:
    def __init__(self, app: ASGIApp) -> None: self.app = app
    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope['type'] != 'http':
            await self.app(scope, receive, send); return
        import time
        start=time.perf_counter(); status={'code':500}
        async def wrapped(message: Message):
            if message['type']=='http.response.start': status['code']=message['status']
            await send(message)
        try: await self.app(scope, receive, wrapped)
        finally:
            path=scope.get('path','')
            if not path.startswith('/metrics'):
                REQUESTS.labels(scope.get('method','?'), path, str(status['code'])).inc()
                LATENCY.labels(scope.get('method','?'), path).observe(time.perf_counter()-start)

def metrics_response():
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)
