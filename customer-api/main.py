from __future__ import annotations
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from core.config import settings
from core.database import check_database, engine, import_all_models
from core.exceptions import register_exception_handlers
from core.logging import setup_logging
from middleware.auth import AuthContextMiddleware
from middleware.logging import RequestLoggingMiddleware
from middleware.rate_limit import RateLimitMiddleware
from middleware.security_headers import SecurityHeadersMiddleware
from core.observability import MetricsMiddleware, metrics_response
from middleware.request_id import RequestIdMiddleware
from customers.auth.routes import router as auth_router
from customers.profiles.routes import router as profile_router
from customers.addresses.routes import router as addresses_router
from customers.products.routes import router as products_router
from customers.categories.routes import router as categories_router
from customers.search.routes import router as search_router
from customers.cart.routes import router as cart_router
from customers.wishlist.routes import router as wishlist_router
from customers.checkout.routes import router as checkout_router
from customers.orders.routes import router as orders_router
from customers.tracking.routes import router as tracking_router
from customers.reviews.routes import router as reviews_router
from customers.coupons.routes import router as coupons_router
from customers.referrals.routes import router as referrals_router
from customers.notifications.routes import router as notifications_router
from customers.recently_viewed.routes import router as recently_viewed_router
from customers.dashboard.routes import router as dashboard_router
from customers.platform.routes import router as platform_router

setup_logging()
import_all_models()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Connectivity is exposed by /health; startup should remain resilient during
    # short database outages and container orchestration restarts.
    yield
    if engine is not None:
        await engine.dispose()

app=FastAPI(title=settings.APP_NAME,version=settings.APP_VERSION,debug=settings.DEBUG,lifespan=lifespan,docs_url='/docs',redoc_url='/redoc',openapi_url='/openapi.json')
app.add_middleware(RequestIdMiddleware)
app.add_middleware(AuthContextMiddleware)
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(MetricsMiddleware)
app.add_middleware(CORSMiddleware,allow_origins=settings.cors_origin_list,allow_credentials=True,allow_methods=['*'],allow_headers=['*'])
register_exception_handlers(app)
media=settings.LOCAL_MEDIA_DIR
from pathlib import Path
Path(media).mkdir(parents=True,exist_ok=True)
app.mount(settings.MEDIA_URL_PREFIX,StaticFiles(directory=media),name='media')

for router in (auth_router,profile_router,addresses_router,products_router,categories_router,search_router,cart_router,wishlist_router,checkout_router,orders_router,tracking_router,reviews_router,coupons_router,referrals_router,notifications_router,recently_viewed_router,dashboard_router,platform_router):
    app.include_router(router,prefix=settings.API_V1_PREFIX)

@app.get('/health',tags=['System'])
async def health():
    try:
        await check_database(); return {'status':'ok','database':'ok','version':settings.APP_VERSION}
    except Exception:
        return JSONResponse({'status':'degraded','database':'unavailable','version':settings.APP_VERSION},status_code=503)

@app.get('/',include_in_schema=False)
async def root(): return {'name':settings.APP_NAME,'version':settings.APP_VERSION,'docs':'/docs','health':'/health'}
