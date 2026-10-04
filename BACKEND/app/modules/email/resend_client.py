from typing import Any
import resend

from .config import get_settings
from .exceptions import EmailProviderError


class ResendEmailClient:
    """Provider adapter. Only this module directly calls the Resend SDK."""

    def __init__(self) -> None:
        settings = get_settings()
        if settings.resend_api_key:
            resend.api_key = settings.resend_api_key

    def send(
        self,
        *,
        from_address: str,
        to: list[str],
        subject: str,
        text: str | None = None,
        html: str | None = None,
        cc: list[str] | None = None,
        bcc: list[str] | None = None,
        reply_to: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "from": from_address,
            "to": to,
            "subject": subject,
        }
        if text:
            payload["text"] = text
        if html:
            payload["html"] = html
        if cc:
            payload["cc"] = cc
        if bcc:
            payload["bcc"] = bcc
        if reply_to:
            payload["reply_to"] = reply_to
        if headers:
            payload["headers"] = headers

        try:
            response = resend.Emails.send(payload)
        except Exception as exc:
            raise EmailProviderError(str(exc)) from exc

        if isinstance(response, dict):
            return response
        data = getattr(response, "data", None)
        if isinstance(data, dict):
            return data
        return {"id": getattr(response, "id", None)}
