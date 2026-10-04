"""Application exceptions and FastAPI exception handlers."""
from __future__ import annotations

import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import DBAPIError, IntegrityError
from starlette.exceptions import HTTPException as StarletteHTTPException

from core.config import settings
from middleware.request_id import get_request_id

logger = logging.getLogger("rtcrackers.errors")


class AppException(Exception):
    status_code = 500
    code = "internal_error"

    def __init__(self, message: str = "Something went wrong", *, code: str | None = None, details: Any = None,
                 headers: dict[str, str] | None = None):
        super().__init__(message)
        self.message = message
        self.code = code or self.code
        self.details = details
        self.headers = headers


class BadRequestError(AppException):
    status_code, code = 400, "bad_request"


class UnauthorizedError(AppException):
    status_code, code = 401, "unauthorized"

    def __init__(self, message: str = "Authentication required", **kw: Any):
        kw.setdefault("headers", {"WWW-Authenticate": "Bearer"})
        super().__init__(message, **kw)


class ForbiddenError(AppException):
    status_code, code = 403, "forbidden"


class NotFoundError(AppException):
    status_code, code = 404, "not_found"


class ConflictError(AppException):
    status_code, code = 409, "conflict"


class UnprocessableError(AppException):
    status_code, code = 422, "unprocessable"


class TooManyRequestsError(AppException):
    status_code, code = 429, "too_many_requests"


class ServiceUnavailableError(AppException):
    status_code, code = 503, "service_unavailable"


def error_body(code: str, message: str, details: Any = None) -> dict[str, Any]:
    body: dict[str, Any] = {"error": {"code": code, "message": message}, "request_id": get_request_id()}
    if details is not None:
        body["error"]["details"] = details
    return body


# Postgres constraint names -> friendly messages (names come from the schema file).
_CONSTRAINT_MESSAGES = {
    "uq_users_email": "An account with this email already exists",
    "uq_users_phone": "An account with this phone number already exists",
    "ck_inventory_on_hand": "Insufficient stock for one or more items",
    "ck_inventory_reserved": "Insufficient stock for one or more items",
    "uq_reviews_product_user": "You have already reviewed this product",
    "uq_review_reports_review_user": "You have already reported this review",
    "uq_addresses_one_default_per_user": "A default address already exists",
    "uq_cart_items_line": "Item already exists in the cart",
}


def friendly_integrity_message(exc: IntegrityError) -> str:
    text = str(getattr(exc, "orig", exc))
    for name, message in _CONSTRAINT_MESSAGES.items():
        if name in text:
            return message
    return "The request conflicts with existing data"


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppException)
    async def _app_exc(_: Request, exc: AppException) -> JSONResponse:
        if exc.status_code >= 500:
            logger.error("AppException %s: %s", exc.code, exc.message)
        return JSONResponse(error_body(exc.code, exc.message, exc.details), status_code=exc.status_code, headers=exc.headers)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        details = [
            {"field": ".".join(str(p) for p in e["loc"] if p != "body"), "message": e["msg"], "type": e["type"]}
            for e in exc.errors()
        ]
        return JSONResponse(error_body("validation_error", "Request validation failed", details), status_code=422)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        code = {404: "not_found", 405: "method_not_allowed", 401: "unauthorized", 403: "forbidden"}.get(exc.status_code, "http_error")
        return JSONResponse(error_body(code, str(exc.detail)), status_code=exc.status_code, headers=getattr(exc, "headers", None))

    @app.exception_handler(IntegrityError)
    async def _integrity(_: Request, exc: IntegrityError) -> JSONResponse:
        logger.warning("Integrity error: %s", exc.orig)
        return JSONResponse(error_body("conflict", friendly_integrity_message(exc)), status_code=409)

    @app.exception_handler(DBAPIError)
    async def _dbapi(_: Request, exc: DBAPIError) -> JSONResponse:
        logger.exception("Database error")
        return JSONResponse(error_body("database_error", "A database error occurred"), status_code=503 if exc.connection_invalidated else 500)

    @app.exception_handler(Exception)
    async def _unhandled(_: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled exception")
        message = str(exc) if settings.DEBUG else "Internal server error"
        return JSONResponse(error_body("internal_error", message), status_code=500)
