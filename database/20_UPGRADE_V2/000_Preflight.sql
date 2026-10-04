-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/000_Preflight.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | Pre-flight checks, disable USER triggers for backfills
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. PRE-FLIGHT
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.pincodes') IS NULL OR to_regclass('public.addresses') IS NULL THEN
        RAISE EXCEPTION 'Base schema not found: run rt_crackers_schema.sql first.';
    END IF;
    IF to_regclass('public.upg_v2_pin_city') IS NOT NULL THEN
        RAISE EXCEPTION 'A previous upgrade run stopped halfway (staging table upg_v2_pin_city exists). Clean up first, see the notes at the top of rt_crackers_upgrade_v2_cleanup.sql.';
    END IF;
    IF to_regclass('public.postal_codes') IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade v2 appears to be applied already (postal_codes exists).';
    END IF;
END;
$$;

-- Backfills below must not fire audit / updated_at triggers.
ALTER TABLE addresses  DISABLE TRIGGER USER;
ALTER TABLE users      DISABLE TRIGGER USER;
ALTER TABLE inventory  DISABLE TRIGGER USER;
ALTER TABLE reviews    DISABLE TRIGGER USER;
ALTER TABLE coupons    DISABLE TRIGGER USER;

