# RTC Crackers Mail database

This directory is intentionally additive. It does not replace or rewrite the
existing RT Crackers commerce/auth schema.

Apply `001_email_core.sql` after the supplied database build. It creates the
mailbox/message persistence expected by `BACKEND/app/modules/email` and adds
archive/trash state required by the supplied email UI.

Recommended deployment order:
1. Run the existing `DATABASE/99_DEPLOYMENT` build from the supplied product.
2. Run `DATABASE/25_EMAIL/001_email_core.sql`.
3. Insert the real domain mailboxes into `mailboxes`.
4. Configure `RESEND_API_KEY` and `EMAIL_WEBHOOK_SECRET`.
5. Configure the Resend webhook to `/api/v1/email/webhook/resend`.
