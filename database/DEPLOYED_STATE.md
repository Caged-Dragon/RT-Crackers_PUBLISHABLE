# Live state of Supabase project `RTCrackers` (josnuaaupzylzgvvnydg, ap-south-1)

Checked/updated 2026-10-04.

| Layer | State |
|---|---|
| Base schema + seed, Upgrade V2, V3 | applied (schema_versions = 3.0; 140 public tables) |
| 22_ADMIN_SECURITY | applied (1 primary admin) |
| 25_EMAIL | applied (9 mailboxes) |
| 99_DEPLOYMENT/009 Production hardening | **applied 2026-10-04** (COD-only trigger, inventory idempotency index) |
| 26_PLATFORM release governance | **applied 2026-10-04** (+ RLS enabled on its 3 tables) |
| RLS | enabled on all public tables (API connects with the owner role; no public policies) |
| Storage | buckets `rt-media`, `rt-banners` (public read) |
| Catalog data | **empty**: 0 products, 0 categories (add via admin panel) |

Do not replay 001_Schema_build.sql against this database.
`99_DEPLOYMENT/010_Production_verification.sql` was corrected (`reserved_quantity` -> `reserved_stock`).
