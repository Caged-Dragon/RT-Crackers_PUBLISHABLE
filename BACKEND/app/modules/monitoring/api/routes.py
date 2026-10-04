from fastapi import APIRouter
from fastapi.responses import PlainTextResponse
from prometheus_client import generate_latest,CONTENT_TYPE_LATEST,Counter
from ....core.database import check_db
REQUESTS=Counter('rtcrackers_requests_total','Total API requests')
router=APIRouter(tags=['Monitoring'])
@router.get('/health')
async def health():
 try: await check_db(); return {'status':'ok','database':'ok'}
 except Exception: return {'status':'degraded','database':'unavailable'}
@router.get('/ready')
async def ready():
 await check_db(); return {'status':'ready'}
@router.get('/metrics')
async def metrics(): return PlainTextResponse(generate_latest(),media_type=CONTENT_TYPE_LATEST)
