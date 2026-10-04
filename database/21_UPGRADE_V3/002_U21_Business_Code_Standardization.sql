-- RT CRACKERS | 21_UPGRADE_V3/002_U21_Business_Code_Standardization.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 21 - BUSINESS CODE STANDARDIZATION
-- One generator for every business identifier. No random values.
--   PRD00000001  products          ORD2026000001  orders        INV2026000001  invoices
--   RET2026000001 returns          REP2026000001  replacements  COD2026000001  COD receipts
--   CPN000001    coupons           DOC00000001    documents     RFL00000001    referral codes
-- Counters live in business_code_counters (one row per code type and year), so a number is
-- only consumed when the surrounding transaction commits: no gaps from rolled-back inserts.
-- Trade-off: two inserts of the same code type queue behind each other until commit.
-- Security tokens (sessions, unsubscribe tokens) stay random on purpose: they are not business ids.
-- =====================================================================
CREATE TABLE business_code_definitions (
    code_type     VARCHAR(20)  NOT NULL,
    prefix        VARCHAR(5)   NOT NULL,
    include_year  BOOLEAN      NOT NULL DEFAULT FALSE,
    pad_width     SMALLINT     NOT NULL,
    description   VARCHAR(255),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_business_code_definitions PRIMARY KEY (code_type),
    CONSTRAINT uq_business_code_definitions_prefix UNIQUE (prefix),
    CONSTRAINT ck_business_code_definitions_type   CHECK (code_type = UPPER(code_type)),
    CONSTRAINT ck_business_code_definitions_prefix CHECK (prefix ~ '^[A-Z]{2,5}$'),
    CONSTRAINT ck_business_code_definitions_pad    CHECK (pad_width BETWEEN 4 AND 12)
);

CREATE TABLE business_code_counters (
    code_type   VARCHAR(20)  NOT NULL,
    period_key  VARCHAR(4)   NOT NULL,                  -- 4-digit year, or 'ALL' for codes without a year
    last_value  BIGINT       NOT NULL DEFAULT 0,
    updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_business_code_counters PRIMARY KEY (code_type, period_key),
    CONSTRAINT fk_business_code_counters_type FOREIGN KEY (code_type) REFERENCES business_code_definitions (code_type) ON DELETE RESTRICT,
    CONSTRAINT ck_business_code_counters_value  CHECK (last_value >= 0),
    CONSTRAINT ck_business_code_counters_period CHECK (period_key = 'ALL' OR period_key ~ '^[0-9]{4}$')
);

INSERT INTO business_code_definitions (code_type, prefix, include_year, pad_width, description) VALUES
    ('PRODUCT',     'PRD', FALSE, 8, 'Product SKU, e.g. PRD00000001 (admins may still type their own SKU)'),
    ('ORDER',       'ORD', TRUE,  6, 'Order number, e.g. ORD2026000001'),
    ('INVOICE',     'INV', TRUE,  6, 'Invoice number, e.g. INV2026000001'),
    ('RETURN',      'RET', TRUE,  6, 'Return request number, e.g. RET2026000001'),
    ('REPLACEMENT', 'REP', TRUE,  6, 'Replacement request number, e.g. REP2026000001'),
    ('COD_RECEIPT', 'COD', TRUE,  6, 'COD receipt number, e.g. COD2026000001'),
    ('COUPON',      'CPN', FALSE, 6, 'Coupon code when none is typed, e.g. CPN000001'),
    ('DOCUMENT',    'DOC', FALSE, 8, 'Document number, e.g. DOC00000001'),
    ('REFERRAL',    'RFL', FALSE, 8, 'User referral code, e.g. RFL00000001');

CREATE OR REPLACE FUNCTION fn_next_business_code(p_code_type TEXT, p_date DATE DEFAULT CURRENT_DATE)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    d         business_code_definitions%ROWTYPE;
    v_period  TEXT;
    v_next    BIGINT;
BEGIN
    SELECT * INTO d FROM business_code_definitions WHERE code_type = p_code_type AND is_active;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unknown or inactive business code type: %', p_code_type;
    END IF;
    v_period := CASE WHEN d.include_year THEN to_char(p_date, 'YYYY') ELSE 'ALL' END;
    INSERT INTO business_code_counters AS c (code_type, period_key, last_value)
    VALUES (d.code_type, v_period, 1)
    ON CONFLICT (code_type, period_key)
    DO UPDATE SET last_value = c.last_value + 1, updated_at = CURRENT_TIMESTAMP
    RETURNING c.last_value INTO v_next;
    IF LENGTH(v_next::TEXT) > d.pad_width THEN
        RAISE EXCEPTION 'Business code counter % / % ran out of digits (pad_width = %)', d.code_type, v_period, d.pad_width;
    END IF;
    RETURN d.prefix || CASE WHEN d.include_year THEN v_period ELSE '' END || LPAD(v_next::TEXT, d.pad_width, '0');
END;
$$;

