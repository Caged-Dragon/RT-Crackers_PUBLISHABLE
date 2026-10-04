-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/004_U03_Product_audit.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U3 Product audit tracking
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 3 - PRODUCT AUDIT TRACKING
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_audit_logs | Purpose: one row per changed field on every product UPDATE.
-- Keys : PK(audit_id)
-- Rel  : N:1 products, N:1 users (who changed it)
-- BCNF : attributes describe a single field change.
-- Notes: set  SET LOCAL app.current_user_id = '<user_id>'  and  app.change_reason = '<text>'  in the
--        transaction to record who/why. updated_at, view_count, discount_percentage are not logged.
-- ---------------------------------------------------------------------
CREATE TABLE product_audit_logs (
    audit_id       BIGINT        GENERATED ALWAYS AS IDENTITY,
    product_id     BIGINT        NOT NULL,
    field_name     VARCHAR(63)   NOT NULL,
    old_value      TEXT,
    new_value      TEXT,
    changed_by     BIGINT,
    change_reason  VARCHAR(255),
    changed_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_audit_logs PRIMARY KEY (audit_id),
    CONSTRAINT fk_product_audit_logs_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT,
    CONSTRAINT fk_product_audit_logs_user    FOREIGN KEY (changed_by) REFERENCES users (user_id)       ON DELETE SET NULL,
    CONSTRAINT ck_product_audit_logs_field   CHECK (BTRIM(field_name) <> ''),
    CONSTRAINT ck_product_audit_logs_changed CHECK (old_value IS DISTINCT FROM new_value)
);
CREATE INDEX idx_product_audit_logs_product ON product_audit_logs (product_id, changed_at DESC);
CREATE INDEX idx_product_audit_logs_field   ON product_audit_logs (field_name, changed_at DESC);
CREATE INDEX idx_product_audit_logs_user    ON product_audit_logs (changed_by) WHERE changed_by IS NOT NULL;

CREATE OR REPLACE FUNCTION fn_log_product_changes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_old    JSONB := to_jsonb(OLD);
    v_new    JSONB := to_jsonb(NEW);
    v_key    TEXT;
    v_by     BIGINT := NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT;
    v_reason TEXT   := LEFT(NULLIF(current_setting('app.change_reason', TRUE), ''), 255);
BEGIN
    FOR v_key IN SELECT jsonb_object_keys(v_new) LOOP
        CONTINUE WHEN v_key IN ('updated_at', 'view_count', 'discount_percentage');
        IF v_old -> v_key IS DISTINCT FROM v_new -> v_key THEN
            INSERT INTO product_audit_logs (product_id, field_name, old_value, new_value, changed_by, change_reason)
            VALUES (NEW.product_id, v_key, v_old ->> v_key, v_new ->> v_key, v_by, v_reason);
        END IF;
    END LOOP;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_products_field_audit AFTER UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION fn_log_product_changes();

