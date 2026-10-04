-- =====================================================================
-- RT CRACKERS | DATABASE UPGRADE V3 (U21 - U40)            VERSION 3.0
-- Deterministic, auditable, business-rule-driven enterprise database.
--
-- RUN ORDER : base schema + seed  ->  upgrade v2  ->  THIS FILE
--             (build/rt_crackers_full.sql, build/rt_crackers_upgrade_v2_full.sql, then this file)
-- HOW       : paste the whole file into the Supabase SQL editor (or psql -f).
--             No \i includes, no psql-only syntax.
-- SAFETY    : ONE transaction (opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql or by the build file). Any error rolls everything back.
--             It refuses to run twice. Take a backup / snapshot first.
--
-- WHAT IT DOES TO EXISTING DATA
--   * orders / invoices / returns / replacements / COD receipts / referral codes that
--     already exist are RENUMBERED into the new business-code format (section U21).
--     If you already sent those numbers to customers, read section U21 before running.
--   * Status / gender / address-type CHECK lists are replaced by foreign keys to
--     master tables (U22, U23). The old CHAR columns stay (kept in sync) so existing
--     code and triggers keep working.
--
-- Section order follows dependencies, not the U-number:
--   U21 -> U22 -> U23 -> U31 -> U24 -> U25 -> U26 -> U38 -> U27/U28 -> U29 -> U30
--   -> U32 -> U33 -> U36 -> U37 -> U34 -> U35 -> U39 -> U40 -> finalize + verification
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. PRE-FLIGHT
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.postal_codes') IS NULL OR to_regclass('public.audit_logs') IS NULL THEN
        RAISE EXCEPTION 'Base schema / upgrade v2 not found. Run rt_crackers_full.sql and rt_crackers_upgrade_v2_full.sql first.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'audit_logs' AND column_name = 'action_type') THEN
        RAISE EXCEPTION 'Upgrade v2 (U20 audit logging) is not applied. Run rt_crackers_upgrade_v2_full.sql first.';
    END IF;
    IF to_regclass('public.business_code_definitions') IS NOT NULL OR to_regclass('public.business_rules') IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade v3 appears to be applied already (business_code_definitions / business_rules exist).';
    END IF;
END;
$$;

-- Backfills below must not fire audit / updated_at / status triggers (re-enabled in the finalize section).
ALTER TABLE users                 DISABLE TRIGGER USER;
ALTER TABLE orders                DISABLE TRIGGER USER;
ALTER TABLE invoices              DISABLE TRIGGER USER;
ALTER TABLE return_requests       DISABLE TRIGGER USER;
ALTER TABLE replacement_requests  DISABLE TRIGGER USER;
ALTER TABLE cod_transactions      DISABLE TRIGGER USER;
ALTER TABLE reviews               DISABLE TRIGGER USER;
ALTER TABLE shipments             DISABLE TRIGGER USER;