-- ---------------------------------------------------------------------
-- Renumber existing rows (one-off helper, dropped at the end of this file).
-- Numbers are assigned in creation order (created_at, then id), restarting each year.
-- If you do NOT want existing numbers to change, delete the six fn_v3_recode(...) calls below
-- and the six ck_*_format constraints that follow them (new rows still get the new format).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_v3_recode(p_table TEXT, p_pk TEXT, p_col TEXT, p_type TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    d       business_code_definitions%ROWTYPE;
    v_rows  BIGINT;
BEGIN
    SELECT * INTO d FROM business_code_definitions WHERE code_type = p_type;
    -- step 1: park every value on a unique temporary token so renumbering can never collide
    EXECUTE format('UPDATE %I SET %I = %L || %I::TEXT', p_table, p_col, 'TMP', p_pk);
    -- step 2: final code, numbered in creation order inside each year
    EXECUTE format($q$
        UPDATE %1$I t
           SET %3$I = %4$L || CASE WHEN %5$s THEN s.yr ELSE '' END || LPAD(s.rn::TEXT, %6$s, '0')
          FROM (SELECT %2$I AS pk,
                       to_char(created_at, 'YYYY') AS yr,
                       ROW_NUMBER() OVER (PARTITION BY CASE WHEN %5$s THEN to_char(created_at, 'YYYY') ELSE 'ALL' END
                                          ORDER BY created_at, %2$I) AS rn
                  FROM %1$I) s
         WHERE t.%2$I = s.pk$q$,
        p_table, p_pk, p_col, d.prefix, d.include_year::TEXT, d.pad_width);
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    -- step 3: counters continue after the highest number issued
    EXECUTE format($q$
        INSERT INTO business_code_counters (code_type, period_key, last_value)
        SELECT %1$L,
               CASE WHEN %2$s THEN substr(%3$I, %4$s + 1, 4) ELSE 'ALL' END,
               MAX(substr(%3$I, %4$s + %5$s + 1)::BIGINT)
          FROM %6$I
         GROUP BY 2
        ON CONFLICT (code_type, period_key)
        DO UPDATE SET last_value = GREATEST(business_code_counters.last_value, EXCLUDED.last_value)$q$,
        p_type, d.include_year::TEXT, p_col, LENGTH(d.prefix), CASE WHEN d.include_year THEN 4 ELSE 0 END, p_table);
    RETURN v_rows;
END;
$$;

SELECT fn_v3_recode('orders',               'order_id',               'order_number',       'ORDER');
SELECT fn_v3_recode('invoices',             'invoice_id',             'invoice_number',     'INVOICE');
SELECT fn_v3_recode('return_requests',      'return_request_id',      'return_number',      'RETURN');
SELECT fn_v3_recode('replacement_requests', 'replacement_request_id', 'replacement_number', 'REPLACEMENT');
SELECT fn_v3_recode('cod_transactions',     'cod_transaction_id',     'receipt_number',     'COD_RECEIPT');
SELECT fn_v3_recode('users',                'user_id',                'referral_code',      'REFERRAL');

-- New rows: structured defaults replace the date + sequence and MD5(RANDOM()) defaults
ALTER TABLE orders               ALTER COLUMN order_number       SET DEFAULT fn_next_business_code('ORDER');
ALTER TABLE invoices             ALTER COLUMN invoice_number     SET DEFAULT fn_next_business_code('INVOICE');
ALTER TABLE return_requests      ALTER COLUMN return_number      SET DEFAULT fn_next_business_code('RETURN');
ALTER TABLE replacement_requests ALTER COLUMN replacement_number SET DEFAULT fn_next_business_code('REPLACEMENT');
ALTER TABLE cod_transactions     ALTER COLUMN receipt_number     SET DEFAULT fn_next_business_code('COD_RECEIPT');
ALTER TABLE users                ALTER COLUMN referral_code      SET DEFAULT fn_next_business_code('REFERRAL');
ALTER TABLE products             ALTER COLUMN sku                SET DEFAULT fn_next_business_code('PRODUCT');
ALTER TABLE coupons              ALTER COLUMN coupon_code        SET DEFAULT fn_next_business_code('COUPON');

-- Formats are enforced so nobody can sneak a hand-typed number into a system-generated column
ALTER TABLE orders               ADD CONSTRAINT ck_orders_number_format       CHECK (order_number       ~ '^ORD[0-9]{10}$');
ALTER TABLE invoices             ADD CONSTRAINT ck_invoices_number_format     CHECK (invoice_number     ~ '^INV[0-9]{10}$');
ALTER TABLE return_requests      ADD CONSTRAINT ck_return_requests_number_fmt CHECK (return_number      ~ '^RET[0-9]{10}$');
ALTER TABLE replacement_requests ADD CONSTRAINT ck_replacement_requests_number_fmt CHECK (replacement_number ~ '^REP[0-9]{10}$');
ALTER TABLE cod_transactions     ADD CONSTRAINT ck_cod_transactions_receipt_fmt CHECK (receipt_number   ~ '^COD[0-9]{10}$');
ALTER TABLE users                ADD CONSTRAINT ck_users_referral_code_format CHECK (referral_code      ~ '^RFL[0-9]{8}$');

-- The old date + sequence generators are no longer used by any default.
-- Optional cleanup once you are sure no application code calls them:
--   DROP SEQUENCE seq_order_number, seq_invoice_number, seq_return_number, seq_replacement_number, seq_cod_receipt;
