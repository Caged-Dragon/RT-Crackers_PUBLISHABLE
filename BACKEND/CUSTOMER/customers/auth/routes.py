from __future__ import annotations
from fastapi import APIRouter, Depends, Request, Response, status
from core.config import settings
from core.exceptions import UnauthorizedError
from core.schemas import MessageResponse
from customers.auth.dependencies import CurrentUser, Principal, get_principal, get_request_meta
from customers.auth.schemas import (
    AuthResponse, ForgotPasswordRequest, LoginRequest, LogoutRequest, OtpSentResponse, RefreshRequest, RegisterRequest,
    ResetPasswordRequest, TokenPair, VerifyEmailRequest, VerifyOtpRequest,
)
from customers.auth.service import AuthService, RequestMeta, get_auth_service

router = APIRouter(prefix="/auth", tags=["Authentication"])

def _cookie_kwargs():
    return {
        "httponly": True,
        "secure": settings.AUTH_COOKIE_SECURE,
        "samesite": settings.AUTH_COOKIE_SAMESITE,
        "domain": settings.AUTH_COOKIE_DOMAIN,
        "path": "/",
    }

def _set_auth_cookies(response: Response, access: str, refresh: str) -> None:
    kw = _cookie_kwargs()
    response.set_cookie("rtc_access_token", access, max_age=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60, **kw)
    response.set_cookie("rtc_refresh_token", refresh, max_age=settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400, **kw)

def _clear_auth_cookies(response: Response) -> None:
    response.delete_cookie("rtc_access_token", domain=settings.AUTH_COOKIE_DOMAIN, path="/")
    response.delete_cookie("rtc_refresh_token", domain=settings.AUTH_COOKIE_DOMAIN, path="/")

@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest, response: Response, service: AuthService = Depends(get_auth_service), meta: RequestMeta = Depends(get_request_meta)):
    result = await service.register(body, meta)
    _set_auth_cookies(response, result.tokens.access_token, result.tokens.refresh_token)
    return result

@router.post("/login", response_model=AuthResponse)
async def login(body: LoginRequest, response: Response, service: AuthService = Depends(get_auth_service), meta: RequestMeta = Depends(get_request_meta)):
    result = await service.login(body.email, body.password, meta)
    _set_auth_cookies(response, result.tokens.access_token, result.tokens.refresh_token)
    return result

@router.post("/refresh", response_model=TokenPair)
async def refresh(body: RefreshRequest | None, request: Request, response: Response, service: AuthService = Depends(get_auth_service)):
    raw = body.refresh_token if body else request.cookies.get("rtc_refresh_token")
    if not raw:
        raise UnauthorizedError("Refresh token is required", code="refresh_required")
    result = await service.refresh(raw)
    _set_auth_cookies(response, result.access_token, result.refresh_token)
    return result

@router.post("/logout", response_model=MessageResponse)
async def logout(body: LogoutRequest | None, response: Response, principal: Principal = Depends(get_principal), service: AuthService = Depends(get_auth_service)):
    await service.logout(principal.user.user_id, principal.session_id, bool(body and body.all_devices))
    _clear_auth_cookies(response)
    return MessageResponse(message="Logged out")

@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(body: ForgotPasswordRequest, service: AuthService = Depends(get_auth_service), meta: RequestMeta = Depends(get_request_meta)):
    await service.forgot_password(body.email, meta)
    return MessageResponse(message="If that email is registered, a reset link has been sent")

@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(body: ResetPasswordRequest, service: AuthService = Depends(get_auth_service)):
    await service.reset_password(body.token, body.new_password)
    return MessageResponse(message="Password updated. Please log in with your new password")

@router.post("/verify-email", response_model=MessageResponse)
async def verify_email(body: VerifyEmailRequest, service: AuthService = Depends(get_auth_service)):
    await service.verify_email(body.token)
    return MessageResponse(message="Email verified")

@router.post("/resend-verification", response_model=MessageResponse)
async def resend_verification(user: CurrentUser, service: AuthService = Depends(get_auth_service)):
    await service.resend_verification(user)
    return MessageResponse(message="Verification email sent")

@router.post("/otp/send", response_model=OtpSentResponse)
async def send_otp(user: CurrentUser, service: AuthService = Depends(get_auth_service)):
    return await service.send_phone_otp(user)

@router.post("/otp/verify", response_model=MessageResponse)
async def verify_otp(body: VerifyOtpRequest, user: CurrentUser, service: AuthService = Depends(get_auth_service)):
    await service.verify_phone_otp(user, body.code)
    return MessageResponse(message="Phone number verified")
