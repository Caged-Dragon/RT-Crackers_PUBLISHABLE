from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict
from app.core.config import settings as platform_settings


class EmailSettings(BaseSettings):
    database_url: str = platform_settings.DATABASE_URL
    resend_api_key: str = platform_settings.RESEND_API_KEY
    resend_from_name: str = platform_settings.RESEND_FROM_NAME
    email_webhook_secret: str | None = platform_settings.EMAIL_WEBHOOK_SECRET

    model_config = SettingsConfigDict(extra="ignore")


@lru_cache
def get_settings() -> EmailSettings:
    return EmailSettings()
