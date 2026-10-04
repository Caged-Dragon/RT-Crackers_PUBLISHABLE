import time,uuid
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi.responses import JSONResponse
from redis.asyncio import from_url
from ..core.config import settings
from ..modules.monitoring.api.routes import REQUESTS
class GatewayMiddleware(BaseHTTPMiddleware):
 async def dispatch(self,request,call_next):
  rid=request.headers.get('x-request-id') or str(uuid.uuid4()); request.state.request_id=rid; REQUESTS.inc()
  if request.url.path.startswith('/api/v1'):
   r=from_url(settings.REDIS_URL,decode_responses=True); key=f'rl:{request.client.host if request.client else "unknown"}'; n=await r.incr(key); await r.expire(key,60)
   if n>settings.RATE_LIMIT_PER_MINUTE: await r.close(); return JSONResponse({'success':False,'error':{'code':'RATE_LIMITED','message':'Too many requests'}},429,headers={'Retry-After':'60'})
   await r.close()
  t=time.perf_counter()
  try: response=await call_next(request)
  except Exception: raise
  response.headers['X-Request-ID']=rid; response.headers['X-Response-Time-ms']=f'{(time.perf_counter()-t)*1000:.2f}'; return response
