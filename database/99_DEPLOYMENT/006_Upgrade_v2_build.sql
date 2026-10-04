-- =====================================================================
-- RT CRACKERS | 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- Master script for upgrade v2 (psql). Run AFTER 001_Schema_build.sql + 002_Master_seed_data.sql.
-- =====================================================================

-- Run from the database root folder:
--   psql "$DATABASE_URL" -f 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- (\i is a psql command; for the Supabase SQL editor use build/rt_crackers_upgrade_v2_full.sql instead.)
-- One transaction: any error rolls the whole upgrade back. It refuses to run twice.

\set ON_ERROR_STOP on

BEGIN;

\i 20_UPGRADE_V2/000_Preflight.sql
\i 20_UPGRADE_V2/001_U01_Geography.sql
\i 20_UPGRADE_V2/002_U08_Address_management.sql
\i 20_UPGRADE_V2/003_U02_Product_seo.sql
\i 20_UPGRADE_V2/004_U03_Product_audit.sql
\i 20_UPGRADE_V2/005_U04_Soft_delete.sql
\i 20_UPGRADE_V2/006_U05_User_security.sql
\i 20_UPGRADE_V2/007_U15_User_validation.sql
\i 20_UPGRADE_V2/008_U06_Inventory.sql
\i 20_UPGRADE_V2/009_U07_Order_tracking_events.sql
\i 20_UPGRADE_V2/010_U09_Analytics.sql
\i 20_UPGRADE_V2/011_U10_Review_moderation.sql
\i 20_UPGRADE_V2/012_U11_Coupons.sql
\i 20_UPGRADE_V2/013_U12_Cart_protection.sql
\i 20_UPGRADE_V2/014_U13_Wishlist_protection.sql
\i 20_UPGRADE_V2/015_U17_System_configurations.sql
\i 20_UPGRADE_V2/016_U18_Feature_flags.sql
\i 20_UPGRADE_V2/017_U19_Error_logs.sql
\i 20_UPGRADE_V2/018_U20_Audit_logs.sql
\i 20_UPGRADE_V2/019_Supporting_indexes_and_comments.sql
\i 20_UPGRADE_V2/020_Finalize.sql
\i 20_UPGRADE_V2/021_Verification.sql

COMMIT;
