-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/099_Cleanup_failed_run.sql
-- NOT part of the upgrade run. Use only after a failed run (see notes below).
-- =====================================================================

-- Run ONLY if a previous run of rt_crackers_upgrade_v2.sql failed AND left things behind
-- (check first:  SELECT to_regclass('public.postal_codes');  -- NULL means nothing was left, skip this file).
-- Safe to run: it only touches objects the failed run created.
BEGIN;
-- the upgrade disables these triggers for its backfills; make sure they are on
ALTER TABLE addresses ENABLE TRIGGER USER;
ALTER TABLE users     ENABLE TRIGGER USER;
ALTER TABLE inventory ENABLE TRIGGER USER;
ALTER TABLE reviews   ENABLE TRIGGER USER;
ALTER TABLE coupons   ENABLE TRIGGER USER;
-- only valid if the failed run stopped inside the geography step (pincodes still exists)
DO $$
BEGIN
    IF to_regclass('public.pincodes') IS NULL THEN
        RAISE EXCEPTION 'pincodes is gone: the upgrade went further than the geography step. Restore your backup instead of running this cleanup.';
    END IF;
END;
$$;
DROP TABLE IF EXISTS upg_v2_pin_city;
DROP TABLE IF EXISTS postal_codes CASCADE;
DROP TABLE IF EXISTS cities CASCADE;
DROP TABLE IF EXISTS districts CASCADE;
DROP TABLE IF EXISTS states CASCADE;
DROP TABLE IF EXISTS countries CASCADE;
COMMIT;
