-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/005_U04_Soft_delete.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U4 Soft delete architecture
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 4 - SOFT DELETE ARCHITECTURE
-- A DELETE on these tables sets is_deleted instead of removing the row.
-- To really purge a row (maintenance only):  SET LOCAL app.allow_hard_delete = 'on';
-- Unique keys (email, sku, slug...) stay reserved by soft-deleted rows.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_soft_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk TEXT := TG_ARGV[0];
BEGIN
    IF COALESCE(current_setting('app.allow_hard_delete', TRUE), 'off') = 'on' THEN
        RETURN OLD;                                   -- explicit purge
    END IF;
    EXECUTE format('UPDATE %s SET is_deleted = TRUE, deleted_at = CURRENT_TIMESTAMP, deleted_by = $2 WHERE %I = ($1).%I AND NOT is_deleted',
                   TG_RELID::regclass, v_pk, v_pk)
    USING OLD, NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT;
    RETURN NULL;                                      -- cancel the physical delete
END;
$$;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT * FROM (VALUES
        ('users','user_id'), ('products','product_id'), ('orders','order_id'),
        ('categories','category_id'), ('subcategories','subcategory_id'), ('brands','brand_id'),
        ('coupons','coupon_id'), ('reviews','review_id')) AS t(tbl, pk)
    LOOP
        EXECUTE format('ALTER TABLE %I ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT FALSE, ADD COLUMN deleted_at TIMESTAMP, ADD COLUMN deleted_by BIGINT', r.tbl);
        EXECUTE format('ALTER TABLE %I ADD CONSTRAINT fk_%s_deleted_by FOREIGN KEY (deleted_by) REFERENCES users (user_id) ON DELETE SET NULL', r.tbl, r.tbl);
        EXECUTE format('ALTER TABLE %I ADD CONSTRAINT ck_%s_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))', r.tbl, r.tbl);
        EXECUTE format('CREATE INDEX idx_%s_deleted ON %I (deleted_at) WHERE is_deleted', r.tbl, r.tbl);
        EXECUTE format('CREATE INDEX idx_%s_deleted_by ON %I (deleted_by) WHERE deleted_by IS NOT NULL', r.tbl, r.tbl);
        EXECUTE format('CREATE TRIGGER trg_%s_soft_delete BEFORE DELETE ON %I FOR EACH ROW EXECUTE FUNCTION fn_soft_delete(%L)', r.tbl, r.tbl, r.pk);
    END LOOP;
END;
$$;


