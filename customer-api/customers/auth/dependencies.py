"""Authentication dependencies shared by every router."""
from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from core.constants import USER_ACTIVE
from core.database import get_db
from core.exceptions import ForbiddenError, UnauthorizedError
from core.security import TOKEN_ACCESS, decode_jwt
from customers.auth.models import User, UserSession
from customers.auth.service import RequestMeta
from utils.helpers import client_ip, user_agent, utcnow

bearer_scheme = HTTPBearer(auto_error=False, description="JWT access token")


@dataclass
class Principal:
    user: User
    session_id: uuid.UUID


async def _resolve(credentials: HTTPAuthorizationCredentials | None, db: AsyncSession) -> Principal:
    if credentials is None:
        raise UnauthorizedError()
    payload = decode_jwt(credentials.credentials, TOKEN_ACCESS)
    session_id = uuid.UUID(payload["sid"])
    row = await db.get(UserSession, session_id)
    if row is None or row.ended_at is not None or row.expires_at <= utcnow():
        raise UnauthorizedError("Session has ended, please log in again", code="session_expired")
    user = await db.get(User, int(payload["sub"]))
    if user is None or user.status == "D":
        raise UnauthorizedError("Account not found", code="invalid_token")
    if user.status != USER_ACTIVE:
        raise ForbiddenError("Your account is not active", code="account_disabled")
    return Principal(user=user, session_id=session_id)


async def get_principal(request: Request, credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
                        db: AsyncSession = Depends(get_db)) -> Principal:
    if credentials is None:
        token = request.cookies.get("rtc_access_token")
        if token:
            credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
    return await _resolve(credentials, db)


async def get_current_user(principal: Principal = Depends(get_principal)) -> User:
    return principal.user


async def get_optional_user(request: Request, credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
                            db: AsyncSession = Depends(get_db)) -> User | None:
    """Returns the user when a valid bearer or HttpOnly cookie token is supplied."""
    if credentials is None:
        token = request.cookies.get("rtc_access_token")
        if token:
            credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        else:
            return None
    return (await _resolve(credentials, db)).user


async def get_verified_user(user: User = Depends(get_current_user)) -> User:
    if not user.email_verified:
        raise ForbiddenError("Please verify your email address first", code="email_not_verified")
    return user


def get_request_meta(request: Request) -> RequestMeta:
    return RequestMeta(ip=client_ip(request), user_agent=user_agent(request))


CurrentUser = Annotated[User, Depends(get_current_user)]
OptionalUser = Annotated[User | None, Depends(get_optional_user)]
