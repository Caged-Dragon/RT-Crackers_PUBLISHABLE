# Upgrade v2 (enterprise upgrade, split by upgrade)

Split from `rt_crackers_upgrade_v2.sql`. This is a **migration** that runs on top of the base schema
(`99_DEPLOYMENT/001_Schema_build.sql` + `002_Master_seed_data.sql`, or `build/rt_crackers_full.sql`).
It changes existing tables, so it is kept in its own folder and the base module files are left untouched.

## How to deploy
- psql, from the database root folder: `psql "$DATABASE_URL" -f 99_DEPLOYMENT/006_Upgrade_v2_build.sql`
- Supabase SQL editor (no `\i`): paste `build/rt_crackers_upgrade_v2_full.sql` (generated, same content)
- Take a backup / snapshot first. One transaction: any error rolls everything back. It refuses to run twice.

## Files (run order = number order)
| File | Upgrade |
|---|---|
| 000_Preflight.sql | pre-flight checks, disables USER triggers for backfills |
| 001_U01_Geography.sql | U1 countries/states/districts/cities/postal_codes, addresses -> postal_code_id |
| 002_U08_Address_management.sql | U8 address label/instructions/verification, v_addresses_full, pincodes view |
| 003_U02_Product_seo.sql | U2 product_seo |
| 004_U03_Product_audit.sql | U3 product_audit_logs + trigger |
| 005_U04_Soft_delete.sql | U4 soft delete on 8 tables |
| 006_U05_User_security.sql | U5 user security columns + lockout trigger |
| 007_U15_User_validation.sql | U15 user validation checks |
| 008_U06_Inventory.sql | U6 stock buckets, generated available_stock / stock_status |
| 009_U07_Order_tracking_events.sql | U7 order_tracking_events |
| 010_U09_Analytics.sql | U9 dashboard/revenue/customer/product/conversion analytics, cart_abandonment_logs |
| 011_U10_Review_moderation.sql | U10 reviews.moderation_status, moderated_by/at |
| 012_U11_Coupons.sql | U11 coupon renames + remaining_uses |
| 013_U12_Cart_protection.sql | U12 notes only (already enforced by uq_cart_items_line) |
| 014_U13_Wishlist_protection.sql | U13 one product per user across wishlists (trigger) |
| 015_U17_System_configurations.sql | U17 config_key unique, is_active |
| 016_U18_Feature_flags.sql | U18 feature_id / feature_name |
| 017_U19_Error_logs.sql | U19 error_logs spec names |
| 018_U20_Audit_logs.sql | U20 audit_logs spec names, LOGIN/LOGOUT tracking |
| 019_Supporting_indexes_and_comments.sql | extra indexes, table comments |
| 020_Finalize.sql | re-enable triggers, updated_at triggers + RLS for new tables |
| 021_Verification.sql | final checks; any miss rolls the upgrade back |
| 098_Check_upgrade_applied.sql | NOT part of the run: read-only query, 20 PASS/FAIL rows after deploying |
| 099_Cleanup_failed_run.sql | NOT part of the run: only after a failed run that left objects behind |

## Notes
- Files depend on each other (e.g. U8 uses tables from U1), so run them in number order or use the runner.
- `build/rt_crackers_upgrade_v2_full.sql` is generated; edit the module files, not that one.
- Placeholder files in other folders (e.g. `04_PRODUCTS/007_Product_seo.sql`) stay as they are; the real DDL for
  those tables is in this folder.
- If the SQL editor fails on a big paste, reset the `public` schema and re-run base then v2 (see chat history).
- Re-check anytime with `build/verify_upgrade_v2.sh`.

## Verified equivalence
Built on Postgres 16: original `rt_crackers_schema.sql` + `rt_crackers_upgrade_v2.sql`, versus the split project
(`001_Schema_build.sql` + seed + `006_Upgrade_v2_build.sql`), versus `build/rt_crackers_full.sql` +
`build/rt_crackers_upgrade_v2_full.sql`. `pg_dump` schema and data output is identical for all three (88 tables).
