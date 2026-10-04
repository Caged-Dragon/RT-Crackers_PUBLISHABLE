# RT Crackers Admin API

Base path: `/api/v1/admin`

## Authentication
- `POST /auth/login`
- `POST /auth/logout`
- `POST /auth/refresh`
- `POST /auth/change-password`
- `POST /auth/forgot-password`
- `POST /auth/reset-password`

## Modules
- `/dashboard`
- `/admin-users`
- `/roles`
- `/permissions`
- `/products`
- `/categories`
- `/inventory`
- `/orders`
- `/customers`
- `/coupons`
- `/banners`
- `/newsletters`
- `/shipping`
- `/delivery`
- `/cms/{pages|home-sections|menus|menu-items|footer-links|faqs|policies}`
- `/settings` and `/settings/system-configurations`
- `/analytics/{revenue|orders|products|customers}`
- `/reports/{sales|inventory|tax|orders|customers}`
- `/audit/{login-history|system-audit|product-changes|inventory-changes|order-changes}`

All non-authenticated business endpoints require a valid admin access token and a permission.
