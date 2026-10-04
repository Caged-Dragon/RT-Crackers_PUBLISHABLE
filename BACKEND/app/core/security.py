from __future__ import annotations

from datetime import datetime, timedelta, timezone
import uuid
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import text

from .config import settings
from .database import get_db

pwd = CryptContext(schemes=["argon2", "bcrypt"], deprecated="auto")
bearer = HTTPBearer(auto_error=False)

CUSTOMER_ACCESS = "access"
ADMIN_ACCESS = "admin_access"


def hash_password(value: str) -> str:
    return pwd.hash(value)


def verify_password(value: str, password_hash: str) -> bool:
    return pwd.verify(value, password_hash)


def create_access_token(subject: int, claims: dict[str, Any] | None = None) -> str:
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": str(subject),
        "type": CUSTOMER_ACCESS,
        "iat": now,
        "exp": now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        "jti": str(uuid.uuid4()),
    }
    payload.update(claims or {})
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except JWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc


async def _revoked(db, jti: str | None) -> bool:
    if not jti:
        return False
    row = (
        await db.execute(
            text("SELECT 1 FROM rtc_revoked_tokens WHERE jti=:j AND expires_at > CURRENT_TIMESTAMP"),
            {"j": jti},
        )
    ).first()
    return row is not None


async def current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db=Depends(get_db),
):
    if not credentials:
        raise HTTPException(401, "Authentication required")
    payload = decode_token(credentials.credentials)
    if await _revoked(db, payload.get("jti")):
        raise HTTPException(401, "Token revoked")

    uid = payload.get("sub")
    token_type = payload.get("type")
    sid = payload.get("sid")
    if not uid:
        raise HTTPException(401, "Invalid token")

    try:
        uid_int = int(uid)
    except (TypeError, ValueError) as exc:
        raise HTTPException(401, "Invalid token subject") from exc

    if sid:
        session = (
            await db.execute(
                text("SELECT ended_at, expires_at FROM sessions WHERE session_id=:sid"),
                {"sid": sid},
            )
        ).mappings().first()
        if session and (session["ended_at"] is not None or session["expires_at"] <= datetime.utcnow()):
            raise HTTPException(401, "Session expired")

    if token_type == ADMIN_ACCESS:
        row = (
            await db.execute(
                text(
                    """
                    SELECT u.user_id, u.email, u.first_name, u.last_name, u.status,
                           a.admin_id, a.status AS admin_status
                    FROM admins a JOIN users u ON u.user_id=a.user_id
                    WHERE a.admin_id=:id
                    """
                ),
                {"id": uid_int},
            )
        ).mappings().first()
        if not row or row["status"] != "A" or row["admin_status"] != "A":
            raise HTTPException(401, "Admin inactive")
        return {**dict(row), "actor_type": "admin", "user_id": row["user_id"]}

    if token_type != CUSTOMER_ACCESS:
        raise HTTPException(401, "Invalid token type")

    row = (
        await db.execute(
            text("SELECT user_id,email,first_name,last_name,status FROM users WHERE user_id=:id"),
            {"id": uid_int},
        )
    ).mappings().first()
    if not row or row["status"] != "A":
        raise HTTPException(401, "User inactive")
    return {**dict(row), "actor_type": "customer"}


def require_roles(*roles: str):
    async def dependency(
        credentials: HTTPAuthorizationCredentials = Depends(bearer),
        db=Depends(get_db),
    ):
        actor = await current_user(credentials, db)
        if not roles:
            return actor
        if actor.get("actor_type") != "admin":
            raise HTTPException(403, "Insufficient privileges")
        if "ADMIN" in roles or "A" in roles:
            return actor
        role_rows = (
            await db.execute(
                text(
                    """
                    SELECT r.role_code, r.role_name
                    FROM admin_roles ar
                    JOIN roles r ON r.role_id=ar.role_id
                    WHERE ar.admin_id=:admin_id AND r.is_active=true
                    """
                ),
                {"admin_id": actor["admin_id"]},
            )
        ).mappings().all()
        allowed = {str(r["role_code"]) for r in role_rows} | {str(r["role_name"]) for r in role_rows}
        if not allowed.intersection(roles):
            raise HTTPException(403, "Insufficient privileges")
        return actor

    return dependency
