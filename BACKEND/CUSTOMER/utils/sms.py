"""SMS delivery (Twilio REST / console / in-memory)."""
from __future__ import annotations

import logging
from dataclasses import dataclass

import httpx

from core.config import settings

logger = logging.getLogger("rtcrackers.sms")


@dataclass
class SentSms:
    to: str
    body: str


SMS_OUTBOX: list[SentSms] = []  # populated when SMS_BACKEND=memory


def to_e164(phone: str) -> str:
    return phone if phone.startswith("+") else f"{settings.SMS_DEFAULT_COUNTRY_CODE}{phone}"


async def send_sms(phone: str, body: str) -> None:
    backend = settings.SMS_BACKEND
    if backend == "memory":
        SMS_OUTBOX.append(SentSms(phone, body))
        return
    if backend == "console":
        logger.info("SMS to=%s body=%s", phone, body)
        return
    if not (settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN and settings.TWILIO_FROM_NUMBER):
        raise RuntimeError("Twilio credentials are not configured")
    url = f"https://api.twilio.com/2010-04-01/Accounts/{settings.TWILIO_ACCOUNT_SID}/Messages.json"
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(
            url, auth=(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN),
            data={"To": to_e164(phone), "From": settings.TWILIO_FROM_NUMBER, "Body": body},
        )
    resp.raise_for_status()


async def safe_send_sms(phone: str, body: str) -> bool:
    try:
        await send_sms(phone, body)
        return True
    except Exception:  # noqa: BLE001
        logger.exception("Failed to send SMS to %s", phone)
        return False
