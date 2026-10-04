-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/020_Finalize.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | re-enable triggers, updated_at triggers, RLS for new tables
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- Re-enable triggers disabled for the backfills
-- =====================================================================
ALTER TABLE addresses  ENABLE TRIGGER USER;
ALTER TABLE users      ENABLE TRIGGER USER;
ALTER TABLE inventory  ENABLE TRIGGER USER;
ALTER TABLE reviews    ENABLE TRIGGER USER;
ALTER TABLE coupons    ENABLE TRIGGER USER;

-- =====================================================================
-- updated_at triggers + row level security for every NEW table
-- (same behaviour the base schema applied to its own tables)
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

