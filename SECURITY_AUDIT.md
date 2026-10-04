# Security Audit

## Controls reviewed

### Authentication / authorization
- Customer authentication validates signed access tokens plus server-side session state.
- Refresh tokens are hashed at rest and rotated; replayed revoked refresh tokens terminate the session.
- Admin access uses explicit permission checks and role fallback.
- Passwords use Argon2 through `argon2-cffi`.
- Production JWT secrets must be 48+ characters and non-default.
- Production CORS requires explicit HTTPS origins.
- Auth cookies are HttpOnly/Secure in production and support a shared `.rtcrackers.com` domain.

### Rate limiting
- Customer/admin applications retain application-level sliding-window limits.
- Nginx adds edge rate limits, including stricter `/auth` limits.
- **Residual:** application memory limits are per process. For multiple hosts/replicas, use a shared Redis/API-gateway limiter for strict global quotas.

### Input and SQL safety
- FastAPI/Pydantic models constrain IDs, quantities, emails, phone numbers, pincodes, notes and coupon codes.
- Raw SQL inspected in the codebase uses bound parameters for dynamic values.
- No evidence of string-interpolated user SQL was found in the audited application paths.
- Inventory/order mutations use SQLAlchemy transactions and row locks.

### XSS / headers
Added:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy`
- `Cross-Origin-Opener-Policy`
- `Cross-Origin-Resource-Policy`
- CSP
- HSTS when HTTPS is detected

CMS content is still an intentionally HTML-capable feature; production CMS authors must only be trusted administrators. If arbitrary untrusted HTML is ever allowed, add server-side HTML sanitization with an allowlist.

### Transport security
- Production DB defaults to `verify-full`.
- Compatibility `require` mode verifies certificate chains rather than using `CERT_NONE`.
- Production rejects `DB_SSL_MODE=disable`.
- Nginx is intended to sit behind HTTPS/TLS termination.

### Payment security
- Razorpay/online payment endpoints are disabled.
- COD is the only active payment method in application logic and database hardening.
- COD amount is server-authoritative.
- Direct SQL orders using a non-COD method are rejected by a database trigger.

## Findings

| Severity | Finding | Status |
|---|---|---|
| Critical | Online payment code could violate COD-only product requirement | Fixed |
| High | DB TLS used `CERT_NONE` in `require` mode | Fixed |
| High | Missing security headers | Fixed |
| High | Production CORS/secret validation insufficiently strict | Fixed |
| Medium | Per-process rate limiter is not globally shared | Remaining blocker |
| Medium | CMS supports trusted HTML and is not a general untrusted-HTML sanitizer | Controlled by admin RBAC; sanitize if public editing is introduced |
| Low | Dependency versions are range-based | CI lockfile/SBOM is recommended before launch |

## Pre-launch security checklist

- Rotate all production secrets.
- Confirm `.env` is not tracked.
- Use a unique DB user with only required privileges.
- Block public access to PostgreSQL and Redis.
- Enable managed DB backups/PITR.
- Configure TLS and HSTS at the edge.
- Put the admin URL behind additional network controls if practical (VPN/allowlist/WAF).
- Run a staging authenticated API scan and dependency vulnerability scan.


## Final enhancement pass
- Browser Supabase configuration was removed from the production frontend adapter; Python/FastAPI is authoritative.
- Razorpay execution code was removed from the legacy payment service; COD-only enforcement remains.
- PWA updates require explicit user approval before service-worker activation.
- Release verification occurs before publication and failed verification leaves the current release untouched.
