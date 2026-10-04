from fastapi import APIRouter, Depends, HTTPException, Request

from .dependencies import get_db
from .exceptions import EmailBackendError
from .repositories import EmailRepository
from .resend_client import ResendEmailClient
from .services import EmailService

router = APIRouter(tags=["email-webhook"])


@router.post("/webhook/resend")
async def resend_webhook(
    request: Request,
    conn=Depends(get_db),
):
    # TODO before production:
    # Verify the Resend webhook signature according to Resend's current
    # webhook verification documentation and your configured secret.
    event = await request.json()

    service = EmailService(
        repository=EmailRepository(conn),
        resend_client=ResendEmailClient(),
    )

    try:
        database_email_id = service.process_inbound_event(event)
    except (EmailBackendError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return {
        "received": True,
        "database_email_id": database_email_id,
    }
