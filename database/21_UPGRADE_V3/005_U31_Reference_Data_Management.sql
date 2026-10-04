-- RT CRACKERS | 21_UPGRADE_V3/005_U31_Reference_Data_Management.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 31 - REFERENCE DATA MANAGEMENT
-- One place for lookup values that do not need a table of their own.
-- v_reference_lookup presents these together with the dedicated reference / status tables.
-- =====================================================================
CREATE TABLE reference_data (
    reference_id  INTEGER       GENERATED ALWAYS AS IDENTITY,
    ref_group     VARCHAR(30)   NOT NULL,
    ref_code      VARCHAR(20)   NOT NULL,
    ref_name      VARCHAR(100)  NOT NULL,
    description   VARCHAR(255),
    sort_order    SMALLINT      NOT NULL DEFAULT 0,
    metadata      JSONB,
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_reference_data PRIMARY KEY (reference_id),
    CONSTRAINT uq_reference_data_group_code UNIQUE (ref_group, ref_code),
    CONSTRAINT ck_reference_data_group CHECK (ref_group ~ '^[A-Z][A-Z_]*$'),
    CONSTRAINT ck_reference_data_code  CHECK (BTRIM(ref_code) <> ''),
    CONSTRAINT ck_reference_data_meta  CHECK (metadata IS NULL OR jsonb_typeof(metadata) = 'object')
);

INSERT INTO reference_data (ref_group, ref_code, ref_name, sort_order, metadata) VALUES
    ('LANGUAGE', 'en', 'English',   1, '{"native_name":"English"}'),
    ('LANGUAGE', 'ta', 'Tamil',     2, '{"native_name":"தமிழ்"}'),
    ('LANGUAGE', 'hi', 'Hindi',     3, '{"native_name":"हिन्दी"}'),
    ('LANGUAGE', 'te', 'Telugu',    4, '{"native_name":"తెలుగు"}'),
    ('LANGUAGE', 'ml', 'Malayalam', 5, '{"native_name":"മലയാളം"}'),
    ('LANGUAGE', 'kn', 'Kannada',   6, '{"native_name":"ಕನ್ನಡ"}'),
    ('CURRENCY', 'INR', 'Indian Rupee',     1, '{"symbol":"₹","decimals":2}'),
    ('CURRENCY', 'USD', 'US Dollar',        2, '{"symbol":"$","decimals":2}'),
    ('CURRENCY', 'EUR', 'Euro',             3, '{"symbol":"€","decimals":2}'),
    ('CURRENCY', 'GBP', 'Pound Sterling',   4, '{"symbol":"£","decimals":2}'),
    ('CURRENCY', 'AED', 'UAE Dirham',       5, '{"symbol":"د.إ","decimals":2}'),
    ('DEVICE_TYPE', 'W', 'Web',     1, NULL),
    ('DEVICE_TYPE', 'M', 'Mobile',  2, NULL),
    ('DEVICE_TYPE', 'T', 'Tablet',  3, NULL),
    ('DEVICE_TYPE', 'O', 'Other',   4, NULL),
    ('NOTIFICATION_CHANNEL', 'A', 'In-app',   1, NULL),
    ('NOTIFICATION_CHANNEL', 'E', 'E-mail',   2, NULL),
    ('NOTIFICATION_CHANNEL', 'S', 'SMS',      3, NULL),
    ('NOTIFICATION_CHANNEL', 'W', 'WhatsApp', 4, NULL),
    ('RETURN_REASON', 'D', 'Damaged',     1, NULL),
    ('RETURN_REASON', 'W', 'Wrong item',  2, NULL),
    ('RETURN_REASON', 'Q', 'Quality',     3, NULL),
    ('RETURN_REASON', 'M', 'Missing',     4, NULL),
    ('RETURN_REASON', 'O', 'Other',       5, NULL),
    ('REFUND_METHOD', 'B', 'Bank transfer', 1, NULL),
    ('REFUND_METHOD', 'C', 'Cash',          2, NULL);

-- users.preferred_language / preferred_currency must exist in reference_data (works for any group)
CREATE OR REPLACE FUNCTION fn_validate_reference()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_col    TEXT := TG_ARGV[0];
    v_group  TEXT := TG_ARGV[1];
    v_val    TEXT := to_jsonb(NEW) ->> v_col;
BEGIN
    IF v_val IS NULL THEN RETURN NEW; END IF;
    IF TG_OP = 'UPDATE' AND v_val IS NOT DISTINCT FROM (to_jsonb(OLD) ->> v_col) THEN RETURN NEW; END IF;
    IF NOT EXISTS (SELECT 1 FROM reference_data WHERE ref_group = v_group AND ref_code = BTRIM(v_val) AND is_active) THEN
        RAISE EXCEPTION '% "%" is not an active % in reference_data', v_col, v_val, v_group
            USING ERRCODE = 'foreign_key_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_users_ref_language BEFORE INSERT OR UPDATE OF preferred_language ON users
    FOR EACH ROW EXECUTE FUNCTION fn_validate_reference('preferred_language', 'LANGUAGE');
CREATE TRIGGER trg_users_ref_currency BEFORE INSERT OR UPDATE OF preferred_currency ON users
    FOR EACH ROW EXECUTE FUNCTION fn_validate_reference('preferred_currency', 'CURRENCY');

CREATE VIEW v_reference_lookup WITH (security_invoker = true) AS
    SELECT ref_group, ref_code, ref_name, sort_order, is_active, 'reference_data' AS source_table FROM reference_data
    UNION ALL SELECT 'GENDER',          gender_code,       gender_name,       sort_order, is_active, 'genders'        FROM genders
    UNION ALL SELECT 'ADDRESS_TYPE',    address_type_code, address_type_name, sort_order, is_active, 'address_types'  FROM address_types
    UNION ALL SELECT 'ORDER_STATUS',    status_code, status_name, sort_order, is_active, 'order_status_master'    FROM order_status_master
    UNION ALL SELECT 'PAYMENT_STATUS',  status_code, status_name, sort_order, is_active, 'payment_status_master'  FROM payment_status_master
    UNION ALL SELECT 'SHIPMENT_STATUS', status_code, status_name, sort_order, is_active, 'shipment_status_master' FROM shipment_status_master
    UNION ALL SELECT 'REVIEW_STATUS',   status_code, status_name, sort_order, is_active, 'review_status_master'   FROM review_status_master
    UNION ALL SELECT 'USER_STATUS',     status_code, status_name, sort_order, is_active, 'user_status_master'     FROM user_status_master;
