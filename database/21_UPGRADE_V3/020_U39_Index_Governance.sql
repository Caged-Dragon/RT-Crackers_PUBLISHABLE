-- RT CRACKERS | 21_UPGRADE_V3/020_U39_Index_Governance.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 39 - INDEX GOVERNANCE
-- The index documentation is generated from the live catalog, so it can never go stale:
--   v_index_governance   every index with its kind: PRIMARY, UNIQUE, FOREIGN KEY, COMPOSITE, PARTIAL, STANDARD
--   v_missing_fk_indexes foreign keys with no index leading with the FK columns (slow joins / slow parent deletes)
-- Review both after every upgrade:  SELECT * FROM v_missing_fk_indexes;
-- =====================================================================
CREATE VIEW v_index_governance WITH (security_invoker = true) AS
WITH fk AS (
    SELECT c.conrelid, c.conkey FROM pg_constraint c WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace
)
SELECT t.relname                                                    AS table_name,
       i.relname                                                    AS index_name,
       CASE WHEN x.indisprimary THEN 'PRIMARY'
            WHEN x.indisunique  THEN 'UNIQUE'
            WHEN EXISTS (SELECT 1 FROM fk WHERE fk.conrelid = x.indrelid
                            AND (string_to_array(x.indkey::TEXT, ' ')::INT2[])[1:cardinality(fk.conkey)] @> fk.conkey
                            AND fk.conkey @> (string_to_array(x.indkey::TEXT, ' ')::INT2[])[1:cardinality(fk.conkey)]) THEN 'FOREIGN KEY'
            WHEN x.indnkeyatts > 1 THEN 'COMPOSITE'
            WHEN x.indpred IS NOT NULL THEN 'PARTIAL'
            ELSE 'STANDARD' END                                     AS index_kind,
       x.indnkeyatts                                                AS column_count,
       (SELECT STRING_AGG(COALESCE(a.attname, '(expression)'), ', ' ORDER BY k.ord)
          FROM UNNEST(string_to_array(x.indkey::TEXT, ' ')::INT2[]) WITH ORDINALITY k(attnum, ord)
          LEFT JOIN pg_attribute a ON a.attrelid = x.indrelid AND a.attnum = k.attnum
         WHERE k.ord <= x.indnkeyatts)                              AS columns,
       x.indisunique                                                AS is_unique,
       (x.indpred IS NOT NULL)                                      AS is_partial,
       pg_size_pretty(pg_relation_size(x.indexrelid))               AS index_size
  FROM pg_index x
  JOIN pg_class i ON i.oid = x.indexrelid
  JOIN pg_class t ON t.oid = x.indrelid
 WHERE t.relnamespace = 'public'::regnamespace AND t.relkind = 'r';

CREATE VIEW v_missing_fk_indexes WITH (security_invoker = true) AS
SELECT c.conrelid::REGCLASS::TEXT AS table_name,
       c.conname                  AS constraint_name,
       (SELECT STRING_AGG(a.attname, ', ' ORDER BY k.ord)
          FROM UNNEST(c.conkey) WITH ORDINALITY k(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum) AS fk_columns,
       c.confrelid::REGCLASS::TEXT AS references_table
  FROM pg_constraint c
 WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace
   AND NOT EXISTS (
        SELECT 1 FROM pg_index x
         WHERE x.indrelid = c.conrelid AND x.indisvalid
           AND (string_to_array(x.indkey::TEXT, ' ')::INT2[])[1:cardinality(c.conkey)] @> c.conkey
           AND c.conkey @> (string_to_array(x.indkey::TEXT, ' ')::INT2[])[1:cardinality(c.conkey)]);

-- index every foreign key this upgrade created (except the ownership columns, see U34)
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT m.table_name, m.constraint_name, m.fk_columns FROM v_missing_fk_indexes m
              WHERE m.table_name = ANY (ARRAY[
                    'schema_versions','business_code_counters','archived_orders','archived_logs','archived_notifications','archive_runs',
                    'country_configurations','search_keywords','search_synonyms','search_redirects','data_quality_results',
                    'data_classification_assignments','documents','document_links','product_collections','product_seasons',
                    'entity_versions','system_health_checks','orders','reviews','users','shipments','products'])
                AND m.fk_columns NOT IN ('created_by','updated_by')
                AND m.fk_columns !~ '^(created_by|updated_by)$' LOOP
        EXECUTE format('CREATE INDEX idx_%s_fk_%s ON %I (%s)', r.table_name,
                       SUBSTR(regexp_replace(r.constraint_name, '^fk_' || r.table_name || '_', ''), 1, 30),
                       r.table_name, r.fk_columns);
    END LOOP;
END;
$$;
