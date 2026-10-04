from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import engine
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging
from app.middleware.gateway import GatewayMiddleware
from app.modules.analytics.api.routes import router as analytics_routes
from app.modules.audit.api.routes import router as audit_routes
from app.modules.cms.api.routes import router as cms_routes
from app.modules.delivery.api.routes import router as delivery_routes
from app.modules.delivery.api.tracking import router as delivery_tracking
from app.modules.files.api.routes import router as files_routes
from app.modules.invoices.api.routes import router as invoices_routes
from app.modules.loyalty.api.routes import router as loyalty_routes
from app.modules.newsletters.api.routes import router as newsletters_routes
from app.modules.notifications.api.routes import router as notifications_routes
from app.modules.payments.api.routes import router as payments_routes
from app.modules.recommendations.api.routes import router as recommendations_routes
from app.modules.referrals.api.routes import router as referrals_routes
from app.modules.reports.api.routes import router as reports_routes
from app.modules.search_engine.api.routes import router as search_engine_routes
from app.modules.security.api.routes import router as security_routes
from app.modules.seo.api.routes import router as seo_routes
from app.modules.settings.api.routes import router as settings_routes
from app.modules.shipping.api.routes import router as shipping_routes
from app.modules.tax.api.routes import router as tax_routes
from app.modules.monitoring.api.routes import router as monitoring
from app.modules.email.router import router as email_routes
from app.modules.email.webhook import router as email_webhook_routes

configure_logging()

@asynccontextmanager
async def lifespan(app):
    yield
    await engine.dispose()

app=FastAPI(title=settings.APP_NAME, version=settings.APP_VERSION, lifespan=lifespan)
app.add_middleware(GatewayMiddleware)
app.add_middleware(CORSMiddleware, allow_origins=[x.strip() for x in settings.CORS_ORIGINS.split(',') if x.strip()], allow_credentials=True, allow_methods=['*'], allow_headers=['*'])
register_exception_handlers(app)
app.include_router(analytics_routes, prefix=settings.API_V1_PREFIX)
app.include_router(audit_routes, prefix=settings.API_V1_PREFIX)
app.include_router(cms_routes, prefix=settings.API_V1_PREFIX)
app.include_router(delivery_routes, prefix=settings.API_V1_PREFIX)
app.include_router(delivery_tracking, prefix=settings.API_V1_PREFIX)
app.include_router(files_routes, prefix=settings.API_V1_PREFIX)
app.include_router(invoices_routes, prefix=settings.API_V1_PREFIX)
app.include_router(loyalty_routes, prefix=settings.API_V1_PREFIX)
app.include_router(newsletters_routes, prefix=settings.API_V1_PREFIX)
app.include_router(notifications_routes, prefix=settings.API_V1_PREFIX)
app.include_router(payments_routes, prefix=settings.API_V1_PREFIX)
app.include_router(recommendations_routes, prefix=settings.API_V1_PREFIX)
app.include_router(referrals_routes, prefix=settings.API_V1_PREFIX)
app.include_router(reports_routes, prefix=settings.API_V1_PREFIX)
app.include_router(search_engine_routes, prefix=settings.API_V1_PREFIX)
app.include_router(security_routes, prefix=settings.API_V1_PREFIX)
app.include_router(seo_routes, prefix=settings.API_V1_PREFIX)
app.include_router(settings_routes, prefix=settings.API_V1_PREFIX)
app.include_router(shipping_routes, prefix=settings.API_V1_PREFIX)
app.include_router(tax_routes, prefix=settings.API_V1_PREFIX)
app.include_router(monitoring)
app.include_router(email_routes, prefix=settings.API_V1_PREFIX + '/email')
app.include_router(email_webhook_routes, prefix=settings.API_V1_PREFIX + '/email')

@app.get('/', include_in_schema=False)
async def root():
    return {'name':settings.APP_NAME,'version':settings.APP_VERSION,'docs':'/docs'}
