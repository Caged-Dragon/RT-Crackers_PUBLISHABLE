-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/005_Audit_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- audit_logs | Purpose: row-level change history (before/after JSON) written by trigger.
-- Keys : PK(audit_log_id)
-- Rel  : N:1 users (optional)
-- BCNF : attributes describe one change.
-- ---------------------------------------------------------------------
CREATE TABLE audit_logs (
    audit_log_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    table_name    VARCHAR(63)   NOT NULL,
    record_id     VARCHAR(64)   NOT NULL,
    action        CHAR(1)       NOT NULL,                     -- I insert, U update, D delete
    old_data      JSONB,
    new_data      JSONB,
    changed_by    BIGINT,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_audit_logs PRIMARY KEY (audit_log_id),
    CONSTRAINT fk_audit_logs_user FOREIGN KEY (changed_by) REFERENCES users (user_id) ON DELETE SET NULL,
    CONSTRAINT ck_audit_logs_action CHECK (action IN ('I','U','D'))
);

-- generic row-level audit trail (argument = primary key column name)
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk  TEXT := TG_ARGV[0];
    v_old JSONB;
    v_new JSONB;
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN v_old := to_jsonb(OLD); END IF;
    IF TG_OP IN ('INSERT','UPDATE') THEN v_new := to_jsonb(NEW); END IF;
    INSERT INTO audit_logs (table_name, record_id, action, old_data, new_data, changed_by)
    VALUES (TG_TABLE_NAME, COALESCE(v_new ->> v_pk, v_old ->> v_pk), LEFT(TG_OP, 1), v_old, v_new,
            NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT);
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_products_audit         AFTER INSERT OR UPDATE OR DELETE ON products         FOR EACH ROW EXECUTE FUNCTION fn_audit_log('product_id');
CREATE TRIGGER trg_orders_audit           AFTER INSERT OR UPDATE OR DELETE ON orders           FOR EACH ROW EXECUTE FUNCTION fn_audit_log('order_id');
CREATE TRIGGER trg_coupons_audit          AFTER INSERT OR UPDATE OR DELETE ON coupons          FOR EACH ROW EXECUTE FUNCTION fn_audit_log('coupon_id');
CREATE TRIGGER trg_settings_audit         AFTER INSERT OR UPDATE OR DELETE ON settings         FOR EACH ROW EXECUTE FUNCTION fn_audit_log('setting_id');
CREATE TRIGGER trg_payment_methods_audit  AFTER INSERT OR UPDATE OR DELETE ON payment_methods  FOR EACH ROW EXECUTE FUNCTION fn_audit_log('payment_method_id');
