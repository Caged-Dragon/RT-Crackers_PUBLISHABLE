# RT Crackers Complete — Production Audit Report

**Audit scope:** existing uploaded codebase, without regeneration. 912 ZIP entries were inspected; 417 Python files were present under `BACKEND`, plus the existing static storefront/admin frontend and 223 SQL files.

## Executive result

The codebase has a viable production architecture, but it was not production-ready at intake. The most important failures were an admin Python syntax error, incomplete CI coverage of the actual customer/admin apps, a deployment topology that started the wrong FastAPI application for the supplied frontend, online-payment code remaining in the legacy platform modules despite the COD-only requirement, insecure PostgreSQL `require` handling (`CERT_NONE`), missing security headers, missing customer/admin readiness/metrics endpoints, and a frontend that was mostly static until runtime wiring was added.

The existing PostgreSQL design is substantially hardened already: it contains foreign keys, check constraints, inventory triggers, COD constraints, audit/status triggers and extensive indexes. The implementation has been improved around those existing guarantees rather than replacing the schema.

## Findings by severity

### Critical

1. **Admin backend could not compile.** `BACKEND/ADMIN/ADMINS/orders/routes.py` had a non-default `BackgroundTasks` parameter after defaulted FastAPI dependency parameters. **Fixed.**
2. **Production Compose routed traffic to `app.main` instead of the actual customer/admin applications used by the frontend.** This could expose an incomplete/legacy API surface and break the purchase/admin journey. **Fixed by production Compose topology.**
3. **Legacy platform payment endpoints could create/verify Razorpay payments even though the requested product is COD-only.** **Fixed: online payment creation, verification, webhook and retry are disabled; COD is the only active path.**

### High

4. **Customer/admin applications imported `jwt` while their requirements did not explicitly install PyJWT.** **Fixed by adding PyJWT.**
5. **Aggregate `app.modules.*` relative imports were one package level too shallow, causing import failures such as `app.modules.core`.** **Fixed.**
6. **PostgreSQL SSL `require` mode disabled certificate verification (`CERT_NONE`).** **Fixed: certificate chain verification is enabled; production defaults to `verify-full`.**
7. **No security-header middleware in the customer/admin apps.** **Fixed.**
8. **Admin cancellation did not use the same inventory-restock safety path as customer cancellation.** **Fixed with locked inventory rows and `C` movements.**
9. **Application-level status history duplicated the database order-status trigger.** **Fixed by relying on the existing DB trigger with transaction-local admin identity.**
10. **Production rate limiting existed only in-process.** Nginx now supplies a shared edge limit for a single host, while application limiting remains as defense in depth. Multi-instance deployments still require an external/global limiter for strict cross-instance quotas. **Residual blocker.**

### Medium

11. **Customer/admin lacked `/ready` and `/metrics`.** **Fixed.**
12. **CI tested the platform app but not the real customer/admin applications or frontend runtime syntax.** **Fixed in CI workflow.**
13. **Frontend route files were largely static and the existing runtime only partially wired the API.** **Improved:** live catalog, product detail, cart, COD checkout and order placement wiring was added while retaining the existing pages.
14. **Existing frontend QA report made claims about routes/features that are not represented by the current repository structure.** It should be treated as historical design documentation, not proof of runtime validation. **Audit finding; current wiring is now the authority.**
15. **No automated 80% whole-repository coverage measurement exists.** Existing tests are narrow. **Residual blocker.**
16. **Runtime database/Alembic/Redis/Celery/Nginx integration could not be executed inside this audit environment because Docker was unavailable and outbound package installation was blocked.** Static checks were performed; runtime validation must complete in CI/deployment infrastructure. **Residual blocker.**

### Low

17. **Legacy aggregate platform API remains in the repository for compatibility/background jobs.** It is no longer the public storefront/admin ingress in the production Compose topology.
18. **Some deployment/docs paths are provider-specific and require real infrastructure values.** Templates and guides were added, but DNS/TLS/provider account actions cannot be completed from source code alone.

## Audit domains

| Domain | Result | Notes |
|---|---|---|
| Backend | Hardened | Customer/admin apps are the production ingress; aggregate modules retained for compatibility/jobs. |
| Frontend | Hardened/wired | Existing static pages retained; live API runtime added for catalog/cart/checkout. |
| Database | Strong + hardened | Existing schema already contains 382 FKs, 516 checks, 257 indexes and 121 triggers across the supplied SQL corpus. |
| APIs | Hardened | Routes compile; COD-only payment surface enforced. |
| Authentication | Hardened | Argon2 hashing, refresh-token rotation/reuse detection, HttpOnly cookies, production secret validation. |
| Deployment | Reworked | Separate customer/admin APIs, worker/beat, PostgreSQL, Redis and Nginx. |
| Docker | Hardened | Non-root API containers and health checks. |
| CI/CD | Improved | Customer/admin/platform/frontend validation added. |
| Security | Hardened | Headers, TLS verification, CORS validation, rate limits, SQL parameterization review. |
| Performance | Improved | Nginx keepalive, static caching, pagination, batched catalog queries, locked inventory operations. |

## Validation performed

- `python -m compileall -q BACKEND` — **passes** after fixes.
- `node --check FRONTEND/SITE/runtime/rtc-runtime.js` — **passes**.
- Existing pytest collection was attempted; the audit environment lacked required Python packages (`jose` initially) and outbound package installation was unavailable. The missing PyJWT dependency was also identified and corrected in the repository.
- Docker Compose and Nginx runtime validation were not executable because the audit environment has no Docker binary.

## Purchase journey

The authoritative path is now:

`Homepage → Product Listing → Product Details → Cart → Checkout → COD summary → COD order creation → Order tracking`

The backend remains authoritative for price, coupon, shipping, COD eligibility and inventory. The order service locks inventory rows and rechecks stock before creating the order and sale movement.

## Production disposition

The repository is materially closer to production and has the required deployment assets, but a real production launch still requires external validation against the real PostgreSQL/Redis instance, SMTP provider, TLS certificate, domain DNS and a staging checkout run.


## Final enhancement pass — 2026-10-04
- Brand standardized to `RTCrackers` in the production frontend/config defaults.
- Reference feature surface audited and preserved under `FEATURE_PARITY_MATRIX.md` and `FRONTEND/WEB`.
- Added additive release/content governance for draft -> verify -> publish.
- Added PWA explicit-update workflow; no automatic activation for installed users.
- Added admin release manager UI.
- Removed executable Razorpay/online-payment implementation; COD remains the only payment method.
