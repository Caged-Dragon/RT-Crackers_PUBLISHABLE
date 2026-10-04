from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession
from core.config import settings
from core.database import get_db
from core.exceptions import UnauthorizedError
from core.security import hash_token
from ADMINS.auth.schemas import *
from ADMINS.auth.service import AuthService
from ADMINS.auth.dependencies import get_current_admin

router = APIRouter(prefix='/auth', tags=['Admin Authentication'])

def _cookie_kwargs():
    return {
        'httponly': True,
        'secure': settings.AUTH_COOKIE_SECURE,
        'samesite': settings.AUTH_COOKIE_SAMESITE,
        'domain': settings.AUTH_COOKIE_DOMAIN,
        'path': '/',
    }

def _set_auth_cookies(response: Response, access: str, refresh: str, expires_in: int):
    kw = _cookie_kwargs()
    response.set_cookie('rtc_admin_access_token', access, max_age=expires_in, **kw)
    response.set_cookie('rtc_admin_refresh_token', refresh, max_age=settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400, **kw)

def _clear_auth_cookies(response: Response):
    response.delete_cookie('rtc_admin_access_token', domain=settings.AUTH_COOKIE_DOMAIN, path='/')
    response.delete_cookie('rtc_admin_refresh_token', domain=settings.AUTH_COOKIE_DOMAIN, path='/')

@router.post('/login', response_model=TokenPair)
async def login(p: LoginRequest, response: Response, request: Request, db: AsyncSession = Depends(get_db)):
    access, refresh_token, expires_at = await AuthService(db).login(
        p.email, p.password,
        request.client.host if request.client else None,
        request.headers.get('user-agent'),
    )
    expires_in = max(1, int((expires_at - datetime.now(timezone.utc)).total_seconds()))
    _set_auth_cookies(response, access, refresh_token, expires_in)
    return TokenPair(access_token=access, refresh_token=refresh_token, expires_in=expires_in)

@router.post('/refresh', response_model=TokenPair)
async def refresh(p: RefreshRequest | None, request: Request, response: Response, db: AsyncSession = Depends(get_db)):
    raw = p.refresh_token if p else request.cookies.get('rtc_admin_refresh_token')
    if not raw:
        raise UnauthorizedError('Refresh token is required', code='refresh_required')
    access, refresh_token, expires_at = await AuthService(db).refresh(raw)
    expires_in = max(1, int((expires_at - datetime.now(timezone.utc)).total_seconds()))
    _set_auth_cookies(response, access, refresh_token, expires_in)
    return TokenPair(access_token=access, refresh_token=refresh_token, expires_in=expires_in)

@router.post('/logout', response_model=Message)
async def logout(p: RefreshRequest | None, request: Request, response: Response, db: AsyncSession = Depends(get_db), admin=Depends(get_current_admin)):
    raw = p.refresh_token if p else request.cookies.get('rtc_admin_refresh_token')
    if raw:
        await AuthService(db).r.revoke_refresh(hash_token(raw))
        await db.commit()
    _clear_auth_cookies(response)
    return Message(message='Logged out')

@router.post('/change-password', response_model=Message)
async def change(p: ChangePasswordRequest, db: AsyncSession = Depends(get_db), admin=Depends(get_current_admin)):
    await AuthService(db).change_password(admin.admin_id, p.current_password, p.new_password)
    return Message(message='Password changed')

@router.post('/forgot-password', response_model=Message)
async def forgot(p: ForgotPasswordRequest, request: Request, db: AsyncSession = Depends(get_db)):
    await AuthService(db).forgot(p.email, request.client.host if request.client else None)
    return Message(message='If the account exists, password reset instructions will be sent to the registered email.')

@router.post('/reset-password', response_model=Message)
async def reset(p: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    await AuthService(db).reset(p.token, p.new_password)
    return Message(message='Password reset successfully')
