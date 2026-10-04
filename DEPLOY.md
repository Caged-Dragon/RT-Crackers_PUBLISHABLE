# RTCrackers: Deploy to Vercel + Supabase

```
Browser ──► rtcrackers (Vercel, static site)  ──/api/v1/admin/*──► rtcrackers-admin-api    (Vercel, FastAPI) ─┐
                                              ──/api/v1/*──────► rtcrackers-customer-api (Vercel, FastAPI) ─┼─► Supabase Postgres (pooler :6543)
                                                                                                            └─► Supabase Storage (rt-media)
```

The browser only ever talks to the site's own domain. The site proxies `/api/v1/*` to the two APIs
(see `site/vercel.json`), so HttpOnly auth cookies stay same-origin and no CORS/cookie-domain tuning is needed.

| Folder | What | Vercel project (Root Directory) |
|---|---|---|
| `site/` | 52 static storefront + admin pages, `vercel.json` rewrites | `rtcrackers` (existing) → `site` |
| `customer-api/` | FastAPI customer API (83 endpoints) | `rtcrackers-customer-api` → `customer-api` |
| `admin-api/` | FastAPI admin API (92 endpoints) | `rtcrackers-admin-api` → `admin-api` |
| `database/` | SQL modules (already applied to Supabase; see `database/DEPLOYED_STATE.md`) | n/a |

## Already done

* Supabase project `RTCrackers` is at schema v3 plus admin security, email, **production hardening** and **release governance** (the last two were applied in this pass).
* Both APIs boot in production mode with the lean `requirements.txt`; every non-auth admin endpoint (132) and the customer protected routes return 401 without credentials.
* Every one of the site's 51 routes and 148 relative asset links resolves through `vercel.json` (including the 2-deep routes like `/admin/orders/pending`, which would otherwise 404 on `../runtime/...`).

## Steps for you (about 15 minutes)

### 1. Push to GitHub
Copy this folder's contents into your `Caged-Dragon/RTCrackers` repo (a new branch is safest, e.g. `deploy-v3`) and push.

### 2. Create the two API projects (Vercel → Add New → Project → import the repo)
For each, set **Root Directory** and leave Framework = FastAPI (auto-detected from `main.py`):

* `rtcrackers-customer-api` → `customer-api`
* `rtcrackers-admin-api` → `admin-api`

Add the variables from each folder's `.env.vercel.example` **before** the first deploy. You must supply:

* `DATABASE_URL`: Supabase → **Connect → Transaction pooler** string (port 6543) with your database password
* `SUPABASE_SERVICE_ROLE_KEY`: Supabase → Settings → API Keys (secret key)
* `JWT_SECRET_KEY`: a different 48+ char random value per API
* `CORS_ORIGINS` / `FRONTEND_URL`: your final site URL (`https://rtcrackers.vercel.app` or the custom domain)

> If you name the projects differently, edit the two `https://rtcrackers-*-api.vercel.app` destinations at the top of `site/vercel.json`.

### 3. Point the existing `rtcrackers` project at `site/`
Vercel → rtcrackers → Settings → General: Root Directory = `site`, Framework Preset = Other, no build command, then redeploy.

### 4. Verify
```
curl https://rtcrackers-customer-api.vercel.app/health   -> {"status":"ok","database":"ok",...}
curl https://rtcrackers-admin-api.vercel.app/health      -> {"status":"ok","database":"ok",...}
curl https://rtcrackers.vercel.app/health                -> same, via the site proxy
```
Then open `/`, `/shop`, `/login`, and `/admin`.

### 5. Add your catalog
The database has **0 products and 0 categories**. Log in at `/admin`, create categories, then products and stock.
(The primary admin identity is the Supabase Auth account `caged.dragon.official@gmail.com`.)

## Things to know

* **COD only.** Checkout accepts only Cash on Delivery, enforced by app logic and by a database trigger.
* **Rate limiting is per serverless instance** (in-memory). Fine for launch; for a hard global limit add Vercel Firewall rules or a shared store.
* **Background jobs/Celery (`app/`) are not deployed**: the customer/admin APIs don't need them. Only email-inbox webhooks / scheduled jobs in `app/` would, and those need a long-running host.
* **Custom domain**: add it to the `rtcrackers` project, then update `CORS_ORIGINS` and `FRONTEND_URL` on both APIs and redeploy them.
* **Supabase Auth**: turn on *Leaked password protection* (Auth → Providers → Email); the advisor flags it as off.
* `requirements-dev.txt` in each API folder is the original full set (alembic, pytest, gunicorn, psycopg) and is used by the Dockerfiles.
* `BACKEND/devops/nginx.conf` (Docker topology only) has literal `\n` characters in its static-asset `location` block that will make nginx reject the file; unused on Vercel.
