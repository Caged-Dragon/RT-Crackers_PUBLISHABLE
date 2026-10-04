from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import settings
from core.database import check_database, engine
from core.exceptions import register_exception_handlers
from middleware.logging import RequestLoggingMiddleware
from middleware.rate_limit import RateLimitMiddleware
from middleware.security_headers import SecurityHeadersMiddleware
from core.observability import MetricsMiddleware, metrics_response
from middleware.request_id import RequestIdMiddleware

from ADMINS.auth.routes import router as auth_router
from ADMINS.admin_users.routes import router as admin_users_router
from ADMINS.roles.routes import router as roles_router
from ADMINS.permissions.routes import router as permissions_router
from ADMINS.dashboard.routes import router as dashboard_router
from ADMINS.products.routes import router as products_router
from ADMINS.categories.routes import router as categories_router
from ADMINS.inventory.routes import router as inventory_router
from ADMINS.orders.routes import router as orders_router
from ADMINS.customers.routes import router as customers_router
from ADMINS.coupons.routes import router as coupons_router
from ADMINS.banners.routes import router as banners_router
from ADMINS.newsletters.routes import router as newsletters_router
from ADMINS.shipping.routes import router as shipping_router
from ADMINS.delivery.routes import router as delivery_router
from ADMINS.cms.routes import router as cms_router
from ADMINS.settings.routes import router as settings_router
from ADMINS.analytics.routes import router as analytics_router
from ADMINS.reports.routes import router as reports_router
from ADMINS.audit.routes import router as audit_router
from ADMINS.platform.routes import router as platform_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Database connectivity is reported by /health; the API process itself can start
    # even when the database is temporarily unavailable.
    yield
    if engine is not None:
        await engine.dispose()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    debug=settings.DEBUG,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.add_middleware(RequestIdMiddleware)
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(MetricsMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
register_exception_handlers(app)

_ROUTERS = (
    auth_router, admin_users_router, roles_router, permissions_router, dashboard_router,
    products_router, categories_router, inventory_router, orders_router, customers_router,
    coupons_router, banners_router, newsletters_router, shipping_router, delivery_router,
    cms_router, settings_router, analytics_router, reports_router, audit_router, platform_router,
)
for router in _ROUTERS:
    app.include_router(router, prefix=settings.API_V1_PREFIX)


@app.get("/health", tags=["System"])
async def health():
    try:
        await check_database()
        return {"status": "ok", "database": "ok", "version": settings.APP_VERSION}
    except Exception:
        return JSONResponse(
            {"status": "degraded", "database": "unavailable", "version": settings.APP_VERSION},
            status_code=503,
        )


@app.get("/ready", tags=["System"])
async def ready():
    await check_database()
    return {"status": "ready", "database": "ok", "version": settings.APP_VERSION}

@app.get("/metrics", include_in_schema=False)
async def metrics():
    return metrics_response()

@app.get("/", include_in_schema=False)
async def root():
    return {"name": settings.APP_NAME, "version": settings.APP_VERSION, "docs": "/docs", "health": "/health"}
