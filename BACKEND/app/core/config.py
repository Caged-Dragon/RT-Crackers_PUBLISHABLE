from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field
from typing import Literal

class Settings(BaseSettings):
    model_config=SettingsConfigDict(env_file='.env',extra='ignore',case_sensitive=False)
    APP_NAME:str='RTCrackers Platform API'; APP_VERSION:str='2.0.0'
    ENVIRONMENT:Literal['development','test','staging','production']='development'; DEBUG:bool=False
    DATABASE_URL:str=Field(...); JWT_SECRET_KEY:str=Field(...,min_length=32); JWT_ALGORITHM:str='HS256'
    ACCESS_TOKEN_EXPIRE_MINUTES:int=30; API_V1_PREFIX:str='/api/v1'; CORS_ORIGINS:str='https://www.rtcrackers.com'
    REDIS_URL:str='redis://redis:6379/0'; CELERY_BROKER_URL:str='redis://redis:6379/1'; CELERY_RESULT_BACKEND:str='redis://redis:6379/2'
    EMAIL_BACKEND:Literal['smtp','console']='console'; SMTP_HOST:str='localhost'; SMTP_PORT:int=587; SMTP_USERNAME:str=''; SMTP_PASSWORD:str=''; SMTP_USE_TLS:bool=True; EMAIL_FROM:str='no-reply@rtcrackers.com'; RESEND_API_KEY:str=''; RESEND_FROM_NAME:str='RTC Crackers'; EMAIL_WEBHOOK_SECRET:str=''
    SMS_BACKEND:Literal['twilio','console']='console'; TWILIO_ACCOUNT_SID:str=''; TWILIO_AUTH_TOKEN:str=''; TWILIO_FROM_NUMBER:str=''
    WHATSAPP_BACKEND:Literal['twilio','console']='console'; WHATSAPP_FROM:str=''
    STORAGE_BACKEND:Literal['local','s3']='local'; LOCAL_STORAGE_DIR:str='media'; STORAGE_PUBLIC_BASE_URL:str='/media'
    AWS_S3_ENDPOINT_URL:str=''; AWS_ACCESS_KEY_ID:str=''; AWS_SECRET_ACCESS_KEY:str=''; AWS_REGION:str='ap-south-1'; AWS_S3_BUCKET:str='rtcrackers-media'
    GSTIN:str=''; STORE_NAME:str='RT Crackers'; STORE_EMAIL:str='support@rtcrackers.com'; STORE_PHONE:str=''; STORE_ADDRESS:str='Sivakasi, Tamil Nadu, India'; STORE_STATE_CODE:str='33'
    FREE_SHIPPING_THRESHOLD:int=2000; DEFAULT_GST_PERCENTAGE:float=18.0
    RATE_LIMIT_PER_MINUTE:int=240; AUTH_RATE_LIMIT_PER_MINUTE:int=20
    LOG_LEVEL:str='INFO'; LOG_JSON:bool=True
    SENTRY_DSN:str=''; OTEL_EXPORTER_OTLP_ENDPOINT:str=''
settings=Settings()
