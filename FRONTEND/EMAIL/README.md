# RTC Crackers Mail frontend

The supplied Stitch screens are preserved in `DESIGNS/` and copied to
`PAGES/` without redesigning them. The integration layer only adds:

- local configuration in `config.js`
- API calls in `email-api.js`
- non-invasive runtime wiring in `email-runtime.js`
- small integration CSS in `email-runtime.css`

Core live operations are connected to `/api/v1/email`:
mailboxes, inbox, sent, starred, archived, trash, drafts, search, message
detail, read/unread, star/unstar, archive/unarchive, trash/restore, send,
and draft creation.

The provider secret is never placed in frontend JavaScript.

For production, serve these files from the same origin as the FastAPI API (or
configure the API CORS policy appropriately) and keep the existing platform
authentication/session layer in front of the email endpoints.
