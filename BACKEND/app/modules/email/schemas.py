from pydantic import BaseModel, EmailStr, Field


class SendEmailRequest(BaseModel):
    mailbox_id: int
    to: list[EmailStr] = Field(min_length=1)
    cc: list[EmailStr] = Field(default_factory=list)
    bcc: list[EmailStr] = Field(default_factory=list)
    reply_to: EmailStr | None = None
    subject: str = ""
    body_text: str | None = None
    body_html: str | None = None
    thread_id: str | None = None
    in_reply_to: str | None = None


class SendEmailResponse(BaseModel):
    database_email_id: int
    resend_email_id: str | None = None
    status: str
