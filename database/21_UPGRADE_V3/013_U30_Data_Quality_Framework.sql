-- RT CRACKERS | 21_UPGRADE_V3/013_U30_Data_Quality_Framework.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 30 - DATA QUALITY FRAMEWORK
-- validation_logic is a SQL condition that every row of entity_name must satisfy.
-- fn_run_data_quality_checks() counts the rows that do not, and stores the result.
-- Rules are written by database administrators only (the table is not exposed through the API).
-- =====================================================================
CREATE TABLE data_quality_rules (
    rule_id           INTEGER       GENERATED ALWAYS AS IDENTITY,
    rule_name         VARCHAR(100)  NOT NULL,
    entity_name       VARCHAR(63)   NOT NULL,
    validation_logic  TEXT          NOT NULL,
    severity          CHAR(1)       NOT NULL DEFAULT 'E',     -- W warning, E error, C critical
    description       VARCHAR(255),
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_data_quality_rules PRIMARY KEY (rule_id),
    CONSTRAINT uq_data_quality_rules_name UNIQUE (rule_name),
    CONSTRAINT ck_data_quality_rules_severity CHECK (severity IN ('W','E','C')),
    CONSTRAINT ck_data_quality_rules_logic    CHECK (BTRIM(validation_logic) <> '' AND validation_logic !~ '(;|--|/\*)')
);

CREATE TABLE data_quality_results (
    result_id        BIGINT       GENERATED ALWAYS AS IDENTITY,
    rule_id          INTEGER      NOT NULL,
    run_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    violation_count  BIGINT       NOT NULL DEFAULT 0,
    result_status    CHAR(1)      NOT NULL,                   -- P pass, F fail, E rule could not run
    error_message    VARCHAR(500),
    CONSTRAINT pk_data_quality_results PRIMARY KEY (result_id),
    CONSTRAINT fk_data_quality_results_rule FOREIGN KEY (rule_id) REFERENCES data_quality_rules (rule_id) ON DELETE CASCADE,
    CONSTRAINT ck_data_quality_results_status CHECK (result_status IN ('P','F','E')),
    CONSTRAINT ck_data_quality_results_count  CHECK (violation_count >= 0)
);
CREATE INDEX idx_data_quality_results_rule ON data_quality_results (rule_id, run_at DESC);

INSERT INTO data_quality_rules (rule_name, entity_name, validation_logic, severity, description) VALUES
    ('product_price_not_above_mrp',    'products',   'selling_price <= mrp',                                   'E', 'Selling price must not exceed MRP'),
    ('product_gst_standard_slab',      'products',   'gst_percentage IN (0, 5, 12, 18, 28)',                   'W', 'GST rate should be a standard slab'),
    ('active_product_has_image',       'products',   'status <> ''A'' OR is_deleted OR EXISTS (SELECT 1 FROM product_images i WHERE i.product_id = products.product_id)', 'W', 'Active products need at least one image'),
    ('user_email_lower_case',          'users',      'email = LOWER(email)',                                   'E', 'E-mail addresses are stored lower case'),
    ('user_phone_indian_mobile',       'users',      'phone ~ ''^[6-9][0-9]{9}$''',                            'E', '10-digit Indian mobile number'),
    ('address_phone_indian_mobile',    'addresses',  'recipient_phone ~ ''^[6-9][0-9]{9}$''',                  'E', '10-digit Indian mobile number'),
    ('inventory_reserved_within_stock','inventory',  'reserved_stock <= quantity_on_hand',                     'C', 'Reserved stock cannot exceed stock on hand'),
    ('coupon_validity_window',         'coupons',    'valid_to > valid_from',                                  'E', 'Coupon must end after it starts'),
    ('review_rating_range',            'reviews',    'rating BETWEEN 1 AND 5',                                 'E', 'Ratings are 1 to 5'),
    ('delivered_order_has_date',       'orders',     'order_status <> ''D'' OR delivery_date IS NOT NULL',     'E', 'Delivered orders carry a delivery date'),
    ('delivered_order_has_invoice',    'orders',     'order_status <> ''D'' OR EXISTS (SELECT 1 FROM invoices v WHERE v.order_id = orders.order_id)', 'W', 'Delivered orders should have an invoice');

CREATE OR REPLACE FUNCTION fn_run_data_quality_checks(p_rule_id INTEGER DEFAULT NULL)
RETURNS TABLE (rule_name TEXT, entity_name TEXT, severity CHAR(1), violation_count BIGINT, result_status CHAR(1))
LANGUAGE plpgsql AS $$
DECLARE
    r      RECORD;
    v_cnt  BIGINT;
    v_st   CHAR(1);
    v_err  TEXT;
BEGIN
    FOR r IN SELECT q.* FROM data_quality_rules q WHERE q.is_active AND (p_rule_id IS NULL OR q.rule_id = p_rule_id) ORDER BY q.rule_id LOOP
        v_cnt := 0; v_err := NULL;
        BEGIN
            IF to_regclass(format('public.%I', r.entity_name)) IS NULL THEN
                RAISE EXCEPTION 'table % does not exist', r.entity_name;
            END IF;
            -- rows where the condition is FALSE are violations; unknown (NULL) is not treated as invalid
            EXECUTE format('SELECT COUNT(*) FROM public.%I WHERE NOT COALESCE((%s), TRUE)', r.entity_name, r.validation_logic) INTO v_cnt;
            v_st := CASE WHEN v_cnt = 0 THEN 'P' ELSE 'F' END;
        EXCEPTION WHEN OTHERS THEN
            v_st := 'E'; v_cnt := 0; v_err := LEFT(SQLERRM, 500);
        END;
        INSERT INTO data_quality_results (rule_id, violation_count, result_status, error_message) VALUES (r.rule_id, v_cnt, v_st, v_err);
        rule_name := r.rule_name; entity_name := r.entity_name; severity := r.severity; violation_count := v_cnt; result_status := v_st;
        RETURN NEXT;
    END LOOP;
END;
$$;
