from fastapi import APIRouter, Depends, HTTPException, Query

from .dependencies import get_db
from .exceptions import EmailBackendError
from .repositories import EmailRepository
from .resend_client import ResendEmailClient
from .schemas import SendEmailRequest
from .services import EmailService

router = APIRouter(tags=["email"])


def get_email_service(conn=Depends(get_db)) -> EmailService:
    return EmailService(
        repository=EmailRepository(conn),
        resend_client=ResendEmailClient(),
    )


@router.get("/mailboxes")
def list_mailboxes(conn=Depends(get_db)):
    return EmailRepository(conn).list_mailboxes()


@router.post("/send")
def send_email(payload: SendEmailRequest, service: EmailService = Depends(get_email_service)):
    try:
        return service.send_email(
            mailbox_id=payload.mailbox_id,
            to=[str(x) for x in payload.to],
            cc=[str(x) for x in payload.cc],
            bcc=[str(x) for x in payload.bcc],
            reply_to=str(payload.reply_to) if payload.reply_to else None,
            subject=payload.subject,
            body_text=payload.body_text,
            body_html=payload.body_html,
            thread_id=payload.thread_id,
            in_reply_to=payload.in_reply_to,
        )
    except EmailBackendError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.post("/drafts")
def save_draft(payload: SendEmailRequest, conn=Depends(get_db)):
    repo = EmailRepository(conn)
    try:
        draft_id = repo.create_draft(
            mailbox_id=payload.mailbox_id,
            to_address=", ".join(str(x) for x in payload.to) or None,
            cc=", ".join(str(x) for x in payload.cc) or None,
            bcc=", ".join(str(x) for x in payload.bcc) or None,
            subject=payload.subject,
            body_text=payload.body_text,
            body_html=payload.body_html,
            thread_id=payload.thread_id,
        )
        return {"database_email_id": draft_id, "status": "draft"}
    except EmailBackendError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def _list_folder(folder: str, mailbox_id: int, limit: int, offset: int, conn):
    try:
        return EmailRepository(conn).list_folder_messages(
            mailbox_id=mailbox_id, folder=folder, limit=limit, offset=offset
        )
    except EmailBackendError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/inbox/{mailbox_id}")
def inbox(mailbox_id: int, limit: int = Query(50, ge=1, le=100),
          offset: int = Query(0, ge=0), conn=Depends(get_db)):
    return _list_folder("inbox", mailbox_id, limit, offset, conn)


@router.get("/outbox/{mailbox_id}")
def outbox(mailbox_id: int, limit: int = Query(50, ge=1, le=100),
           offset: int = Query(0, ge=0), conn=Depends(get_db)):
    return _list_folder("sent", mailbox_id, limit, offset, conn)


@router.get("/starred/{mailbox_id}")
def starred(mailbox_id: int, limit: int = Query(50, ge=1, le=100),
            offset: int = Query(0, ge=0), conn=Depends(get_db)):
    return _list_folder("starred", mailbox_id, limit, offset, conn)


@router.get("/archived/{mailbox_id}")
def archived(mailbox_id: int, limit: int = Query(50, ge=1, le=100),
             offset: int = Query(0, ge=0), conn=Depends(get_db)):
    return _list_folder("archived", mailbox_id, limit, offset, conn)


@router.get("/trash/{mailbox_id}")
def trash(mailbox_id: int, limit: int = Query(50, ge=1, le=100),
          offset: int = Query(0, ge=0), conn=Depends(get_db)):
    return EmailRepository(conn).list_folder_messages(
        mailbox_id=mailbox_id, folder="trash", limit=limit, offset=offset
    )


@router.get("/drafts/{mailbox_id}")
def drafts(mailbox_id: int, limit: int = Query(50, ge=1, le=100),
           offset: int = Query(0, ge=0), conn=Depends(get_db)):
    return _list_folder("drafts", mailbox_id, limit, offset, conn)


@router.get("/search/{mailbox_id}")
def search(mailbox_id: int, q: str = Query(..., min_length=1),
           limit: int = Query(50, ge=1, le=100),
           offset: int = Query(0, ge=0), conn=Depends(get_db)):
    return EmailRepository(conn).search_messages(
        mailbox_id=mailbox_id, query_text=q, limit=limit, offset=offset
    )


@router.get("/messages/{email_id}")
def get_message(email_id: int, conn=Depends(get_db)):
    try:
        return EmailRepository(conn).get_message(email_id)
    except EmailBackendError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


def _set_flag(email_id: int, field: str, value: bool, conn):
    repo = EmailRepository(conn)
    try:
        repo.get_message(email_id, include_deleted=(field == "delete" and value is False))
        if field == "read":
            repo.set_read(email_id, value)
        elif field == "star":
            repo.set_starred(email_id, value)
        elif field == "archive":
            repo.set_archived(email_id, value)
        elif field == "delete":
            repo.set_deleted(email_id, value)
        return {"success": True}
    except EmailBackendError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/messages/{email_id}/read")
def mark_read(email_id: int, conn=Depends(get_db)):
    return _set_flag(email_id, "read", True, conn)


@router.post("/messages/{email_id}/unread")
def mark_unread(email_id: int, conn=Depends(get_db)):
    return _set_flag(email_id, "read", False, conn)


@router.post("/messages/{email_id}/star")
def star_message(email_id: int, conn=Depends(get_db)):
    return _set_flag(email_id, "star", True, conn)


@router.post("/messages/{email_id}/unstar")
def unstar_message(email_id: int, conn=Depends(get_db)):
    return _set_flag(email_id, "star", False, conn)


@router.post("/messages/{email_id}/archive")
def archive_message(email_id: int, conn=Depends(get_db)):
    return _set_flag(email_id, "archive", True, conn)


@router.post("/messages/{email_id}/unarchive")
def unarchive_message(email_id: int, conn=Depends(get_db)):
    return _set_flag(email_id, "archive", False, conn)


@router.post("/messages/{email_id}/trash")
def trash_message(email_id: int, conn=Depends(get_db)):
    return _set_flag(email_id, "delete", True, conn)


@router.post("/messages/{email_id}/restore")
def restore_message(email_id: int, conn=Depends(get_db)):
    return _set_flag(email_id, "delete", False, conn)
