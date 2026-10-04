# Source manifest

Preserved from `RTCRACKERS_FINAL_WIRED.zip`:
- BACKEND/
- DATABASE/
- ASSETS/
- FRONTEND/SITE/

Integrated from `RTC_CRACKERS_BACKEND_ADJUSTED (1).zip`:
- backend/EMAIL module, adapted only to mount inside the existing FastAPI
  module tree and use the existing platform DATABASE_URL/config.

Integrated from `stitch_rtc_crackers_email_inbox_client.zip`:
- all supplied email page designs under FRONTEND/EMAIL/DESIGNS/
- selected/essential active pages under FRONTEND/EMAIL/PAGES/
- Ignite Mail design specification

Additive code:
- BACKEND/app/modules/email/
- DATABASE/25_EMAIL/
- FRONTEND/EMAIL/email-runtime.js
- FRONTEND/EMAIL/email-api.js
- FRONTEND/EMAIL/email-runtime.css
- CONFIG/
- root environment/config documentation

Final review:
- Python AST validation passed for the new email module and main application.
- Trash restore was explicitly checked and supports lookup of deleted rows.
- Original commerce database package is not rewritten; the email migration is additive.
