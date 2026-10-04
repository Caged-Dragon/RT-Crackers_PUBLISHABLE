from fastapi import FastAPI,Request
from fastapi.responses import JSONResponse
import logging
log=logging.getLogger('rtcrackers.errors')
def register_exception_handlers(app:FastAPI):
 @app.exception_handler(Exception)
 async def handler(request:Request,exc:Exception):
  log.exception('unhandled_exception',extra={'path':str(request.url.path)}); return JSONResponse({'success':False,'error':{'code':'INTERNAL_ERROR','message':'Internal server error'}},500)
