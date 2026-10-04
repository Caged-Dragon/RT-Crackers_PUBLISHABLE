# RT Crackers database (split by module)

Split from `rt_crackers_schema.sql` into your folder structure.

## How to deploy
- psql: run from this folder: `psql "$DATABASE_URL" -f 99_DEPLOYMENT/001_Schema_build.sql`, then `-f 99_DEPLOYMENT/002_Master_seed_data.sql`
- Supabase SQL editor (no `\i` support): paste `build/rt_crackers_full.sql` (schema + seed in one file)

## Things to know
- Run order is dependency order, not folder order (e.g. 12_SHIPPING lookups and payment_methods come before orders). `001_Schema_build.sql` holds the correct order.
- Triggers and their functions live in the file of the table they belong to; audit triggers are in `18_SYSTEM/005_Audit_logs.sql`.
- Indexes are grouped into `19_INDEXES/001-006`.
- The `updated_at` trigger loop and the RLS loop must run after all tables exist, so they are inline at the end of `001_Schema_build.sql`.
- `12_SHIPPING/009_Zone_shipping_rates.sql` is an extra file: that table exists in your SQL but not in your tree.
- Files with no matching DDL in the source schema are placeholders containing only a comment.
- `build/rt_crackers_full.sql` is generated; edit the module files, not this one.
- Not executed against a live Postgres here, only verified for completeness by line comparison.

## Verified equivalence
Built on Postgres: the original single file, `99_DEPLOYMENT/001_Schema_build.sql` (+ seed), and `build/rt_crackers_full.sql`.
`pg_dump` schema output is identical for all three; seed data is identical apart from timestamps.
Statement order differs from the original file (triggers sit with their tables, indexes are grouped), but the resulting database is the same.
Re-check anytime with `build/verify_equivalence.sh`.

## Upgrade v2
The enterprise upgrade (U1-U20) is in `20_UPGRADE_V2/` (see its README). Deploy order:
1. base: `99_DEPLOYMENT/001_Schema_build.sql` then `002_Master_seed_data.sql` (or `build/rt_crackers_full.sql`)
2. upgrade: `99_DEPLOYMENT/006_Upgrade_v2_build.sql` (or `build/rt_crackers_upgrade_v2_full.sql` in the Supabase SQL editor)

## Upgrade V3
Deterministic business codes, master/lookup tables, governance, archive, versioning and self-documentation (U21-U40) is in `21_UPGRADE_V3/` (see its README). Deploy order:
1. base + v2 as above
2. upgrade: `99_DEPLOYMENT/007_Upgrade_v3_build.sql` (or `build/rt_crackers_upgrade_v3_full.sql` in the Supabase SQL editor)

## Final Admin Security Module
The final application-admin security changes are in `22_ADMIN_SECURITY/`.
Run `99_DEPLOYMENT/008_Admin_security_build.sql` after the V3 upgrade, or paste `build/rt_crackers_admin_security_upgrade_full.sql` into the Supabase SQL Editor.
