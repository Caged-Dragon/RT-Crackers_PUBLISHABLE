from __future__ import annotations
from functools import lru_cache
from typing import Literal, Any
import ssl, uuid
from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url

_STRIP_QUERY_KEYS={"sslmode","pgbouncer","supa","connect_timeout","options"}
class Settings(BaseSettings):
    model_config=SettingsConfigDict(env_file='.env',env_file_encoding='utf-8',extra='ignore',case_sensitive=False)
    APP_NAME:str='RTCrackers Admin API'; APP_VERSION:str='1.0.0'; ENVIRONMENT:Literal['development','test','staging','production']='development'; DEBUG:bool=False
    API_V1_PREFIX:str='/api/v1/admin'; FRONTEND_URL:str='https://www.rtcrackers.com/admin'; CORS_ORIGINS:str='https://www.rtcrackers.com'; LOG_LEVEL:str='INFO'; LOG_JSON:bool=False
    AUTH_COOKIE_DOMAIN:str|None=None; AUTH_COOKIE_SECURE:bool=True; AUTH_COOKIE_SAMESITE:Literal['lax','strict','none']='lax'
    DATABASE_URL:str=Field(...); MIGRATION_DATABASE_URL:str|None=None; DB_SSL_MODE:Literal['disable','require','verify-full']='require'; DB_SSL_CA_FILE:str|None=None
    DB_PGBOUNCER:bool|None=None; DB_NULL_POOL:bool=False; DB_POOL_SIZE:int=5; DB_MAX_OVERFLOW:int=10; DB_POOL_TIMEOUT:int=30; DB_POOL_RECYCLE:int=1800; DB_CONNECT_TIMEOUT:int=15; DB_COMMAND_TIMEOUT:int=60; DB_ECHO:bool=False
    JWT_SECRET_KEY:str=Field(...,min_length=32); JWT_ALGORITHM:str='HS256'; ACCESS_TOKEN_EXPIRE_MINUTES:int=30; REFRESH_TOKEN_EXPIRE_DAYS:int=14; PASSWORD_RESET_EXPIRE_MINUTES:int=30
    MAX_FAILED_LOGINS:int=5; RATE_LIMIT_ENABLED:bool=True; RATE_LIMIT_PER_MINUTE:int=240; RATE_LIMIT_AUTH_PER_MINUTE:int=20
    EMAIL_BACKEND:Literal['smtp','console','memory']='console'; SMTP_HOST:str='localhost'; SMTP_PORT:int=587; SMTP_USERNAME:str|None=None; SMTP_PASSWORD:str|None=None; SMTP_USE_TLS:bool=False; SMTP_START_TLS:bool=True; EMAIL_FROM:str='RT Crackers <no-reply@rtcrackers.com>'
    ADMIN_FRONTEND_RESET_URL:str='https://www.rtcrackers.com/admin/reset-password';
    STORE_NAME:str='RT Crackers'; STORE_GSTIN:str=''; STORE_PHONE:str=''; STORE_EMAIL:str='support@rtcrackers.com'
    @model_validator(mode='after')
    def validate_prod(self):
        if self.JWT_ALGORITHM not in {'HS256','HS384','HS512'}:
            raise ValueError('JWT_ALGORITHM must be an approved HMAC algorithm')
        if self.AUTH_COOKIE_SAMESITE == 'none' and not self.AUTH_COOKIE_SECURE:
            raise ValueError('AUTH_COOKIE_SECURE must be true when SameSite=None')
        if self.ENVIRONMENT in ('production','staging'):
            if self.DB_SSL_MODE == 'disable': raise ValueError('DB_SSL_MODE=disable is not permitted in production/staging')
            if self.DEBUG: raise ValueError('DEBUG must be false in production/staging')
            if len(self.JWT_SECRET_KEY) < 48 or self.JWT_SECRET_KEY.lower() in {'change-me','changeme','secret','replace_me'}:
                raise ValueError('Use a strong 48+ character JWT_SECRET_KEY')
            if '*' in self.cors_origin_list or not self.cors_origin_list or not all(x.startswith('https://') for x in self.cors_origin_list):
                raise ValueError('Production CORS_ORIGINS must contain explicit HTTPS origins')
            if not self.AUTH_COOKIE_SECURE: raise ValueError('AUTH_COOKIE_SECURE must be true in production')
        return self
    @property
    def cors_origin_list(self): return [x.strip() for x in self.CORS_ORIGINS.split(',') if x.strip()]
    @property
    def uses_pgbouncer(self):
        if self.DB_PGBOUNCER is not None:return self.DB_PGBOUNCER
        u=make_url(self.DATABASE_URL); return u.port==6543 or 'pooler.supabase' in (u.host or '').lower() or u.query.get('pgbouncer')=='true'
    @staticmethod
    def _clean_query(url:URL): return url.set(query={k:v for k,v in url.query.items() if k.lower() not in _STRIP_QUERY_KEYS})
    @property
    def async_database_url(self): return self._clean_query(make_url(self.DATABASE_URL).set(drivername='postgresql+asyncpg'))
    @property
    def sync_database_url(self):
        raw=self.MIGRATION_DATABASE_URL or self.DATABASE_URL
        return self._clean_query(make_url(raw).set(drivername='postgresql+psycopg')).update_query_dict({'sslmode':self.DB_SSL_MODE})
    def asyncpg_connect_args(self)->dict[str,Any]:
        a={'timeout':self.DB_CONNECT_TIMEOUT,'command_timeout':self.DB_COMMAND_TIMEOUT}
        if self.DB_SSL_MODE!='disable':
            c=ssl.create_default_context(cafile=self.DB_SSL_CA_FILE) if self.DB_SSL_CA_FILE else ssl.create_default_context()
            if self.DB_SSL_MODE=='require':
                # Compatibility mode: verify the certificate chain but do not require hostname validation.
                # Production deployments should prefer verify-full.
                c.check_hostname=False
                c.verify_mode=ssl.CERT_REQUIRED
            a['ssl']=c
        if self.uses_pgbouncer:
            a.update(statement_cache_size=0,prepared_statement_cache_size=0,prepared_statement_name_func=lambda:f'__asyncpg_{uuid.uuid4()}__')
        return a
@lru_cache
def get_settings(): return Settings()
settings=get_settings()
