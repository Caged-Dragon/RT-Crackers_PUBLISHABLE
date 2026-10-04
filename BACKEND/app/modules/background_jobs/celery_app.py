from celery import Celery
from ...core.config import settings
celery_app=Celery('rtcrackers',broker=settings.CELERY_BROKER_URL,backend=settings.CELERY_RESULT_BACKEND)
celery_app.conf.update(task_serializer='json',accept_content=['json'],result_serializer='json',timezone='Asia/Kolkata',enable_utc=True,task_acks_late=True,worker_prefetch_multiplier=1,beat_schedule={'refresh-analytics':{'task':'BACKGROUND_JOBS.tasks.refresh_analytics','schedule':900},'process-coupon-expiry':{'task':'BACKGROUND_JOBS.tasks.process_coupon_expiry','schedule':3600},'inventory-alerts':{'task':'BACKGROUND_JOBS.tasks.inventory_alerts','schedule':1800}})
