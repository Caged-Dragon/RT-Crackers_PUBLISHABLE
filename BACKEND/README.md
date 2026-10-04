# RT Crackers — Production E-commerce Platform

This repository is the hardened version of the existing RT Crackers codebase. It does **not** regenerate the project or replace the existing PostgreSQL schema/admin modules.

## Architecture

- `CUSTOMER/`: customer FastAPI application (catalog, cart, checkout, COD orders, accounts, reviews, tracking).
- `ADMIN/`: admin FastAPI application (authentication, RBAC, products, inventory, orders, CMS, coupons, analytics).
- `app/`: existing platform/worker modules retained for background jobs and compatibility.
- `../FRONTEND/SITE/`: existing static storefront/admin pages with a live API runtime.
- `../DATABASE/`: existing PostgreSQL schema and upgrade scripts.
- `devops/nginx.conf`: production reverse proxy and static site server.
- `docker-compose.yml`: production-oriented local/VPS topology.

## Local setup

1. Copy `.env.example` to `.env` and use development-safe values.
2. Create PostgreSQL and Redis.
3. Install dependencies separately for `CUSTOMER`, `ADMIN`, and `BACKEND` when you need the platform worker.
4. Apply the existing database build/upgrade scripts in `DATABASE/99_DEPLOYMENT/` in their documented order.
5. Run customer and admin migrations with the guides below if your database uses Alembic-managed changes.
6. Start `customer-api`, `admin-api`, Redis, PostgreSQL, Celery, and Nginx with Compose.

## Database migration guide

For a new database, follow the existing master build first:

```bash
cd DATABASE
psql "$DATABASE_URL" -f 99_DEPLOYMENT/001_Schema_build.sql
psql "$DATABASE_URL" -f 99_DEPLOYMENT/002_Master_seed_data.sql
psql "$DATABASE_URL" -f 99_DEPLOYMENT/006_Upgrade_v2_build.sql
psql "$DATABASE_URL" -f 99_DEPLOYMENT/007_Upgrade_v3_build.sql
psql "$DATABASE_URL" -f 99_DEPLOYMENT/008_Admin_security_build.sql
psql "$DATABASE_URL" -f 99_DEPLOYMENT/009_Production_hardening.sql
psql "$DATABASE_URL" -f 99_DEPLOYMENT/010_Production_verification.sql
```

For an existing installation, **take a PostgreSQL backup first**, inspect the scripts, then apply only the upgrades that are not already recorded by your database's schema-version system. Never blindly replay the base build against production.

Alembic is retained for application-specific migrations. Run from the relevant application directory:

```bash
cd BACKEND/CUSTOMER && alembic upgrade head
cd ../ADMIN && alembic upgrade head
```

Use the direct migration connection for Alembic when using a managed pooler.

## Health endpoints

- `/health` — liveness plus database check.
- `/ready` — readiness; returns non-2xx when PostgreSQL is unavailable.
- `/metrics` — Prometheus metrics.

## COD-only checkout

Online payment gateways are intentionally disabled. Checkout accepts only `COD`, and the database already constrains `payment_methods.method_code` to `COD`. Production hardening adds a trigger that rejects any direct SQL order using another payment method.

Order placement re-prices the cart server-side, validates shipping/COD eligibility, locks inventory rows, re-checks stock, records the inventory sale movement, creates the COD transaction, and commits atomically. Cancellation restocks inventory under row locks.

## Backup strategy

- Daily managed PostgreSQL backups plus point-in-time recovery where the provider supports it.
- Before every schema upgrade, create an on-demand snapshot and export a logical backup.
- Store backups outside the application host.
- Test a restore at least monthly.
- Redis is a cache/job broker, not the source of truth; PostgreSQL is authoritative.

Example logical backup:

```bash
pg_dump --format=custom --no-owner --no-privileges "$DATABASE_URL" > rtcrackers-$(date +%F).dump
```

## Production setup

On a VPS/EC2/DigitalOcean host:

```bash
git clone <your-repository>
cd <repository>/BACKEND
cp ../.env.example .env
# edit .env with real PostgreSQL, Redis, SMTP and JWT values
docker compose build
docker compose up -d
```

Put TLS in front of Nginx using your preferred certificate manager, or run Nginx behind a managed load balancer/CDN that terminates HTTPS. Do not expose PostgreSQL or Redis publicly.

## Railway / Render

Deploy the existing `CUSTOMER` and `ADMIN` Dockerfiles as separate web services, use managed PostgreSQL and Redis, and set the same environment variables from `.env.example`. The static `FRONTEND/SITE` directory can be served by the Nginx container on a VM or as a static site on the platform. Keep the API paths `/api/v1` and `/api/v1/admin` so the frontend needs no secret configuration.

## Domain publishing

Recommended DNS layout:

- `www.rtcrackers.com` → frontend/Nginx host.
- `rtcrackers.com` → redirect to `www.rtcrackers.com`.
- If using separate API hosts instead, set `customerApi` and `adminApi` in `FRONTEND/SITE/runtime/config.js` and update CORS/cookie domain accordingly.

The simplest production setup is same-origin `/api/v1` and `/api/v1/admin`, which avoids cross-origin cookie complexity.

## Testing

Static syntax checks:

```bash
python -m compileall -q BACKEND
node --check FRONTEND/SITE/runtime/rtc-runtime.js
```

The CI workflow runs customer, admin, platform and frontend checks. Full runtime verification requires a PostgreSQL/Redis environment; the audit environment did not have Docker or outbound package installation available, so those checks must be completed in CI or on the deployment host.

## Security

Never commit `.env`. Use a 48+ character random JWT secret, verified PostgreSQL TLS in production, explicit HTTPS CORS origins, HttpOnly/Secure auth cookies, non-root containers, Nginx rate limiting, application rate limiting, security headers, parameterized SQL, and server-authoritative pricing/inventory.
