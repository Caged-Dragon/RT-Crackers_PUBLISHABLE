"""Application configuration.

Every value comes from environment variables (or a local ``.env`` file).
The database is Supabase PostgreSQL: set ``DATABASE_URL`` to the connection
string from *Supabase Dashboard -> Project Settings -> Database*.
"""
from __future__ import annotations

import ssl
import uuid
from functools import lru_cache
from typing import Any, Literal

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url

# Query-string keys that are meaningful to libpq/Supabase tooling but not to the drivers.
_STRIP_QUERY_KEYS = {"sslmode", "pgbouncer", "supa", "connect_timeout", "options"}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore", case_sensitive=False
    )

    # ------------------------------------------------------------------ app
    APP_NAME: str = "RTCrackers API"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: Literal["development", "test", "staging", "production"] = "development"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"
    FRONTEND_URL: str = "https://www.rtcrackers.com"
    CORS_ORIGINS: str = "https://www.rtcrackers.com"
    AUTH_COOKIE_DOMAIN: str | None = None
    AUTH_COOKIE_SECURE: bool = True
    AUTH_COOKIE_SAMESITE: Literal["lax", "strict", "none"] = "lax"
    LOG_LEVEL: str = "INFO"
    LOG_JSON: bool = False

    # ------------------------------------------------------------- database
    DATABASE_URL: str = Field(..., description="Supabase Postgres connection string")
    MIGRATION_DATABASE_URL: str | None = None
    DB_SSL_MODE: Literal["disable", "require", "verify-full"] = "verify-full"
    DB_SSL_CA_FILE: str | None = None
    DB_PGBOUNCER: bool | None = None  # None = auto-detect Supabase pooler
    DB_NULL_POOL: bool = False
    DB_POOL_SIZE: int = 5
    DB_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30
    DB_POOL_RECYCLE: int = 1800
    DB_CONNECT_TIMEOUT: int = 15
    DB_COMMAND_TIMEOUT: int = 60
    DB_ECHO: bool = False

    # ------------------------------------------------------------------ JWT
    JWT_SECRET_KEY: str = Field(..., min_length=32)
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 14
    CART_TOKEN_EXPIRE_DAYS: int = 30
    EMAIL_VERIFY_EXPIRE_HOURS: int = 48
    PASSWORD_RESET_EXPIRE_MINUTES: int = 30

    # ------------------------------------------------------- auth behaviour
    MAX_FAILED_LOGINS: int = 5
    OTP_LENGTH: int = 6
    OTP_EXPIRE_MINUTES: int = 10
    OTP_MAX_ATTEMPTS: int = 5
    OTP_RESEND_SECONDS: int = 60

    # ------------------------------------------------------- Supabase storage
    STORAGE_BACKEND: Literal["local", "supabase"] = "local"
    SUPABASE_URL: str | None = None
    SUPABASE_SERVICE_ROLE_KEY: str | None = None
    SUPABASE_STORAGE_BUCKET: str = "rtcrackers-media"
    LOCAL_MEDIA_DIR: str = "media"
    MEDIA_URL_PREFIX: str = "/media"
    MAX_UPLOAD_MB: int = 5

    # --------------------------------------------------------------- e-mail
    EMAIL_BACKEND: Literal["smtp", "console", "memory"] = "console"
    SMTP_HOST: str = "localhost"
    SMTP_PORT: int = 587
    SMTP_USERNAME: str | None = None
    SMTP_PASSWORD: str | None = None
    SMTP_USE_TLS: bool = False
    SMTP_START_TLS: bool = True
    EMAIL_FROM: str = "RT Crackers <no-reply@rtcrackers.com>"

    # ------------------------------------------------------------------ SMS
    SMS_BACKEND: Literal["twilio", "console", "memory"] = "console"
    TWILIO_ACCOUNT_SID: str | None = None
    TWILIO_AUTH_TOKEN: str | None = None
    TWILIO_FROM_NUMBER: str | None = None
    SMS_DEFAULT_COUNTRY_CODE: str = "+91"

    # ----------------------------------------------------------- rate limit
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_PER_MINUTE: int = 240
    RATE_LIMIT_AUTH_PER_MINUTE: int = 20

    # ----------------------------------------------------------- business
    STORE_NAME: str = "RTCrackers"
    STORE_ADDRESS: str = "Sivakasi, Tamil Nadu, India"
    STORE_GSTIN: str = ""
    STORE_PHONE: str = ""
    STORE_EMAIL: str = "support@rtcrackers.com"
    ORDER_ADMIN_EMAILS: str = "support@rtcrackers.com"  # comma-separated recipients for new-order alerts
    STORE_STATE: str = "Tamil Nadu"
    DEFAULT_MIN_ORDER_AMOUNT: int = 500
    REFERRAL_REFERRER_REWARD: int = 100
    REFERRAL_REFEREE_REWARD: int = 50
    REFERRAL_REWARD_VALID_DAYS: int = 90

    # ------------------------------------------------------------ validators
    @model_validator(mode="after")
    def _validate(self) -> "Settings":
        if self.JWT_ALGORITHM not in {"HS256", "HS384", "HS512"}:
            raise ValueError("JWT_ALGORITHM must be an approved HMAC algorithm")
        if self.AUTH_COOKIE_SAMESITE == "none" and not self.AUTH_COOKIE_SECURE:
            raise ValueError("AUTH_COOKIE_SECURE must be true when SameSite=None")
        origins = self.cors_origin_list
        if self.ENVIRONMENT in ("staging", "production"):
            if self.DB_SSL_MODE == "disable":
                raise ValueError("DB_SSL_MODE=disable is not permitted in production/staging")
            weak = {"change-me", "secret", "changeme", "replace_me"}
            if len(self.JWT_SECRET_KEY) < 48 or any(w in self.JWT_SECRET_KEY.lower() for w in weak):
                raise ValueError("JWT_SECRET_KEY must be a strong random value (48+ chars) in production")
            if self.DEBUG:
                raise ValueError("DEBUG must be false in staging/production")
            if not origins or "*" in origins:
                raise ValueError("CORS_ORIGINS must contain explicit HTTPS origins in production")
            if not all(o.startswith("https://") for o in origins):
                raise ValueError("Production CORS_ORIGINS must use HTTPS")
            if not self.AUTH_COOKIE_SECURE:
                raise ValueError("AUTH_COOKIE_SECURE must be true in production")
        if self.STORAGE_BACKEND == "supabase" and not (self.SUPABASE_URL and self.SUPABASE_SERVICE_ROLE_KEY):
            raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required when STORAGE_BACKEND=supabase")
        return self

    # ------------------------------------------------------------ helpers
    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

    @property
    def uses_pgbouncer(self) -> bool:
        """True when talking to a transaction-mode pooler (Supabase port 6543)."""
        if self.DB_PGBOUNCER is not None:
            return self.DB_PGBOUNCER
        url = make_url(self.DATABASE_URL)
        host = (url.host or "").lower()
        return url.port == 6543 or "pooler.supabase" in host or url.query.get("pgbouncer") == "true"

    @staticmethod
    def _clean_query(url: URL) -> URL:
        keep = {k: v for k, v in url.query.items() if k.lower() not in _STRIP_QUERY_KEYS}
        return url.set(query=keep)

    @property
    def async_database_url(self) -> URL:
        url = make_url(self.DATABASE_URL).set(drivername="postgresql+asyncpg")
        return self._clean_query(url)

    @property
    def sync_database_url(self) -> URL:
        """URL used by Alembic (psycopg 3). Prefer MIGRATION_DATABASE_URL (direct / session-mode)."""
        raw = self.MIGRATION_DATABASE_URL or self.DATABASE_URL
        url = self._clean_query(make_url(raw).set(drivername="postgresql+psycopg"))
        return url.update_query_dict({"sslmode": self.DB_SSL_MODE})

    def asyncpg_connect_args(self) -> dict[str, Any]:
        args: dict[str, Any] = {
            "timeout": self.DB_CONNECT_TIMEOUT,
            "command_timeout": self.DB_COMMAND_TIMEOUT,
        }
        if self.DB_SSL_MODE != "disable":
            ctx = ssl.create_default_context(cafile=self.DB_SSL_CA_FILE) if self.DB_SSL_CA_FILE else ssl.create_default_context()
            if self.DB_SSL_MODE == "require":  # encrypt, don't verify (same as libpq sslmode=require)
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
            args["ssl"] = ctx
        if self.uses_pgbouncer:
            # PgBouncer in transaction mode cannot keep server-side prepared statements.
            args["statement_cache_size"] = 0
            args["prepared_statement_cache_size"] = 0
            args["prepared_statement_name_func"] = lambda: f"__asyncpg_{uuid.uuid4()}__"
        return args


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]


settings = get_settings()
