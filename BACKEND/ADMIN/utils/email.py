"""E-mail delivery (SMTP / console / in-memory) and built-in templates.

Templates stored in the `email_templates` table (matched by template_code) take priority;
the built-in templates below are the fallback so a fresh database works out of the box.
"""
from __future__ import annotations

import html
import logging
from dataclasses import dataclass
from email.message import EmailMessage
from typing import Any


from core.config import settings

logger = logging.getLogger("rtcrackers.email")


@dataclass
class SentEmail:
    to: str
    subject: str
    html: str
    text: str


OUTBOX: list[SentEmail] = []  # populated when EMAIL_BACKEND=memory (used by the test-suite)


class _SafeDict(dict):
    def __missing__(self, key: str) -> str:
        return ""


def render(template: str, context: dict[str, Any], escape: bool = True) -> str:
    safe = _SafeDict({k: (html.escape(str(v)) if escape else str(v)) for k, v in context.items()})
    return template.format_map(safe)


_LAYOUT = (
    "<div style='font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px;border:1px solid #eee'>"
    "<h2 style='color:#c0392b;margin-top:0'>{store_name}</h2>{body}"
    "<hr style='border:none;border-top:1px solid #eee;margin:24px 0'>"
    "<p style='color:#888;font-size:12px'>You are receiving this email because of activity on your {store_name} account.</p></div>"
)

BUILTIN_TEMPLATES: dict[str, tuple[str, str]] = {
    "VERIFY_EMAIL": (
        "Verify your email address",
        "<p>Hi {first_name},</p><p>Welcome to {store_name}! Please confirm your email address to secure your account.</p>"
        "<p><a href='{link}' style='background:#c0392b;color:#fff;padding:10px 18px;text-decoration:none;border-radius:4px'>Verify email</a></p>"
        "<p>If the button does not work, open this link: {link}</p>",
    ),
    "PASSWORD_RESET": (
        "Reset your password",
        "<p>Hi {first_name},</p><p>We received a request to reset your password. This link is valid for {minutes} minutes.</p>"
        "<p><a href='{link}' style='background:#c0392b;color:#fff;padding:10px 18px;text-decoration:none;border-radius:4px'>Reset password</a></p>"
        "<p>If you did not request this, you can ignore this email.</p>",
    ),
    "PASSWORD_CHANGED": (
        "Your password was changed",
        "<p>Hi {first_name},</p><p>Your password was just changed. If this was not you, reset your password immediately and contact {support_email}.</p>",
    ),
    "ORDER_PLACED": (
        "Order {order_number} received",
        "<p>Hi {first_name},</p><p>Thank you for your order <b>{order_number}</b>. Total payable on delivery (Cash on Delivery): <b>&#8377;{total}</b>.</p>"
        "<p>Expected delivery: {expected_delivery}.</p>",
    ),
    "ORDER_CANCELLED": (
        "Order {order_number} cancelled",
        "<p>Hi {first_name},</p><p>Your order <b>{order_number}</b> has been cancelled.</p><p>Reason: {reason}</p>",
    ),
    "REFERRAL_REWARD": (
        "Your referral reward is ready",
        "<p>Hi {first_name},</p><p>You earned a reward of &#8377;{amount}. Use coupon code <b>{coupon_code}</b> on your next order (valid until {valid_until}).</p>",
    ),
    "GENERIC": ("{title}", "<p>Hi {first_name},</p><p>{message}</p>"),
}


def build_builtin(template_code: str, context: dict[str, Any]) -> tuple[str, str, str]:
    subject_t, body_t = BUILTIN_TEMPLATES.get(template_code, BUILTIN_TEMPLATES["GENERIC"])
    ctx = {"store_name": settings.STORE_NAME, "support_email": settings.STORE_EMAIL, **context}
    subject = render(subject_t, ctx, escape=False)
    body = render(body_t, ctx)
    full = _LAYOUT.replace("{store_name}", html.escape(settings.STORE_NAME)).replace("{body}", body)
    return subject, full, html_to_text(body)


def html_to_text(value: str) -> str:
    import re
    text = re.sub(r"<br\s*/?>|</p>", "\n", value)
    text = re.sub(r"<[^>]+>", "", text)
    return html.unescape(text).strip()


async def send_email(to: str, subject: str, html_body: str, text_body: str | None = None) -> None:
    text_body = text_body or html_to_text(html_body)
    backend = settings.EMAIL_BACKEND
    if backend == "memory":
        OUTBOX.append(SentEmail(to, subject, html_body, text_body))
        return
    if backend == "console":
        logger.info("EMAIL to=%s subject=%s\n%s", to, subject, text_body)
        return
    try:
        import aiosmtplib
    except ImportError as exc:
        raise RuntimeError("aiosmtplib is required when EMAIL_BACKEND=smtp. Run: pip install -r requirements.txt") from exc
    msg = EmailMessage()
    msg["From"], msg["To"], msg["Subject"] = settings.EMAIL_FROM, to, subject
    msg.set_content(text_body)
    msg.add_alternative(html_body, subtype="html")
    await aiosmtplib.send(
        msg, hostname=settings.SMTP_HOST, port=settings.SMTP_PORT, username=settings.SMTP_USERNAME,
        password=settings.SMTP_PASSWORD, use_tls=settings.SMTP_USE_TLS, start_tls=settings.SMTP_START_TLS, timeout=15,
    )


async def send_template_email(to: str, template_code: str, context: dict[str, Any]) -> None:
    subject, body_html, body_text = build_builtin(template_code, context)
    await send_email(to, subject, body_html, body_text)


async def safe_send_template_email(to: str, template_code: str, context: dict[str, Any]) -> bool:
    """Never raises — used from background tasks so a mail outage cannot fail a request."""
    try:
        await send_template_email(to, template_code, context)
        return True
    except Exception:  # noqa: BLE001
        logger.exception("Failed to send %s email to %s", template_code, to)
        return False
