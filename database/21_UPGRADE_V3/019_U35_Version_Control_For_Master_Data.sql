-- RT CRACKERS | 21_UPGRADE_V3/019_U35_Version_Control_For_Master_Data.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 35 - VERSION CONTROL FOR MASTER DATA
-- Every change to a master-data row writes a full snapshot with the next version number.
-- Version 1 is the row as it is when this upgrade runs. Changes that touch only updated_at /
-- updated_by are ignored. Encrypted configuration values are never copied into a snapshot.
--   SELECT * FROM entity_versions WHERE entity_name = 'brands' AND entity_id = '3' ORDER BY version_number;
-- =====================================================================
CREATE TABLE entity_versions (
    entity_version_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    entity_name        VARCHAR(63)   NOT NULL,
    entity_id          VARCHAR(64)   NOT NULL,
    version_number     INTEGER       NOT NULL,
    change_type        CHAR(1)       NOT NULL,                 -- I insert / baseline, U update, D delete
    change_date        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by         BIGINT,
    changed_columns    TEXT[],
    entity_snapshot    JSONB         NOT NULL,
    CONSTRAINT pk_entity_versions PRIMARY KEY (entity_version_id),
    CONSTRAINT uq_entity_versions_version UNIQUE (entity_name, entity_id, version_number),
    CONSTRAINT fk_entity_versions_changed_by FOREIGN KEY (changed_by) REFERENCES users (user_id) ON DELETE SET NULL,
    CONSTRAINT ck_entity_versions_number CHECK (version_number >= 1),
    CONSTRAINT ck_entity_versions_type   CHECK (change_type IN ('I','U','D'))
);
CREATE INDEX idx_entity_versions_changed_by ON entity_versions (changed_by) WHERE changed_by IS NOT NULL;
CREATE INDEX idx_entity_versions_date       ON entity_versions (change_date DESC);

CREATE OR REPLACE FUNCTION fn_entity_version()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk       TEXT := TG_ARGV[0];
    v_row      JSONB;
    v_old      JSONB;
    v_id       TEXT;
    v_ver      INTEGER;
    v_changed  TEXT[];
BEGIN
    v_row := to_jsonb(CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END);
    v_id  := v_row ->> v_pk;
    IF TG_OP = 'UPDATE' THEN
        v_old := to_jsonb(OLD);
        IF (v_row - ARRAY['updated_at','updated_by']) = (v_old - ARRAY['updated_at','updated_by']) THEN
            RETURN NULL;                                       -- nothing but bookkeeping changed
        END IF;
        SELECT ARRAY_AGG(k ORDER BY k) INTO v_changed
          FROM jsonb_object_keys(v_row) k
         WHERE k NOT IN ('updated_at','updated_by') AND (v_row -> k) IS DISTINCT FROM (v_old -> k);
    END IF;
    IF COALESCE((v_row ->> 'is_encrypted')::BOOLEAN, FALSE) THEN
        v_row := v_row - 'config_value';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(TG_TABLE_NAME || ':' || v_id, 0));
    SELECT COALESCE(MAX(version_number), 0) + 1 INTO v_ver FROM entity_versions WHERE entity_name = TG_TABLE_NAME AND entity_id = v_id;
    INSERT INTO entity_versions (entity_name, entity_id, version_number, change_type, changed_by, changed_columns, entity_snapshot)
    VALUES (TG_TABLE_NAME, v_id, v_ver, LEFT(TG_OP, 1), NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT, v_changed, v_row);
    RETURN NULL;
END;
$$;

-- baseline (version 1) + trigger for every master-data table; the primary key column is looked up, not guessed
DO $$
DECLARE
    t   TEXT;
    pk  TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'categories','subcategories','brands','payment_methods','shipping_methods','delivery_zones',
        'system_configurations','settings','feature_flags','business_rules','country_configurations',
        'product_types','collections','seasons','reference_data','genders','address_types',
        'order_status_master','payment_status_master','shipment_status_master','review_status_master','user_status_master',
        'business_code_definitions','data_retention_policies','data_quality_rules','data_classification',
        'document_types','search_synonyms','search_redirects'] LOOP
        SELECT a.attname INTO pk
          FROM pg_index i JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
         WHERE i.indrelid = format('public.%I', t)::regclass AND i.indisprimary AND i.indnatts = 1;
        IF pk IS NULL THEN RAISE EXCEPTION 'Table % has no single-column primary key: cannot version it', t; END IF;
        EXECUTE format($q$
            INSERT INTO entity_versions (entity_name, entity_id, version_number, change_type, entity_snapshot)
            SELECT %1$L, to_jsonb(x) ->> %2$L, 1, 'I',
                   CASE WHEN COALESCE((to_jsonb(x) ->> 'is_encrypted')::BOOLEAN, FALSE) THEN to_jsonb(x) - 'config_value' ELSE to_jsonb(x) END
              FROM %1$I x$q$, t, pk);
        EXECUTE format('CREATE TRIGGER trg_%1$s_version AFTER INSERT OR UPDATE OR DELETE ON %1$I FOR EACH ROW EXECUTE FUNCTION fn_entity_version(%2$L)', t, pk);
    END LOOP;
END;
$$;
