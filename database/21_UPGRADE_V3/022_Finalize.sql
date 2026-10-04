-- RT CRACKERS | 21_UPGRADE_V3/022_Finalize.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- FINALIZE: re-enable triggers disabled for the backfills
-- =====================================================================
ALTER TABLE users                 ENABLE TRIGGER USER;
ALTER TABLE orders                ENABLE TRIGGER USER;
ALTER TABLE invoices              ENABLE TRIGGER USER;
ALTER TABLE return_requests       ENABLE TRIGGER USER;
ALTER TABLE replacement_requests  ENABLE TRIGGER USER;
ALTER TABLE cod_transactions      ENABLE TRIGGER USER;
ALTER TABLE reviews               ENABLE TRIGGER USER;
ALTER TABLE shipments             ENABLE TRIGGER USER;

-- =====================================================================
-- updated_at triggers + row level security for every NEW table (same rule the base schema and v2 used)
-- =====================================================================
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT c.table_name
          FROM information_schema.columns c
          JOIN information_schema.tables t
            ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
         WHERE c.table_schema = 'public' AND c.column_name = 'updated_at'
           AND NOT EXISTS (SELECT 1 FROM pg_trigger g
                            WHERE g.tgrelid = format('public.%I', c.table_name)::regclass
                              AND g.tgname = 'trg_' || c.table_name || '_updated_at')
    LOOP
        EXECUTE format('CREATE TRIGGER trg_%1$s_updated_at BEFORE UPDATE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()', r.table_name);
    END LOOP;
END;
$$;

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND NOT rowsecurity LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.tablename);
    END LOOP;
END;
$$;

INSERT INTO schema_versions (version_number, description)
VALUES ('3.0', 'Upgrade V3 (U21-U40): business codes, master tables, governance, archive, versioning, metadata');
