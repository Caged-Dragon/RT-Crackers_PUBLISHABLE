from typing import Any

from .exceptions import InvalidMailboxError
from .repositories import EmailRepository
from .resend_client import ResendEmailClient


class EmailService:
    """Coordinates business logic between the API, DB and Resend."""

    def __init__(
        self,
        repository: EmailRepository,
        resend_client: ResendEmailClient,
    ) -> None:
        self.repository = repository
        self.resend = resend_client

    def send_email(
        self,
        *,
        mailbox_id: int,
        to: list[str],
        subject: str,
        body_text: str | None,
        body_html: str | None,
        cc: list[str] | None = None,
        bcc: list[str] | None = None,
        reply_to: str | None = None,
        thread_id: str | None = None,
        in_reply_to: str | None = None,
    ) -> dict[str, Any]:
        mailbox = self.repository.get_mailbox(mailbox_id)

        if not body_text and not body_html:
            raise ValueError("At least body_text or body_html is required.")

        response = self.resend.send(
            from_address=f"{mailbox['name']} <{mailbox['email']}>",
            to=to,
            cc=cc,
            bcc=bcc,
            reply_to=reply_to,
            subject=subject,
            text=body_text,
            html=body_html,
            headers={"X-RTC-Mailbox": mailbox["email"]},
        )

        resend_id = response.get("id")

        database_id = self.repository.create_outbound_email(
            mailbox_id=mailbox_id,
            from_address=mailbox["email"],
            to_address=", ".join(to),
            cc=", ".join(cc) if cc else None,
            bcc=", ".join(bcc) if bcc else None,
            reply_to=reply_to,
            subject=subject,
            body_text=body_text,
            body_html=body_html,
            status="sent",
            resend_email_id=resend_id,
            thread_id=thread_id,
            in_reply_to=in_reply_to,
        )

        return {
            "database_email_id": database_id,
            "resend_email_id": resend_id,
            "status": "sent",
        }

    def process_inbound_event(self, event: dict[str, Any]) -> int | None:
        if event.get("type") != "email.received":
            return None

        data = event.get("data") or {}

        recipient = self._first_string(
            data.get("to"),
            data.get("recipient"),
            data.get("to_address"),
        )
        sender = self._first_string(
            data.get("from"),
            data.get("sender"),
            data.get("from_address"),
        )

        if not recipient or not sender:
            raise ValueError("Inbound event is missing sender or recipient.")

        mailbox = self.repository.get_mailbox_by_email(recipient)

        return self.repository.create_inbound_email(
            mailbox_id=mailbox["id"],
            resend_email_id=data.get("email_id") or data.get("id"),
            from_address=sender,
            to_address=recipient,
            cc=self._join_value(data.get("cc")),
            bcc=self._join_value(data.get("bcc")),
            reply_to=data.get("reply_to"),
            subject=data.get("subject") or "",
            body_text=data.get("text"),
            body_html=data.get("html"),
            message_id=data.get("message_id"),
            in_reply_to=data.get("in_reply_to"),
            thread_id=data.get("thread_id"),
            event_data=event,
        )

    @staticmethod
    def _first_string(*values: Any) -> str | None:
        for value in values:
            if isinstance(value, str) and value.strip():
                return value.strip()
            if isinstance(value, list) and value:
                first = value[0]
                if isinstance(first, str) and first.strip():
                    return first.strip()
        return None

    @staticmethod
    def _join_value(value: Any) -> str | None:
        if isinstance(value, list):
            return ", ".join(str(v) for v in value)
        if value is None:
            return None
        return str(value)
