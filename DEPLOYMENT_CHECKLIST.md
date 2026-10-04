# Production Deployment Checklist

## Before deploy

- [ ] Production PostgreSQL created and private.
- [ ] Redis created and private.
- [ ] `.env` populated with real secrets; no secrets committed.
- [ ] `JWT_SECRET_KEY` is 48+ random characters.
- [ ] `DB_SSL_MODE=verify-full` and CA/trust configuration verified.
- [ ] `CORS_ORIGINS=https://www.rtcrackers.com`.
- [ ] `AUTH_COOKIE_DOMAIN=.rtcrackers.com` and Secure cookies enabled.
- [ ] SMTP credentials tested.
- [ ] Database backup/PITR enabled.
- [ ] Staging migration completed successfully.
- [ ] `009_Production_hardening.sql` reviewed and applied.
- [ ] `010_Production_verification.sql` passes.

## Application

- [ ] `python -m compileall -q BACKEND` passes.
- [ ] Customer tests pass in CI.
- [ ] Admin tests pass in CI.
- [ ] Platform/worker tests pass in CI.
- [ ] Frontend `node --check` passes.
- [ ] Customer `/health` returns 200.
- [ ] Customer `/ready` returns 200.
- [ ] Admin `/health` returns 200.
- [ ] Admin `/ready` returns 200.
- [ ] `/metrics` returns Prometheus output.
- [ ] Celery worker starts.
- [ ] Celery beat starts.
- [ ] Nginx config validates.

## Functional smoke test

- [ ] Register customer.
- [ ] Verify email/activation flow.
- [ ] Login/logout/refresh.
- [ ] Browse category/product.
- [ ] Add/remove/update cart.
- [ ] Add address and verify pincode/COD eligibility.
- [ ] Checkout summary.
- [ ] Place COD order.
- [ ] Verify one inventory sale movement.
- [ ] Confirm order in admin.
- [ ] Track order as customer.
- [ ] Cancel an eligible order and verify one restock movement.
- [ ] Verify stock never becomes negative.
- [ ] Verify coupon usage and analytics.

## Domain / TLS

- [ ] DNS A/AAAA/CNAME points to the production edge.
- [ ] HTTP redirects to HTTPS.
- [ ] `https://www.rtcrackers.com/` loads.
- [ ] `/api/v1/...` reaches customer API.
- [ ] `/api/v1/admin/...` reaches admin API.
- [ ] Admin is protected by HTTPS and, ideally, WAF/IP/VPN controls.
