# RTC Crackers Email Module

## Project placement

```text
PROJECT/
├── .env                 # local secrets; never commit
├── backend/
│   ├── __init__.py
│   └── EMAIL/
│       ├── config.py
│       ├── dependencies.py
│       ├── exceptions.py
│       ├── repositories.py
│       ├── resend_client.py
│       ├── router.py
│       ├── schemas.py
│       ├── services.py
│       └── webhook.py
└── ...
```

Vercel production environment variables are read directly by `pydantic-settings`.
The backend does not require an `EMAIL/.env`.

## Flow

```text
Website/API
   |
   +--> EmailService --> ResendEmailClient --> Resend
   |          |
   |          +-----------------------------> PostgreSQL
   |
   +--> Inbox/Outbox --> PostgreSQL
   |
Resend inbound webhook
   |
   +--> webhook.py --> EmailService --> PostgreSQL
```

## FastAPI integration

```python
from backend.EMAIL.router import router as email_router
from backend.EMAIL.webhook import router as email_webhook_router

app.include_router(email_router, prefix="/api/email")
app.include_router(email_webhook_router, prefix="/api/email")
```

## Production security

Protect the email routes with your existing admin authentication/authorization.
Do not expose the Resend API key to frontend JavaScript.

The inbound webhook must also be signature-verified before production use.
