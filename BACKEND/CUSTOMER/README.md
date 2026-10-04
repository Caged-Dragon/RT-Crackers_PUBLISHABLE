# RT Crackers Customer Python Backend

FastAPI + async SQLAlchemy backend for the customer-facing RT Crackers store. It targets the supplied PostgreSQL/Supabase schema through V3 and does not create catalogue/order tables in application startup.

## Customer API
`/api/v1/auth`, `/profile`, `/addresses`, `/products`, `/categories`, `/search`, `/cart`, `/wishlist`, `/checkout`, `/orders`, `/tracking`, `/reviews`, `/coupons`, `/referrals`, `/notifications`, `/recently-viewed`, `/dashboard`.

## Run
1. Use Python 3.12+ (recommended 3.12).
2. `python -m venv .venv` and activate it.
3. `pip install -r requirements.txt`.
4. Copy `.env.example` to `.env` and set `DATABASE_URL` and a strong `JWT_SECRET_KEY`.
5. Apply the supplied database deployment in its documented order: base, V2, then V3.
6. Run `uvicorn main:app --reload --host 0.0.0.0 --port 8000`.

Swagger: `/docs`; health: `/health`.

## OTP migration
The supplied database does not contain the verification-code table used by phone OTP. `alembic/versions/0002_verification_codes.py` adds only that table. Run `alembic upgrade head` after V3.

## Supabase
For normal API traffic, `DATABASE_URL` can be the Supabase pooler URL. For Alembic, prefer a direct/session-mode `MIGRATION_DATABASE_URL`. The engine disables asyncpg statement caching automatically for transaction-mode poolers.
