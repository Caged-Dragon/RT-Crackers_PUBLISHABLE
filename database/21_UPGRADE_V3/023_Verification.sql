-- RT CRACKERS | 21_UPGRADE_V3/023_Verification.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- VERIFICATION  (any miss aborts and rolls back the whole upgrade)
-- =====================================================================
DO $$
DECLARE
    v_missing TEXT;
    v_tables  INTEGER;
    v_fks     INTEGER;
    v_cons    INTEGER;
    v_cols    INTEGER;
BEGIN
    -- every table the upgrade promises
    SELECT string_agg(req.name, ', ') INTO v_missing
      FROM (VALUES
        ('business_code_definitions'), ('business_code_counters'), ('order_status_master'), ('payment_status_master'),
        ('shipment_status_master'), ('review_status_master'), ('user_status_master'), ('genders'), ('address_types'),
        ('business_rules'), ('country_configurations'), ('product_types'), ('collections'), ('seasons'),
        ('data_retention_policies'), ('archived_orders'), ('archived_logs'), ('archived_notifications'),
        ('search_keywords'), ('search_synonyms'), ('search_redirects'), ('data_quality_rules'), ('reference_data'),
        ('entity_versions'), ('documents'), ('document_types'), ('document_links'), ('system_health_checks'),
        ('data_classification'), ('database_metadata')
      ) AS req(name)
     WHERE to_regclass('public.' || req.name) IS NULL;
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, missing tables: %', v_missing;
    END IF;

    -- U33 audit columns
    SELECT string_agg(req.name, ', ') INTO v_missing
      FROM (VALUES ('session_id'), ('device_type'), ('browser'), ('operating_system'), ('country'), ('city')) AS req(name)
     WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns
                        WHERE table_schema = 'public' AND table_name = 'audit_logs' AND column_name = req.name);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, audit_logs is missing columns: %', v_missing;
    END IF;

    -- U22/U23 status and lookup foreign keys
    SELECT string_agg(req.name, ', ') INTO v_missing
      FROM (VALUES ('fk_users_gender'), ('fk_addresses_address_label')) AS req(name)
     WHERE NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conname = req.name);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, missing constraints: %', v_missing;
    END IF;

    -- U40: nothing left undocumented, nothing documented that does not exist
    SELECT string_agg(table_name, ', ') INTO v_missing FROM v_undocumented_tables;
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, tables missing from database_metadata: %', v_missing;
    END IF;
    SELECT string_agg(table_name, ', ') INTO v_missing FROM v_stale_metadata;
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, database_metadata lists tables that do not exist: %', v_missing;
    END IF;

    -- U39: every foreign key has a supporting index, except the ownership columns left unindexed on purpose (U34)
    SELECT string_agg(table_name || '.' || fk_columns, ', ') INTO v_missing
      FROM v_missing_fk_indexes WHERE fk_columns !~ '^(created_by|updated_by|deleted_by)$' AND table_name IN (
            SELECT tablename FROM pg_tables WHERE schemaname = 'public'
               AND tablename IN (SELECT table_name FROM database_metadata WHERE module = 'GOVERNANCE'));
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, unindexed foreign keys on new governance tables: %', v_missing;
    END IF;

    -- row level security everywhere
    SELECT string_agg(tablename, ', ') INTO v_missing FROM pg_tables WHERE schemaname = 'public' AND NOT rowsecurity;
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, row level security is off for: %', v_missing;
    END IF;

    SELECT COUNT(*) INTO v_tables FROM pg_tables WHERE schemaname = 'public';
    SELECT COUNT(*) INTO v_fks    FROM pg_constraint c WHERE c.connamespace = 'public'::regnamespace AND c.contype = 'f';
    SELECT COUNT(*) INTO v_cons   FROM pg_constraint c WHERE c.connamespace = 'public'::regnamespace AND c.contype IN ('p','f','u','c');
    SELECT COUNT(*) INTO v_cols   FROM information_schema.columns
                                   WHERE table_schema = 'public' AND table_name IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public');
    RAISE NOTICE 'RT Crackers upgrade V3 OK: % tables, % columns, % foreign keys, % constraints (PK/FK/UNIQUE/CHECK)',
                 v_tables, v_cols, v_fks, v_cons;
END;
$$;
