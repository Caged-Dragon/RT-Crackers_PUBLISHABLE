# RT Crackers — Production E-commerce Platform

This is the existing RT Crackers codebase hardened for production. The project was **not regenerated from scratch**.

## What is included

- Existing PostgreSQL schema preserved.
- Existing customer FastAPI application preserved and hardened.
- Existing admin FastAPI/RBAC modules preserved and hardened.
- COD-only checkout/order workflow.
- Production Docker Compose topology for PostgreSQL, Redis, customer API, admin API, Celery and Nginx.
- Existing static frontend retained and connected to live APIs.
- Security, database, performance and deployment reports.

## Key documents

- `AUDIT_REPORT.md`
- `SECURITY_AUDIT.md`
- `DATABASE_AUDIT.md`
- `PERFORMANCE_REPORT.md`
- `DEPLOYMENT_CHECKLIST.md`
- `REMAINING_BLOCKERS.md`
- `BACKEND/README.md`

## Local/VPS launch

```bash
cp .env.example .env
# edit .env
cd BACKEND
docker compose build
docker compose up -d
```

For a fresh database, use the existing scripts under `DATABASE/99_DEPLOYMENT/`. For an existing database, back it up first and apply only the required upgrade/hardening scripts.

## Domain publishing

The simplest production topology is same-origin:

- `https://www.rtcrackers.com/` → Nginx/static storefront
- `https://www.rtcrackers.com/api/v1/...` → customer API
- `https://www.rtcrackers.com/api/v1/admin/...` → admin API

This avoids cross-origin cookie complexity. Point your domain DNS to the VPS/host, expose only ports 80/443, and keep PostgreSQL/Redis private. Terminate TLS at Nginx or a managed load balancer/CDN and redirect HTTP to HTTPS.

For Railway/Render, deploy `BACKEND/CUSTOMER` and `BACKEND/ADMIN` as separate Docker services, use managed PostgreSQL/Redis, and serve `FRONTEND/SITE` as a static site or through the included Nginx container.

## Validation

```bash
python -m compileall -q BACKEND
node --check FRONTEND/SITE/runtime/rtc-runtime.js
```

Full runtime validation must run in CI/staging with PostgreSQL, Redis, Docker and real provider credentials.


## RTCrackers feature parity
See `FEATURE_PARITY_MATRIX.md`. The supplied reference archive was audited for its customer/admin feature surface and its pages were preserved under `FRONTEND/WEB`; production data/auth/order logic uses the Python/PostgreSQL backend.
