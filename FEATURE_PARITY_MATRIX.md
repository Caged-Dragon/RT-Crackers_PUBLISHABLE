# RTCrackers Reference Feature Parity Matrix

The legacy/reference archive is treated as a feature inventory, not as the production backend.

## Customer surface
- [x] `404.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `about.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `account.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `admin-dashboard.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `admin-register.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `admin.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `contact.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `feedback.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `index.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `intro.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `login.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `my-orders.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `offline.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `order.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `policy.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `product.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `products.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.
- [x] `reset-password.html` — preserved as a customer-facing route/page in `FRONTEND/WEB/`.

## Backend capability mapping
- [x] Authentication: registration, login, refresh, logout, password reset, email/phone verification.
- [x] Product catalogue: listing, filters, search, featured/trending/new arrivals, detail, images, variants, attributes.
- [x] Categories and discovery.
- [x] Cart: guest token, authenticated cart, merge, coupon, quantities, totals.
- [x] Checkout: address, shipping, coupon, tax/total calculation, COD only.
- [x] Orders: creation, idempotency, status lifecycle, cancellation, tracking, invoices.
- [x] Inventory: locked stock decrement, movement history, cancellation restoration.
- [x] Customer: profile, addresses, wishlist, referrals, notifications, recently viewed, reviews.
- [x] Admin: authentication, RBAC, products, categories, inventory, orders, customers, coupons, banners, newsletters, shipping, delivery, CMS, settings, analytics, reports, audit, admin users, roles and permissions.
- [x] CMS release governance: arbitrary page/section JSON content, draft -> verification -> publish, immutable release snapshots and rollback-safe superseded releases.
- [x] Primary administrator boundary: administrator lifecycle/audit permissions remain separate from normal admin permissions.
- [x] PWA: manifest, offline shell, installable service worker, explicit release/update prompt.
- [x] COD-only payment workflow: no online payment provider is enabled.
- [x] Deployment: Docker, Compose, Nginx, health/readiness/metrics, PostgreSQL and Redis.

## PWA release policy

1. Admin edits data/content into a draft release.
2. Release is structurally verified.
3. Only a VERIFIED release can become PUBLISHED.
4. Existing users remain on their accepted release.
5. The browser/PWA displays an update prompt when a newer release is available.
6. Clicking **Update** activates the waiting service worker/release.
7. Clicking **Keep current** leaves the existing release active.
8. Failed verification never replaces the live release.
9. The editor receives an email for verification success/failure and publication.

## Reference limitations deliberately not copied

The legacy project's Supabase-specific client writes and demo-only browser order flow are not used as the production data path. The Python/FastAPI backend remains authoritative.
