# Deployment order

1. Provision PostgreSQL and Redis using the existing backend deployment files.
2. Apply the supplied `DATABASE/99_DEPLOYMENT` database build.
3. Apply `DATABASE/25_EMAIL/001_email_core.sql`.
4. Set root/backend environment values from `.env`.
5. Build/start `BACKEND`.
6. Serve `FRONTEND/SITE` using the existing frontend deployment approach.
7. Serve `FRONTEND/EMAIL/PAGES` at `/email/*`.
8. Configure Resend inbound webhook to `/api/v1/email/webhook/resend`.
9. Create/verify domain mailboxes in the `mailboxes` table.
10. Verify send, inbound webhook, read/unread, star, archive, trash, and draft flows.

Do not place `RESEND_API_KEY` in frontend files.
