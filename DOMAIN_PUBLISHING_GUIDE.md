# RTCrackers domain publishing guide

## Recommended production topology

Domain -> HTTPS reverse proxy/Nginx -> Customer FastAPI + Admin FastAPI -> PostgreSQL + Redis.

The website files are in `FRONTEND/WEB` and the production Nginx container serves that directory.

## DNS

Create:
- `A @ <VPS-IP>`
- `A www <VPS-IP>`

Or use your provider's equivalent custom-domain configuration.

## TLS

Use Let's Encrypt/Certbot or Cloudflare. Force HTTP -> HTTPS.

Set:
- `FRONTEND_URL=https://your-domain`
- `CORS_ORIGINS=https://your-domain`
- `AUTH_COOKIE_SECURE=true`
- `AUTH_COOKIE_DOMAIN` only when cross-subdomain cookies are actually required.

## First deployment

1. Upload/clone the repository.
2. Copy `.env.example` to `.env`.
3. Set production PostgreSQL, Redis, JWT, email and storage values.
4. Back up the existing PostgreSQL database.
5. Run `DATABASE/26_PLATFORM/001_platform_release_governance.sql`.
6. Run the existing production database verification/hardening scripts in their documented order.
7. `docker compose -f BACKEND/docker-compose.yml build`
8. `docker compose -f BACKEND/docker-compose.yml up -d`
9. Check `/health`, `/ready`, `/metrics`.
10. Test customer registration/login, cart, COD checkout, order tracking, cancellation and inventory.
11. Test admin RBAC, primary-admin administrator management and release manager.
12. Configure the domain/TLS and perform a real browser/device test.

## PWA release process

A release is not automatically activated for an installed user.

Admin:
1. Create a release draft in `/admin-release.html`.
2. Stage page/section content.
3. Verify the release.
4. Publish it only after verification succeeds.

Customer:
1. Existing app continues using the accepted release.
2. The app detects a newer published release.
3. It displays an Update prompt.
4. `Update` activates the waiting service worker/release.
5. `Keep current` leaves the installed version unchanged.

If verification fails, the current live release is retained and the editor is notified by email.

## Backup

Before schema changes:
- PostgreSQL logical backup with `pg_dump`.
- For managed PostgreSQL, take a provider snapshot where available.
- Store backups outside the application server.
- Test restore regularly.

Never store database passwords, JWT secrets, SMTP passwords or service credentials in Git.
