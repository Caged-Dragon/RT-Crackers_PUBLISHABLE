BEGIN;

-- =====================================================================
-- RT CRACKERS | DATABASE UPGRADE V3 (U21 - U40)            VERSION 3.0
-- Deterministic, auditable, business-rule-driven enterprise database.
--
-- RUN ORDER : base schema + seed  ->  upgrade v2  ->  THIS FILE
--             (build/rt_crackers_full.sql, build/rt_crackers_upgrade_v2_full.sql, then this file)
-- HOW       : paste the whole file into the Supabase SQL editor (or psql -f).
--             No \i includes, no psql-only syntax.
-- SAFETY    : ONE transaction (opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql or by the build file). Any error rolls everything back.
--             It refuses to run twice. Take a backup / snapshot first.
--
-- WHAT IT DOES TO EXISTING DATA
--   * orders / invoices / returns / replacements / COD receipts / referral codes that
--     already exist are RENUMBERED into the new business-code format (section U21).
--     If you already sent those numbers to customers, read section U21 before running.
--   * Status / gender / address-type CHECK lists are replaced by foreign keys to
--     master tables (U22, U23). The old CHAR columns stay (kept in sync) so existing
--     code and triggers keep working.
--
-- Section order follows dependencies, not the U-number:
--   U21 -> U22 -> U23 -> U31 -> U24 -> U25 -> U26 -> U38 -> U27/U28 -> U29 -> U30
--   -> U32 -> U33 -> U36 -> U37 -> U34 -> U35 -> U39 -> U40 -> finalize + verification
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. PRE-FLIGHT
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.postal_codes') IS NULL OR to_regclass('public.audit_logs') IS NULL THEN
        RAISE EXCEPTION 'Base schema / upgrade v2 not found. Run rt_crackers_full.sql and rt_crackers_upgrade_v2_full.sql first.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'audit_logs' AND column_name = 'action_type') THEN
        RAISE EXCEPTION 'Upgrade v2 (U20 audit logging) is not applied. Run rt_crackers_upgrade_v2_full.sql first.';
    END IF;
    IF to_regclass('public.business_code_definitions') IS NOT NULL OR to_regclass('public.business_rules') IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade v3 appears to be applied already (business_code_definitions / business_rules exist).';
    END IF;
END;
$$;

-- Backfills below must not fire audit / updated_at / status triggers (re-enabled in the finalize section).
ALTER TABLE users                 DISABLE TRIGGER USER;
ALTER TABLE orders                DISABLE TRIGGER USER;
ALTER TABLE invoices              DISABLE TRIGGER USER;
ALTER TABLE return_requests       DISABLE TRIGGER USER;
ALTER TABLE replacement_requests  DISABLE TRIGGER USER;
ALTER TABLE cod_transactions      DISABLE TRIGGER USER;
ALTER TABLE reviews               DISABLE TRIGGER USER;
ALTER TABLE shipments             DISABLE TRIGGER USER;

-- RT CRACKERS | 21_UPGRADE_V3/001_Schema_versions.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- ---------------------------------------------------------------------
-- Schema version register
-- ---------------------------------------------------------------------
CREATE TABLE schema_versions (
    schema_version_id  SMALLINT      GENERATED ALWAYS AS IDENTITY,
    version_number     VARCHAR(10)   NOT NULL,
    description        VARCHAR(255)  NOT NULL,
    applied_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    applied_by         VARCHAR(80)   NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_schema_versions PRIMARY KEY (schema_version_id),
    CONSTRAINT uq_schema_versions_number UNIQUE (version_number)
);
COMMENT ON TABLE schema_versions IS 'Which upgrade scripts have been applied to this database.';

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

-- RT CRACKERS | 21_UPGRADE_V3/003_U22_Master_Status_Tables.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 22 - MASTER STATUS TABLES
-- order / payment / shipment / review / user status masters.
-- Transaction tables get a status_id foreign key. The old CHAR status column stays and is kept
-- in sync by trigger (write either one; if both change, status_id wins), so existing queries,
-- indexes and triggers keep working while the application moves to status_id.
-- The old CHECK (... IN ('P','C',...)) lists become foreign keys to the master, so a new status
-- is one INSERT into the master table instead of a schema change.
-- =====================================================================
DO $$
DECLARE t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY['order', 'payment', 'shipment', 'review', 'user'] LOOP
        EXECUTE format($f$
            CREATE TABLE %1$s_status_master (
                status_id    SMALLINT     GENERATED ALWAYS AS IDENTITY,
                status_code  CHAR(1)      NOT NULL,
                status_name  VARCHAR(40)  NOT NULL,
                description  VARCHAR(255),
                sort_order   SMALLINT     NOT NULL DEFAULT 0,
                is_terminal  BOOLEAN      NOT NULL DEFAULT FALSE,
                is_default   BOOLEAN      NOT NULL DEFAULT FALSE,
                is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
                created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT pk_%1$s_status_master      PRIMARY KEY (status_id),
                CONSTRAINT uq_%1$s_status_master_code UNIQUE (status_code),
                CONSTRAINT uq_%1$s_status_master_name UNIQUE (status_name),
                CONSTRAINT ck_%1$s_status_master_code CHECK (status_code ~ '^[A-Z]$')
            )$f$, t);
        EXECUTE format('CREATE UNIQUE INDEX uq_%1$s_status_master_default ON %1$s_status_master (is_default) WHERE is_default', t);
    END LOOP;
END;
$$;

INSERT INTO order_status_master (status_code, status_name, description, sort_order, is_terminal, is_default) VALUES
    ('P', 'Placed',            'Order received, awaiting confirmation',     1, FALSE, TRUE),
    ('C', 'Confirmed',         'Order confirmed by the store',              2, FALSE, FALSE),
    ('K', 'Packed',            'Items packed and ready for dispatch',       3, FALSE, FALSE),
    ('S', 'Shipped',           'Handed over to the carrier',                4, FALSE, FALSE),
    ('O', 'Out for delivery',  'With the delivery agent',                   5, FALSE, FALSE),
    ('D', 'Delivered',         'Delivered to the customer',                 6, TRUE,  FALSE),
    ('X', 'Cancelled',         'Cancelled before delivery',                 7, TRUE,  FALSE),
    ('R', 'Returned',          'Returned by the customer or the carrier',   8, TRUE,  FALSE);

INSERT INTO payment_status_master (status_code, status_name, description, sort_order, is_terminal, is_default) VALUES
    ('P', 'Pending',             'Payment not collected yet',        1, FALSE, TRUE),
    ('C', 'Collected',           'Payment collected in full',        2, FALSE, FALSE),
    ('F', 'Failed',              'Payment attempt failed',           3, FALSE, FALSE),
    ('Q', 'Partially refunded',  'Part of the payment was refunded', 4, FALSE, FALSE),
    ('R', 'Refunded',            'Payment refunded in full',         5, TRUE,  FALSE);

INSERT INTO shipment_status_master (status_code, status_name, description, sort_order, is_terminal, is_default) VALUES
    ('P', 'Pending',            'Shipment created, not packed yet',    1, FALSE, TRUE),
    ('K', 'Packed',             'Packed and ready for pickup',         2, FALSE, FALSE),
    ('S', 'Shipped',            'Handed over to the carrier',          3, FALSE, FALSE),
    ('T', 'In transit',         'Moving between hubs',                 4, FALSE, FALSE),
    ('O', 'Out for delivery',   'With the delivery agent',             5, FALSE, FALSE),
    ('D', 'Delivered',          'Delivered to the customer',           6, TRUE,  FALSE),
    ('F', 'Delivery failed',    'Delivery attempt failed, will retry', 7, FALSE, FALSE),
    ('R', 'Returned to origin', 'Returned to the warehouse',           8, TRUE,  FALSE),
    ('X', 'Cancelled',          'Shipment cancelled',                  9, TRUE,  FALSE);

INSERT INTO review_status_master (status_code, status_name, description, sort_order, is_terminal, is_default) VALUES
    ('P', 'Pending',   'Waiting for moderation',          1, FALSE, TRUE),
    ('A', 'Approved',  'Visible on the storefront',       2, FALSE, FALSE),
    ('R', 'Rejected',  'Rejected by a moderator',         3, TRUE,  FALSE),
    ('H', 'Hidden',    'Hidden after approval',           4, FALSE, FALSE);

INSERT INTO user_status_master (status_code, status_name, description, sort_order, is_terminal, is_default) VALUES
    ('A', 'Active',     'Can sign in and order',          1, FALSE, TRUE),
    ('I', 'Inactive',   'Dormant or deactivated',         2, FALSE, FALSE),
    ('S', 'Suspended',  'Temporarily suspended',          3, FALSE, FALSE),
    ('B', 'Blocked',    'Blocked by the store',           4, FALSE, FALSE),
    ('D', 'Deleted',    'Account deleted',                5, TRUE,  FALSE);

-- status_id columns on the transaction tables, backfilled from the existing codes
ALTER TABLE orders    ADD COLUMN order_status_id    SMALLINT,
                      ADD COLUMN payment_status_id  SMALLINT;
ALTER TABLE reviews   ADD COLUMN review_status_id   SMALLINT;
ALTER TABLE users     ADD COLUMN user_status_id     SMALLINT;
ALTER TABLE shipments ADD COLUMN shipment_status_id SMALLINT;

UPDATE orders o  SET order_status_id   = m.status_id FROM order_status_master   m WHERE m.status_code = o.order_status;
UPDATE orders o  SET payment_status_id = m.status_id FROM payment_status_master m WHERE m.status_code = o.payment_status;
UPDATE reviews r SET review_status_id  = m.status_id FROM review_status_master  m WHERE m.status_code = r.moderation_status;
UPDATE users u   SET user_status_id    = m.status_id FROM user_status_master    m WHERE m.status_code = u.status;
-- shipments never had a status: derive it from the order and the dispatch timestamps
UPDATE shipments s
   SET shipment_status_id = (SELECT m.status_id FROM shipment_status_master m
                              WHERE m.status_code = CASE WHEN o.order_status = 'D' THEN 'D'
                                                         WHEN o.order_status = 'X' THEN 'X'
                                                         WHEN o.order_status = 'R' THEN 'R'
                                                         WHEN o.order_status = 'O' THEN 'O'
                                                         WHEN s.shipped_at IS NOT NULL THEN 'S'
                                                         WHEN s.packed_at  IS NOT NULL THEN 'K'
                                                         ELSE 'P' END)
  FROM orders o WHERE o.order_id = s.order_id;

ALTER TABLE orders    ALTER COLUMN order_status_id    SET NOT NULL,
                      ALTER COLUMN payment_status_id  SET NOT NULL;
ALTER TABLE reviews   ALTER COLUMN review_status_id   SET NOT NULL;
ALTER TABLE users     ALTER COLUMN user_status_id     SET NOT NULL;
ALTER TABLE shipments ALTER COLUMN shipment_status_id SET NOT NULL;

ALTER TABLE orders    ADD CONSTRAINT fk_orders_order_status_id    FOREIGN KEY (order_status_id)    REFERENCES order_status_master (status_id)    ON DELETE RESTRICT,
                      ADD CONSTRAINT fk_orders_payment_status_id  FOREIGN KEY (payment_status_id)  REFERENCES payment_status_master (status_id)  ON DELETE RESTRICT;
ALTER TABLE reviews   ADD CONSTRAINT fk_reviews_review_status_id  FOREIGN KEY (review_status_id)   REFERENCES review_status_master (status_id)   ON DELETE RESTRICT;
ALTER TABLE users     ADD CONSTRAINT fk_users_user_status_id      FOREIGN KEY (user_status_id)     REFERENCES user_status_master (status_id)     ON DELETE RESTRICT;
ALTER TABLE shipments ADD CONSTRAINT fk_shipments_shipment_status_id FOREIGN KEY (shipment_status_id) REFERENCES shipment_status_master (status_id) ON DELETE RESTRICT;

-- hard-coded CHECK lists -> foreign keys to the master code (new statuses = one INSERT)
ALTER TABLE orders DROP CONSTRAINT ck_orders_order_status,
                   DROP CONSTRAINT ck_orders_payment_status;
ALTER TABLE orders ADD CONSTRAINT fk_orders_order_status_code   FOREIGN KEY (order_status)   REFERENCES order_status_master (status_code)   ON DELETE RESTRICT,
                   ADD CONSTRAINT fk_orders_payment_status_code FOREIGN KEY (payment_status) REFERENCES payment_status_master (status_code) ON DELETE RESTRICT;
ALTER TABLE order_status_history DROP CONSTRAINT ck_order_status_history_old,
                                 DROP CONSTRAINT ck_order_status_history_new;
ALTER TABLE order_status_history ADD CONSTRAINT fk_order_status_history_old FOREIGN KEY (old_status) REFERENCES order_status_master (status_code) ON DELETE RESTRICT,
                                 ADD CONSTRAINT fk_order_status_history_new FOREIGN KEY (new_status) REFERENCES order_status_master (status_code) ON DELETE RESTRICT;
ALTER TABLE reviews DROP CONSTRAINT ck_reviews_moderation_status;
ALTER TABLE reviews ADD CONSTRAINT fk_reviews_moderation_status_code FOREIGN KEY (moderation_status) REFERENCES review_status_master (status_code) ON DELETE RESTRICT;
ALTER TABLE users   DROP CONSTRAINT ck_users_status;
ALTER TABLE users   ADD CONSTRAINT fk_users_status_code FOREIGN KEY (status) REFERENCES user_status_master (status_code) ON DELETE RESTRICT;

CREATE INDEX idx_orders_order_status_id    ON orders (order_status_id, created_at DESC);
CREATE INDEX idx_orders_payment_status_id  ON orders (payment_status_id);
CREATE INDEX idx_reviews_review_status_id  ON reviews (review_status_id);
CREATE INDEX idx_users_user_status_id      ON users (user_status_id);
CREATE INDEX idx_shipments_shipment_status_id ON shipments (shipment_status_id);

-- Keeps the CHAR code and status_id in step.
--   TG_ARGV[0] master table | [1] code column ('' = table has no code column) | [2] status_id column
CREATE OR REPLACE FUNCTION fn_sync_status_id()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_master  TEXT  := TG_ARGV[0];
    v_code    TEXT  := TG_ARGV[1];
    v_idcol   TEXT  := TG_ARGV[2];
    v_new     JSONB := to_jsonb(NEW);
    v_old     JSONB;
    v_use_id  BOOLEAN;
    v_val     TEXT;
BEGIN
    IF TG_OP = 'UPDATE' THEN v_old := to_jsonb(OLD); END IF;

    IF v_code = '' THEN                                   -- id-only table: fill the default status
        IF v_new ->> v_idcol IS NULL THEN
            EXECUTE format('SELECT status_id::TEXT FROM %I WHERE is_default', v_master) INTO v_val;
            NEW := jsonb_populate_record(NEW, jsonb_build_object(v_idcol, v_val::SMALLINT));
        END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        v_use_id := (v_new ->> v_idcol) IS NOT NULL;      -- id wins when given, otherwise the code (or its default)
    ELSIF (v_new ->> v_idcol) IS DISTINCT FROM (v_old ->> v_idcol) THEN
        v_use_id := TRUE;
    ELSIF (v_new ->> v_code) IS DISTINCT FROM (v_old ->> v_code) THEN
        v_use_id := FALSE;
    ELSE
        RETURN NEW;
    END IF;

    IF v_use_id THEN
        EXECUTE format('SELECT status_code::TEXT FROM %I WHERE status_id = $1', v_master)
           INTO v_val USING (v_new ->> v_idcol)::SMALLINT;
        IF v_val IS NOT NULL THEN
            NEW := jsonb_populate_record(NEW, jsonb_build_object(v_code, v_val));
        END IF;
    ELSE
        EXECUTE format('SELECT status_id::TEXT FROM %I WHERE status_code = $1', v_master)
           INTO v_val USING (v_new ->> v_code)::CHAR(1);
        IF v_val IS NOT NULL THEN
            NEW := jsonb_populate_record(NEW, jsonb_build_object(v_idcol, v_val::SMALLINT));
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- named trg_00_* so they fire before the other BEFORE triggers (e.g. review moderation stamp)
CREATE TRIGGER trg_00_orders_order_status_sync   BEFORE INSERT OR UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_sync_status_id('order_status_master', 'order_status', 'order_status_id');
CREATE TRIGGER trg_00_orders_payment_status_sync BEFORE INSERT OR UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_sync_status_id('payment_status_master', 'payment_status', 'payment_status_id');
CREATE TRIGGER trg_00_reviews_status_sync        BEFORE INSERT OR UPDATE ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_sync_status_id('review_status_master', 'moderation_status', 'review_status_id');
CREATE TRIGGER trg_00_users_status_sync          BEFORE INSERT OR UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_sync_status_id('user_status_master', 'status', 'user_status_id');
CREATE TRIGGER trg_00_shipments_status_sync      BEFORE INSERT ON shipments
    FOR EACH ROW EXECUTE FUNCTION fn_sync_status_id('shipment_status_master', '', 'shipment_status_id');

-- "UPDATE OF <col>" triggers only fire for columns named in the UPDATE statement, so they must
-- also listen to the new status_id column (the sync trigger above fills the code before they run).
DROP TRIGGER trg_orders_log_status ON orders;
CREATE TRIGGER trg_orders_log_status AFTER INSERT OR UPDATE OF order_status, order_status_id ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_log_order_status();
DROP TRIGGER trg_orders_sales_count ON orders;
CREATE TRIGGER trg_orders_sales_count AFTER UPDATE OF order_status, order_status_id ON orders
    FOR EACH ROW WHEN (NEW.order_status = 'D' AND OLD.order_status <> 'D')
    EXECUTE FUNCTION fn_update_sales_count();
DROP TRIGGER trg_reviews_sync_rating ON reviews;
CREATE TRIGGER trg_reviews_sync_rating AFTER INSERT OR DELETE OR UPDATE OF rating, moderation_status, review_status_id, is_deleted ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_sync_product_rating();
DROP TRIGGER trg_users_audit ON users;
CREATE TRIGGER trg_users_audit AFTER INSERT OR DELETE OR UPDATE OF email, phone, first_name, middle_name, last_name,
        status, user_status_id, email_verified, phone_verified, account_locked, account_locked_until, password_hash, mfa_enabled,
        mfa_secret, security_answer_hash, referred_by, is_deleted ON users
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log('user_id', 'password_hash', 'security_answer_hash', 'mfa_secret');

-- RT CRACKERS | 21_UPGRADE_V3/004_U23_Enum_Replacement_Strategy.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 23 - ENUM REPLACEMENT STRATEGY
-- Gender and address type become reference tables with foreign keys.
-- (Order status is U22 above; languages, currencies, device types... are in U31 reference_data.)
-- =====================================================================
CREATE TABLE genders (
    gender_id    SMALLINT     GENERATED ALWAYS AS IDENTITY,
    gender_code  CHAR(1)      NOT NULL,
    gender_name  VARCHAR(40)  NOT NULL,
    sort_order   SMALLINT     NOT NULL DEFAULT 0,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_genders PRIMARY KEY (gender_id),
    CONSTRAINT uq_genders_code UNIQUE (gender_code),
    CONSTRAINT uq_genders_name UNIQUE (gender_name),
    CONSTRAINT ck_genders_code CHECK (gender_code ~ '^[A-Z]$')
);
INSERT INTO genders (gender_code, gender_name, sort_order) VALUES ('M', 'Male', 1), ('F', 'Female', 2), ('O', 'Other', 3);

CREATE TABLE address_types (
    address_type_id    SMALLINT     GENERATED ALWAYS AS IDENTITY,
    address_type_code  VARCHAR(10)  NOT NULL,
    address_type_name  VARCHAR(40)  NOT NULL,
    sort_order         SMALLINT     NOT NULL DEFAULT 0,
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_address_types PRIMARY KEY (address_type_id),
    CONSTRAINT uq_address_types_code UNIQUE (address_type_code),
    CONSTRAINT uq_address_types_name UNIQUE (address_type_name),
    CONSTRAINT ck_address_types_code CHECK (address_type_code ~ '^[A-Z]+$')
);
INSERT INTO address_types (address_type_code, address_type_name, sort_order) VALUES ('HOME', 'Home', 1), ('OFFICE', 'Office', 2), ('WAREHOUSE', 'Warehouse', 3), ('OTHER', 'Other', 4);
-- (v2 U8 replaced addresses.address_type with address_label; the label is what now references this table)

ALTER TABLE users     DROP CONSTRAINT ck_users_gender;
ALTER TABLE users     ADD CONSTRAINT fk_users_gender FOREIGN KEY (gender) REFERENCES genders (gender_code) ON DELETE RESTRICT;
ALTER TABLE addresses DROP CONSTRAINT ck_addresses_label;
ALTER TABLE addresses ADD CONSTRAINT fk_addresses_address_label FOREIGN KEY (address_label) REFERENCES address_types (address_type_code) ON DELETE RESTRICT;

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

-- RT CRACKERS | 21_UPGRADE_V3/006_U24_Business_Rule_Centralization.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 24 - BUSINESS RULE CENTRALIZATION
-- Rule values live here, not in application code. Change a row, behaviour changes.
-- Enforced in the database today: cart size, wishlist size, return window, replacement window.
-- The numbers below are starting values: edit them to your policy.
-- =====================================================================
CREATE TABLE business_rules (
    rule_id      INTEGER       GENERATED ALWAYS AS IDENTITY,
    rule_name    VARCHAR(80)   NOT NULL,
    rule_value   VARCHAR(255)  NOT NULL,
    value_type   CHAR(1)       NOT NULL DEFAULT 'N',          -- N number, S string, B boolean, J json
    module       VARCHAR(30)   NOT NULL DEFAULT 'GENERAL',
    description  VARCHAR(255),
    is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_business_rules PRIMARY KEY (rule_id),
    CONSTRAINT uq_business_rules_name UNIQUE (rule_name),
    CONSTRAINT ck_business_rules_name  CHECK (rule_name ~ '^[a-z][a-z0-9_.]*$'),
    CONSTRAINT ck_business_rules_type  CHECK (value_type IN ('N','S','B','J')),
    CONSTRAINT ck_business_rules_value CHECK (
           (value_type = 'N' AND rule_value ~ '^-?[0-9]+(\.[0-9]+)?$')
        OR (value_type = 'B' AND rule_value IN ('true','false'))
        OR (value_type = 'S' AND BTRIM(rule_value) <> '')
        OR (value_type = 'J' AND rule_value LIKE '{%}' OR rule_value LIKE '[%]'))
);

INSERT INTO business_rules (rule_name, rule_value, value_type, module, description) VALUES
    ('cart.max_items',               '25',  'N', 'CART',        'Maximum different products in one cart'),
    ('wishlist.max_items',           '100', 'N', 'WISHLIST',    'Maximum products across all wishlists of one customer'),
    ('return.period_days',           '7',   'N', 'ORDERS',      'Days after delivery in which a return can be requested'),
    ('replacement.period_days',      '7',   'N', 'ORDERS',      'Days after delivery in which a replacement can be requested'),
    ('archive.batch_size',           '5000','N', 'GOVERNANCE',  'Rows moved per batch by the retention / archive job'),
    ('health.cpu_warning_percent',   '80',  'N', 'OPERATIONS',  'CPU usage that marks a health check as warning'),
    ('health.cpu_critical_percent',  '95',  'N', 'OPERATIONS',  'CPU usage that marks a health check as critical'),
    ('health.memory_warning_percent','85',  'N', 'OPERATIONS',  'Memory usage that marks a health check as warning'),
    ('health.memory_critical_percent','95', 'N', 'OPERATIONS',  'Memory usage that marks a health check as critical');

-- rule lookups for triggers / application: NULL-safe, inactive rules behave as "no rule"
CREATE OR REPLACE FUNCTION fn_rule_number(p_rule_name TEXT, p_default NUMERIC DEFAULT NULL)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
    SELECT COALESCE((SELECT rule_value::NUMERIC FROM business_rules
                      WHERE rule_name = p_rule_name AND is_active AND value_type = 'N'), p_default)
$$;

CREATE OR REPLACE FUNCTION fn_enforce_cart_limit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_max INTEGER := fn_rule_number('cart.max_items');
BEGIN
    IF v_max IS NOT NULL AND (SELECT COUNT(*) FROM cart_items WHERE cart_id = NEW.cart_id) >= v_max THEN
        RAISE EXCEPTION 'Cart is full: at most % different products per cart (rule cart.max_items)', v_max
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_cart_items_limit BEFORE INSERT ON cart_items
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_cart_limit();

CREATE OR REPLACE FUNCTION fn_enforce_wishlist_limit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_max   INTEGER := fn_rule_number('wishlist.max_items');
    v_user  BIGINT;
BEGIN
    IF v_max IS NULL THEN RETURN NEW; END IF;
    SELECT user_id INTO v_user FROM wishlists WHERE wishlist_id = NEW.wishlist_id;
    IF (SELECT COUNT(*) FROM wishlist_items wi JOIN wishlists w ON w.wishlist_id = wi.wishlist_id WHERE w.user_id = v_user) >= v_max THEN
        RAISE EXCEPTION 'Wishlist is full: at most % products per customer (rule wishlist.max_items)', v_max
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_wishlist_items_limit BEFORE INSERT ON wishlist_items
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_wishlist_limit();

-- return / replacement window, counted from the delivery date (not enforced for undelivered orders)
CREATE OR REPLACE FUNCTION fn_enforce_after_sales_window()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_rule       TEXT := TG_ARGV[0];
    v_days       INTEGER := fn_rule_number(TG_ARGV[0]);
    v_delivered  DATE;
BEGIN
    IF v_days IS NULL THEN RETURN NEW; END IF;
    SELECT o.delivery_date INTO v_delivered
      FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
     WHERE oi.order_item_id = NEW.order_item_id;
    IF v_delivered IS NOT NULL AND CURRENT_DATE - v_delivered > v_days THEN
        RAISE EXCEPTION 'Request window closed: % days after delivery (rule %)', v_days, v_rule
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_return_requests_window BEFORE INSERT ON return_requests
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_after_sales_window('return.period_days');
CREATE TRIGGER trg_replacement_requests_window BEFORE INSERT ON replacement_requests
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_after_sales_window('replacement.period_days');

-- RT CRACKERS | 21_UPGRADE_V3/007_U25_Country_Configuration.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 25 - COUNTRY CONFIGURATION
-- Currency, tax, phone and postal rules per country (India seeded).
-- Existing India-only checks on users / addresses are unchanged; this table is what a
-- multi-country application reads, and what you extend when you open a new country.
-- =====================================================================
CREATE TABLE country_configurations (
    country_config_id   SMALLINT      GENERATED ALWAYS AS IDENTITY,
    country_id          SMALLINT      NOT NULL,
    currency_code       CHAR(3)       NOT NULL,
    currency_symbol     VARCHAR(5)    NOT NULL,
    currency_decimals   SMALLINT      NOT NULL DEFAULT 2,
    tax_name            VARCHAR(20)   NOT NULL DEFAULT 'GST',
    tax_rate            NUMERIC(5,2)  NOT NULL,                 -- default tax percentage
    phone_length        SMALLINT      NOT NULL,                 -- national number length, without country code
    phone_format        VARCHAR(120)  NOT NULL,                 -- regular expression
    postal_code_length  SMALLINT      NOT NULL,
    postal_format       VARCHAR(120)  NOT NULL,                 -- regular expression
    postal_example      VARCHAR(20),
    timezone            VARCHAR(40)   NOT NULL DEFAULT 'UTC',
    is_default          BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_country_configurations PRIMARY KEY (country_config_id),
    CONSTRAINT uq_country_configurations_country UNIQUE (country_id),
    CONSTRAINT fk_country_configurations_country FOREIGN KEY (country_id) REFERENCES countries (country_id) ON DELETE CASCADE,
    CONSTRAINT ck_country_configurations_currency CHECK (currency_code = UPPER(currency_code)),
    CONSTRAINT ck_country_configurations_decimals CHECK (currency_decimals BETWEEN 0 AND 4),
    CONSTRAINT ck_country_configurations_tax      CHECK (tax_rate BETWEEN 0 AND 100),
    CONSTRAINT ck_country_configurations_phone    CHECK (phone_length BETWEEN 4 AND 15),
    CONSTRAINT ck_country_configurations_postal   CHECK (postal_code_length BETWEEN 3 AND 10)
);
CREATE UNIQUE INDEX uq_country_configurations_default ON country_configurations (is_default) WHERE is_default;

INSERT INTO country_configurations (country_id, currency_code, currency_symbol, tax_name, tax_rate, phone_length, phone_format,
                                    postal_code_length, postal_format, postal_example, timezone, is_default)
SELECT country_id, 'INR', '₹', 'GST', 18.00, 10, '^[6-9][0-9]{9}$', 6, '^[1-9][0-9]{5}$', '641001', 'Asia/Kolkata', TRUE
  FROM countries WHERE country_code = 'IN';

-- RT CRACKERS | 21_UPGRADE_V3/008_U26_Product_Classification_Framework.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 26 - PRODUCT CLASSIFICATION FRAMEWORK
-- Already existing: category, subcategory, brand, festival (festival_products).
-- New: product type (one per product), collections and seasons (many per product).
-- v_product_classification joins everything for filtering.
-- =====================================================================
CREATE TABLE product_types (
    product_type_id  SMALLINT      GENERATED ALWAYS AS IDENTITY,
    type_code        VARCHAR(30)   NOT NULL,
    type_name        VARCHAR(80)   NOT NULL,
    slug             VARCHAR(100)  NOT NULL,
    description      VARCHAR(255),
    display_order    SMALLINT      NOT NULL DEFAULT 0,
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_types PRIMARY KEY (product_type_id),
    CONSTRAINT uq_product_types_code UNIQUE (type_code),
    CONSTRAINT uq_product_types_name UNIQUE (type_name),
    CONSTRAINT uq_product_types_slug UNIQUE (slug),
    CONSTRAINT ck_product_types_code CHECK (type_code = UPPER(type_code))
);
INSERT INTO product_types (type_code, type_name, slug, display_order) VALUES
    ('SPARKLER',       'Sparklers',                'sparklers',        1),
    ('FLOWER_POT',     'Flower Pots',              'flower-pots',      2),
    ('GROUND_CHAKKAR', 'Ground Chakkars',          'ground-chakkars',  3),
    ('FOUNTAIN',       'Fountains',                'fountains',        4),
    ('ROCKET',         'Rockets',                  'rockets',          5),
    ('SKY_SHOT',       'Sky Shots & Aerials',      'sky-shots',        6),
    ('MULTI_SHOT',     'Multi-shot Cakes',         'multi-shot-cakes', 7),
    ('CRACKER',        'Crackers & Bombs',         'crackers-bombs',   8),
    ('KIDS_SPECIAL',   'Kids Specials',            'kids-specials',    9),
    ('GIFT_BOX',       'Gift Boxes',               'gift-boxes',      10),
    ('COMBO_PACK',     'Combo Packs',              'combo-packs',     11),
    ('NOVELTY',        'Novelty & Fun',            'novelty',         12);

CREATE TABLE collections (
    collection_id    INTEGER       GENERATED ALWAYS AS IDENTITY,
    collection_name  VARCHAR(100)  NOT NULL,
    slug             VARCHAR(120)  NOT NULL,
    description      TEXT,
    image_url        VARCHAR(500),
    start_date       DATE,
    end_date         DATE,
    display_order    SMALLINT      NOT NULL DEFAULT 0,
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_collections PRIMARY KEY (collection_id),
    CONSTRAINT uq_collections_name UNIQUE (collection_name),
    CONSTRAINT uq_collections_slug UNIQUE (slug),
    CONSTRAINT ck_collections_window CHECK (start_date IS NULL OR end_date IS NULL OR end_date >= start_date)
);
INSERT INTO collections (collection_name, slug, display_order) VALUES
    ('Family Packs',        'family-packs',        1),
    ('Kids Safe Picks',     'kids-safe-picks',     2),
    ('Premium Gift Boxes',  'premium-gift-boxes',  3),
    ('Best Sellers',        'best-sellers',        4),
    ('New Launches',        'new-launches',        5);

CREATE TABLE seasons (
    season_id    SMALLINT      GENERATED ALWAYS AS IDENTITY,
    season_name  VARCHAR(80)   NOT NULL,
    slug         VARCHAR(100)  NOT NULL,
    start_month  SMALLINT      NOT NULL,
    end_month    SMALLINT      NOT NULL,                       -- may be smaller than start_month (wraps over new year)
    description  VARCHAR(255),
    is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_seasons PRIMARY KEY (season_id),
    CONSTRAINT uq_seasons_name UNIQUE (season_name),
    CONSTRAINT uq_seasons_slug UNIQUE (slug),
    CONSTRAINT ck_seasons_months CHECK (start_month BETWEEN 1 AND 12 AND end_month BETWEEN 1 AND 12)
);
INSERT INTO seasons (season_name, slug, start_month, end_month, description) VALUES
    ('Diwali Season',          'diwali',          10, 11, 'Deepavali shopping season'),
    ('Pongal & Harvest',       'pongal-harvest',   1,  1, 'Pongal / Sankranti'),
    ('Christmas & New Year',   'christmas-new-year',12, 1, 'Year-end celebrations'),
    ('Wedding & Events',       'wedding-events',   4,  6, 'Wedding and temple festival season'),
    ('All Year',               'all-year',         1, 12, 'Not seasonal');

ALTER TABLE products ADD COLUMN product_type_id SMALLINT;
ALTER TABLE products ADD CONSTRAINT fk_products_product_type FOREIGN KEY (product_type_id) REFERENCES product_types (product_type_id) ON DELETE SET NULL;
CREATE INDEX idx_products_product_type ON products (product_type_id) WHERE product_type_id IS NOT NULL;

CREATE TABLE product_collections (
    product_id     BIGINT     NOT NULL,
    collection_id  INTEGER    NOT NULL,
    display_order  SMALLINT   NOT NULL DEFAULT 0,
    created_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_collections PRIMARY KEY (product_id, collection_id),
    CONSTRAINT fk_product_collections_product    FOREIGN KEY (product_id)    REFERENCES products (product_id)       ON DELETE CASCADE,
    CONSTRAINT fk_product_collections_collection FOREIGN KEY (collection_id) REFERENCES collections (collection_id) ON DELETE CASCADE
);
CREATE INDEX idx_product_collections_collection ON product_collections (collection_id);

CREATE TABLE product_seasons (
    product_id  BIGINT     NOT NULL,
    season_id   SMALLINT   NOT NULL,
    created_at  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_seasons PRIMARY KEY (product_id, season_id),
    CONSTRAINT fk_product_seasons_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT fk_product_seasons_season  FOREIGN KEY (season_id)  REFERENCES seasons (season_id)   ON DELETE CASCADE
);
CREATE INDEX idx_product_seasons_season ON product_seasons (season_id);

CREATE VIEW v_product_classification WITH (security_invoker = true) AS
SELECT p.product_id, p.sku, p.product_name, p.status,
       c.category_id,  c.category_name,
       sc.subcategory_id, sc.subcategory_name,
       b.brand_id, b.brand_name,
       pt.product_type_id, pt.type_code AS product_type_code, pt.type_name AS product_type,
       ARRAY(SELECT col.collection_name FROM product_collections pc JOIN collections col ON col.collection_id = pc.collection_id
              WHERE pc.product_id = p.product_id ORDER BY col.collection_name) AS collections,
       ARRAY(SELECT s.season_name FROM product_seasons ps JOIN seasons s ON s.season_id = ps.season_id
              WHERE ps.product_id = p.product_id ORDER BY s.season_name) AS seasons,
       ARRAY(SELECT f.festival_name FROM festival_products fp JOIN festivals f ON f.festival_id = fp.festival_id
              WHERE fp.product_id = p.product_id ORDER BY f.festival_name) AS festivals
  FROM products p
  JOIN categories c           ON c.category_id = p.category_id
  LEFT JOIN subcategories sc  ON sc.subcategory_id = p.subcategory_id
  LEFT JOIN brands b          ON b.brand_id = p.brand_id
  LEFT JOIN product_types pt  ON pt.product_type_id = p.product_type_id
 WHERE NOT p.is_deleted;

-- RT CRACKERS | 21_UPGRADE_V3/009_U38_Data_Classification.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 38 - DATA CLASSIFICATION
-- Four levels, plus a register that says which tables / columns sit at which level.
-- The register is pre-filled for every table at the end of this file; adjust it to your policy.
-- =====================================================================
CREATE TABLE data_classification (
    classification_id    SMALLINT      GENERATED ALWAYS AS IDENTITY,
    level_code           VARCHAR(15)   NOT NULL,
    sensitivity_rank     SMALLINT      NOT NULL,
    description          VARCHAR(255)  NOT NULL,
    handling_guidelines  TEXT,
    requires_encryption  BOOLEAN       NOT NULL DEFAULT FALSE,
    requires_masking     BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active            BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_data_classification PRIMARY KEY (classification_id),
    CONSTRAINT uq_data_classification_level UNIQUE (level_code),
    CONSTRAINT uq_data_classification_rank  UNIQUE (sensitivity_rank),
    CONSTRAINT ck_data_classification_level CHECK (level_code IN ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED')),
    CONSTRAINT ck_data_classification_rank  CHECK (sensitivity_rank BETWEEN 1 AND 4)
);
INSERT INTO data_classification (level_code, sensitivity_rank, description, handling_guidelines, requires_encryption, requires_masking) VALUES
    ('PUBLIC',       1, 'Safe to show to anyone (catalogue, banners, festival pages)', 'No restrictions.', FALSE, FALSE),
    ('INTERNAL',     2, 'Business data for staff and the application only',           'Not exposed through public APIs without a policy.', FALSE, FALSE),
    ('CONFIDENTIAL', 3, 'Personal or commercial data about customers or the business', 'Access on a need-to-know basis; mask in logs and exports.', FALSE, TRUE),
    ('RESTRICTED',   4, 'Secrets and credentials',                                    'Store hashed or encrypted only; never log, never export.', TRUE, TRUE);

CREATE TABLE data_classification_assignments (
    assignment_id      INTEGER       GENERATED ALWAYS AS IDENTITY,
    table_name         VARCHAR(63)   NOT NULL,
    column_name        VARCHAR(63),                           -- NULL = the table as a whole
    classification_id  SMALLINT      NOT NULL,
    rationale          VARCHAR(255),
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_data_classification_assignments PRIMARY KEY (assignment_id),
    CONSTRAINT fk_data_classification_assignments_level FOREIGN KEY (classification_id) REFERENCES data_classification (classification_id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX uq_data_classification_assignments_target ON data_classification_assignments (table_name, COALESCE(column_name, ''));
CREATE INDEX idx_data_classification_assignments_level ON data_classification_assignments (classification_id);

-- RT CRACKERS | 21_UPGRADE_V3/010_U27_Data_Retention_Policy.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 27 - DATA RETENTION POLICY
-- archive_after_days : rows older than this leave the active table (archive framework, U28)
-- retention_period   : days after which archived rows may be destroyed
-- Order data keeps 7 years (tax records). Adjust to the advice you get for your business.
-- =====================================================================
CREATE TABLE data_retention_policies (
    policy_id             SMALLINT      GENERATED ALWAYS AS IDENTITY,
    entity_name           VARCHAR(63)   NOT NULL,
    retention_period      INTEGER       NOT NULL,             -- days
    archive_after_days    INTEGER       NOT NULL,             -- days
    legal_basis           VARCHAR(255),
    is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_data_retention_policies PRIMARY KEY (policy_id),
    CONSTRAINT uq_data_retention_policies_entity UNIQUE (entity_name),
    CONSTRAINT ck_data_retention_policies_days   CHECK (archive_after_days > 0 AND retention_period >= archive_after_days)
);
INSERT INTO data_retention_policies (entity_name, retention_period, archive_after_days, legal_basis) VALUES
    ('orders',             2555, 730, 'Tax and accounting records (7 years)'),
    ('audit_logs',         2555, 180, 'Security forensics and accountability'),
    ('login_history',       730, 180, 'Security monitoring'),
    ('error_logs',          365,  90, 'Operational troubleshooting'),
    ('search_logs',         365,  90, 'Search tuning'),
    ('user_activity_logs',  365,  90, 'Product analytics'),
    ('page_views',          365,  90, 'Product analytics'),
    ('user_notifications',  365,  90, 'Customer communication history');

-- RT CRACKERS | 21_UPGRADE_V3/011_U28_Archive_Framework.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 28 - ARCHIVE FRAMEWORK
-- Archived rows are stored as JSONB so the archive never breaks when a live table changes.
-- Logs and notifications are MOVED (deleted from the live table).
-- Orders are SNAPSHOTTED only: they stay in orders because invoices, refunds, returns and
-- reviews point at them. Purging an archived order is deliberately a manual decision.
-- Nothing runs on its own: call fn_run_data_retention(FALSE) from a scheduler (pg_cron / Supabase cron).
-- =====================================================================
CREATE TABLE archived_orders (
    archived_order_id  BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id           BIGINT         NOT NULL,                -- no foreign key: the archive outlives the live row
    order_number       VARCHAR(20)    NOT NULL,
    user_id            BIGINT,
    order_status       CHAR(1)        NOT NULL,
    total_amount       NUMERIC(12,2)  NOT NULL,
    ordered_at         TIMESTAMP      NOT NULL,
    order_snapshot     JSONB          NOT NULL,                -- order + items, invoice, shipments, history, COD, refunds, returns
    archived_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_archived_orders PRIMARY KEY (archived_order_id),
    CONSTRAINT uq_archived_orders_order  UNIQUE (order_id),
    CONSTRAINT uq_archived_orders_number UNIQUE (order_number),
    CONSTRAINT ck_archived_orders_snapshot CHECK (jsonb_typeof(order_snapshot) = 'object')
);
CREATE INDEX idx_archived_orders_user ON archived_orders (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_archived_orders_date ON archived_orders (ordered_at);

CREATE TABLE archived_logs (
    archived_log_id  BIGINT       GENERATED ALWAYS AS IDENTITY,
    source_table     VARCHAR(63)  NOT NULL,
    source_id        VARCHAR(64)  NOT NULL,
    logged_at        TIMESTAMP    NOT NULL,
    log_data         JSONB        NOT NULL,
    archived_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_archived_logs PRIMARY KEY (archived_log_id),
    CONSTRAINT uq_archived_logs_source UNIQUE (source_table, source_id)
);
CREATE INDEX idx_archived_logs_time ON archived_logs (source_table, logged_at);

CREATE TABLE archived_notifications (
    archived_notification_id  BIGINT     GENERATED ALWAYS AS IDENTITY,
    user_notification_id      BIGINT     NOT NULL,
    user_id                   BIGINT     NOT NULL,
    notification_id           BIGINT     NOT NULL,
    notification_data         JSONB      NOT NULL,
    notified_at               TIMESTAMP  NOT NULL,
    archived_at               TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_archived_notifications PRIMARY KEY (archived_notification_id),
    CONSTRAINT uq_archived_notifications_source UNIQUE (user_notification_id)
);
CREATE INDEX idx_archived_notifications_user ON archived_notifications (user_id);
CREATE INDEX idx_archived_notifications_time ON archived_notifications (notified_at);

CREATE TABLE archive_runs (
    archive_run_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    entity_name     VARCHAR(63)   NOT NULL,
    action          VARCHAR(10)   NOT NULL,                   -- ARCHIVE or PURGE
    cutoff_at       TIMESTAMP     NOT NULL,
    rows_affected   INTEGER       NOT NULL DEFAULT 0,
    started_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at     TIMESTAMP,
    run_by          VARCHAR(80)   NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_archive_runs PRIMARY KEY (archive_run_id),
    CONSTRAINT ck_archive_runs_action CHECK (action IN ('ARCHIVE','PURGE'))
);
CREATE INDEX idx_archive_runs_entity ON archive_runs (entity_name, started_at DESC);

-- move one batch of a log table into archived_logs
CREATE OR REPLACE FUNCTION fn_archive_logs(p_source TEXT, p_cutoff TIMESTAMP, p_limit INTEGER DEFAULT 5000)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk   TEXT;
    v_ts   TEXT;
    v_rows INTEGER;
BEGIN
    SELECT m.pk, m.ts INTO v_pk, v_ts
      FROM (VALUES ('audit_logs', 'audit_id', 'changed_at'), ('error_logs', 'error_log_id', 'created_at'),
                   ('login_history', 'login_id', 'created_at'), ('search_logs', 'search_log_id', 'created_at'),
                   ('user_activity_logs', 'activity_id', 'created_at'), ('page_views', 'page_view_id', 'created_at')) m(t, pk, ts)
     WHERE m.t = p_source;
    IF NOT FOUND THEN RAISE EXCEPTION 'fn_archive_logs does not support table %', p_source; END IF;

    EXECUTE format($q$
        WITH moved AS (
            DELETE FROM %1$I WHERE ctid IN (SELECT ctid FROM %1$I WHERE %3$I < $1 ORDER BY %3$I LIMIT $2) RETURNING *)
        INSERT INTO archived_logs (source_table, source_id, logged_at, log_data)
        SELECT %1$L, to_jsonb(moved) ->> %2$L, moved.%3$I, to_jsonb(moved) FROM moved$q$,
        p_source, v_pk, v_ts) USING p_cutoff, p_limit;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows;
END;
$$;

-- move one batch of user_notifications (with the notification text) into archived_notifications
CREATE OR REPLACE FUNCTION fn_archive_notifications(p_cutoff TIMESTAMP, p_limit INTEGER DEFAULT 5000)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_rows INTEGER;
BEGIN
    WITH moved AS (
        DELETE FROM user_notifications
         WHERE user_notification_id IN (SELECT user_notification_id FROM user_notifications
                                         WHERE created_at < p_cutoff ORDER BY created_at LIMIT p_limit)
        RETURNING *)
    INSERT INTO archived_notifications (user_notification_id, user_id, notification_id, notification_data, notified_at)
    SELECT m.user_notification_id, m.user_id, m.notification_id,
           to_jsonb(m) || jsonb_build_object('notification', to_jsonb(n)), m.created_at
      FROM moved m LEFT JOIN notifications n ON n.notification_id = m.notification_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows;
END;
$$;

-- snapshot one batch of finished orders (delivered / cancelled / returned) with everything attached to them.
-- Skips orders with an open return, replacement or refund. The live order is NOT removed.
CREATE OR REPLACE FUNCTION fn_archive_orders(p_cutoff TIMESTAMP, p_limit INTEGER DEFAULT 5000)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_rows INTEGER;
BEGIN
    INSERT INTO archived_orders (order_id, order_number, user_id, order_status, total_amount, ordered_at, order_snapshot)
    SELECT o.order_id, o.order_number, o.user_id, o.order_status, o.total_amount, o.created_at,
           to_jsonb(o)
           || jsonb_build_object(
                'items',           COALESCE((SELECT jsonb_agg(to_jsonb(i)) FROM order_items i WHERE i.order_id = o.order_id), '[]'::JSONB),
                'invoice',         (SELECT to_jsonb(v) FROM invoices v WHERE v.order_id = o.order_id),
                'shipments',       COALESCE((SELECT jsonb_agg(to_jsonb(s)) FROM shipments s WHERE s.order_id = o.order_id), '[]'::JSONB),
                'status_history',  COALESCE((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.created_at) FROM order_status_history h WHERE h.order_id = o.order_id), '[]'::JSONB),
                'cod_transaction', (SELECT to_jsonb(c) FROM cod_transactions c WHERE c.order_id = o.order_id),
                'refunds',         COALESCE((SELECT jsonb_agg(to_jsonb(r)) FROM refunds r WHERE r.order_id = o.order_id), '[]'::JSONB),
                'returns',         COALESCE((SELECT jsonb_agg(to_jsonb(rr)) FROM return_requests rr
                                              JOIN order_items oi ON oi.order_item_id = rr.order_item_id WHERE oi.order_id = o.order_id), '[]'::JSONB))
      FROM orders o
     WHERE o.order_status IN ('D','X','R')
       AND o.created_at < p_cutoff
       AND NOT EXISTS (SELECT 1 FROM archived_orders a WHERE a.order_id = o.order_id)
       AND NOT EXISTS (SELECT 1 FROM return_requests rr JOIN order_items oi ON oi.order_item_id = rr.order_item_id
                        WHERE oi.order_id = o.order_id AND rr.status IN ('R','A','P'))
       AND NOT EXISTS (SELECT 1 FROM replacement_requests rp JOIN order_items oi ON oi.order_item_id = rp.order_item_id
                        WHERE oi.order_id = o.order_id AND rp.status IN ('R','A','S'))
       AND NOT EXISTS (SELECT 1 FROM refunds r WHERE r.order_id = o.order_id AND r.status IN ('P','A'))
     ORDER BY o.created_at
     LIMIT p_limit;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows;
END;
$$;

-- Runs every active retention policy. DRY RUN BY DEFAULT: it only reports what it would do.
--   SELECT * FROM fn_run_data_retention();        -- look first
--   SELECT * FROM fn_run_data_retention(FALSE);   -- then archive for real
CREATE OR REPLACE FUNCTION fn_run_data_retention(p_dry_run BOOLEAN DEFAULT TRUE)
RETURNS TABLE (entity_name TEXT, cutoff_at TIMESTAMP, eligible_rows BIGINT, archived_rows INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    r        RECORD;
    v_batch  INTEGER := COALESCE(fn_rule_number('archive.batch_size'), 5000)::INTEGER;
    v_cut    TIMESTAMP;
    v_total  INTEGER;
    v_n      INTEGER;
    v_elig   BIGINT;
    v_run    BIGINT;
BEGIN
    FOR r IN SELECT * FROM data_retention_policies WHERE is_active ORDER BY policy_id LOOP
        v_cut := CURRENT_TIMESTAMP - make_interval(days => r.archive_after_days);
        v_total := 0;

        IF r.entity_name = 'orders' THEN
            SELECT COUNT(*) INTO v_elig FROM orders o
             WHERE o.order_status IN ('D','X','R') AND o.created_at < v_cut
               AND NOT EXISTS (SELECT 1 FROM archived_orders a WHERE a.order_id = o.order_id);
        ELSIF r.entity_name = 'user_notifications' THEN
            SELECT COUNT(*) INTO v_elig FROM user_notifications WHERE created_at < v_cut;
        ELSIF r.entity_name IN ('audit_logs','error_logs','login_history','search_logs','user_activity_logs','page_views') THEN
            EXECUTE format('SELECT COUNT(*) FROM %I WHERE %I < $1', r.entity_name,
                           CASE r.entity_name WHEN 'audit_logs' THEN 'changed_at' ELSE 'created_at' END)
               INTO v_elig USING v_cut;
        ELSE
            RAISE NOTICE 'No archive routine for "%": policy skipped', r.entity_name;
            CONTINUE;
        END IF;

        IF NOT p_dry_run AND v_elig > 0 THEN
            INSERT INTO archive_runs (entity_name, action, cutoff_at) VALUES (r.entity_name, 'ARCHIVE', v_cut) RETURNING archive_run_id INTO v_run;
            LOOP
                v_n := CASE r.entity_name
                           WHEN 'orders'             THEN fn_archive_orders(v_cut, v_batch)
                           WHEN 'user_notifications' THEN fn_archive_notifications(v_cut, v_batch)
                           ELSE fn_archive_logs(r.entity_name, v_cut, v_batch) END;
                v_total := v_total + v_n;
                EXIT WHEN v_n < v_batch;
            END LOOP;
            UPDATE archive_runs SET rows_affected = v_total, finished_at = CURRENT_TIMESTAMP WHERE archive_run_id = v_run;
        END IF;

        entity_name := r.entity_name; cutoff_at := v_cut; eligible_rows := v_elig; archived_rows := v_total;
        RETURN NEXT;
    END LOOP;
END;
$$;

-- Destroys ARCHIVED rows older than retention_period. DRY RUN BY DEFAULT.
CREATE OR REPLACE FUNCTION fn_purge_expired_archives(p_dry_run BOOLEAN DEFAULT TRUE)
RETURNS TABLE (archive_table TEXT, source_entity TEXT, expired_rows BIGINT)
LANGUAGE plpgsql AS $$
DECLARE
    r       RECORD;
    v_cut   TIMESTAMP;
    v_cnt   BIGINT;
BEGIN
    FOR r IN SELECT * FROM data_retention_policies WHERE is_active ORDER BY policy_id LOOP
        v_cut := CURRENT_TIMESTAMP - make_interval(days => r.retention_period);
        IF r.entity_name = 'orders' THEN
            SELECT COUNT(*) INTO v_cnt FROM archived_orders WHERE ordered_at < v_cut;
            IF NOT p_dry_run AND v_cnt > 0 THEN DELETE FROM archived_orders WHERE ordered_at < v_cut; END IF;
            archive_table := 'archived_orders';
        ELSIF r.entity_name = 'user_notifications' THEN
            SELECT COUNT(*) INTO v_cnt FROM archived_notifications WHERE notified_at < v_cut;
            IF NOT p_dry_run AND v_cnt > 0 THEN DELETE FROM archived_notifications WHERE notified_at < v_cut; END IF;
            archive_table := 'archived_notifications';
        ELSE
            SELECT COUNT(*) INTO v_cnt FROM archived_logs WHERE source_table = r.entity_name AND logged_at < v_cut;
            IF NOT p_dry_run AND v_cnt > 0 THEN DELETE FROM archived_logs WHERE source_table = r.entity_name AND logged_at < v_cut; END IF;
            archive_table := 'archived_logs';
        END IF;
        IF NOT p_dry_run AND v_cnt > 0 THEN
            INSERT INTO archive_runs (entity_name, action, cutoff_at, rows_affected, finished_at) VALUES (r.entity_name, 'PURGE', v_cut, v_cnt, CURRENT_TIMESTAMP);
        END IF;
        source_entity := r.entity_name; expired_rows := v_cnt;
        RETURN NEXT;
    END LOOP;
END;
$$;

-- RT CRACKERS | 21_UPGRADE_V3/012_U29_Search_Optimization.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 29 - SEARCH OPTIMIZATION
-- search_keywords  : extra words that should find a product or category
-- search_synonyms  : "patakha" also means "crackers"
-- search_redirects : a search term that sends the visitor to a fixed page
-- All terms are stored lower case with single spaces (trigger), so lookups are plain equality.
-- Search logs (U9) already exist: search_logs.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_normalize_search_term(p_term TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT LOWER(BTRIM(regexp_replace(p_term, '\s+', ' ', 'g')))
$$;

CREATE OR REPLACE FUNCTION fn_search_terms_normalize()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_col TEXT;
BEGIN
    FOREACH v_col IN ARRAY TG_ARGV LOOP
        NEW := jsonb_populate_record(NEW, jsonb_build_object(v_col, fn_normalize_search_term(to_jsonb(NEW) ->> v_col)));
    END LOOP;
    RETURN NEW;
END;
$$;

CREATE TABLE search_keywords (
    keyword_id   BIGINT        GENERATED ALWAYS AS IDENTITY,
    keyword      VARCHAR(100)  NOT NULL,
    product_id   BIGINT,
    category_id  INTEGER,
    weight       SMALLINT      NOT NULL DEFAULT 1,
    is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_search_keywords PRIMARY KEY (keyword_id),
    CONSTRAINT fk_search_keywords_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)     ON DELETE CASCADE,
    CONSTRAINT fk_search_keywords_category FOREIGN KEY (category_id) REFERENCES categories (category_id) ON DELETE CASCADE,
    CONSTRAINT ck_search_keywords_target  CHECK ((product_id IS NOT NULL)::INT + (category_id IS NOT NULL)::INT = 1),
    CONSTRAINT ck_search_keywords_keyword CHECK (BTRIM(keyword) <> ''),
    CONSTRAINT ck_search_keywords_weight  CHECK (weight BETWEEN 1 AND 100)
);
CREATE UNIQUE INDEX uq_search_keywords_target ON search_keywords (keyword, COALESCE(product_id, 0), COALESCE(category_id, 0));
CREATE INDEX idx_search_keywords_keyword  ON search_keywords (keyword) WHERE is_active;
CREATE INDEX idx_search_keywords_product  ON search_keywords (product_id)  WHERE product_id  IS NOT NULL;
CREATE INDEX idx_search_keywords_category ON search_keywords (category_id) WHERE category_id IS NOT NULL;
CREATE TRIGGER trg_00_search_keywords_normalize BEFORE INSERT OR UPDATE ON search_keywords
    FOR EACH ROW EXECUTE FUNCTION fn_search_terms_normalize('keyword');

CREATE TABLE search_synonyms (
    synonym_id        INTEGER       GENERATED ALWAYS AS IDENTITY,
    term              VARCHAR(100)  NOT NULL,
    synonym           VARCHAR(100)  NOT NULL,
    is_bidirectional  BOOLEAN       NOT NULL DEFAULT TRUE,
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_search_synonyms PRIMARY KEY (synonym_id),
    CONSTRAINT uq_search_synonyms_pair UNIQUE (term, synonym),
    CONSTRAINT ck_search_synonyms_different CHECK (term <> synonym),
    CONSTRAINT ck_search_synonyms_blank     CHECK (BTRIM(term) <> '' AND BTRIM(synonym) <> '')
);
CREATE INDEX idx_search_synonyms_synonym ON search_synonyms (synonym) WHERE is_bidirectional;
CREATE TRIGGER trg_00_search_synonyms_normalize BEFORE INSERT OR UPDATE ON search_synonyms
    FOR EACH ROW EXECUTE FUNCTION fn_search_terms_normalize('term', 'synonym');
INSERT INTO search_synonyms (term, synonym) VALUES
    ('crackers',  'fireworks'),
    ('patakha',   'crackers'),
    ('phuljhari', 'sparklers'),
    ('anar',      'flower pot'),
    ('chakkar',   'ground chakkar'),
    ('bijli',     'lakshmi bomb'),
    ('rocket',    'sky shot');

CREATE TABLE search_redirects (
    redirect_id    INTEGER       GENERATED ALWAYS AS IDENTITY,
    search_term    VARCHAR(100)  NOT NULL,
    redirect_url   VARCHAR(500)  NOT NULL,
    valid_from     TIMESTAMP,
    valid_until    TIMESTAMP,
    is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_search_redirects PRIMARY KEY (redirect_id),
    CONSTRAINT uq_search_redirects_term UNIQUE (search_term),
    CONSTRAINT ck_search_redirects_url    CHECK (redirect_url ~* '^(https?://|/)'),
    CONSTRAINT ck_search_redirects_window CHECK (valid_from IS NULL OR valid_until IS NULL OR valid_until > valid_from)
);
CREATE TRIGGER trg_00_search_redirects_normalize BEFORE INSERT OR UPDATE ON search_redirects
    FOR EACH ROW EXECUTE FUNCTION fn_search_terms_normalize('search_term');

-- the term itself plus its synonyms (both directions where allowed)
CREATE OR REPLACE FUNCTION fn_search_expand(p_term TEXT)
RETURNS TABLE (term TEXT) LANGUAGE sql STABLE AS $$
    SELECT fn_normalize_search_term(p_term)
    UNION SELECT s.synonym FROM search_synonyms s WHERE s.is_active AND s.term = fn_normalize_search_term(p_term)
    UNION SELECT s.term    FROM search_synonyms s WHERE s.is_active AND s.is_bidirectional AND s.synonym = fn_normalize_search_term(p_term)
$$;

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

-- RT CRACKERS | 21_UPGRADE_V3/014_U32_Application_Configuration.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 32 - APPLICATION CONFIGURATION
-- system_configurations gets a value type (validated by trigger) and a public flag.
-- Company details are added as group 'company'. Fill in the blanks: the values below are empty
-- on purpose (a wrong GST number or e-mail is worse than none). v_company_profile_gaps lists them.
-- =====================================================================
ALTER TABLE system_configurations
    ADD COLUMN value_type  CHAR(1)  NOT NULL DEFAULT 'S',     -- S string, N number, B boolean, J json, E e-mail, U url, P phone, G GSTIN
    ADD COLUMN is_public   BOOLEAN  NOT NULL DEFAULT FALSE;   -- may be shown on the storefront
UPDATE system_configurations SET value_type = 'N' WHERE config_group = 'security';
ALTER TABLE system_configurations ADD CONSTRAINT ck_system_configurations_value_type CHECK (value_type IN ('S','N','B','J','E','U','P','G'));

CREATE OR REPLACE FUNCTION fn_validate_config_value()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_bad BOOLEAN;
BEGIN
    IF NEW.config_value = '' OR NEW.is_encrypted THEN RETURN NEW; END IF;
    v_bad := CASE NEW.value_type
           WHEN 'N' THEN NEW.config_value !~ '^-?[0-9]+(\.[0-9]+)?$'
           WHEN 'B' THEN NEW.config_value NOT IN ('true','false')
           WHEN 'E' THEN NEW.config_value !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
           WHEN 'U' THEN NEW.config_value !~* '^(https?://|/)\S+$'
           WHEN 'P' THEN NEW.config_value !~ '^\+?[0-9][0-9 ()-]{6,18}$'
           WHEN 'G' THEN NEW.config_value !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'
           WHEN 'J' THEN FALSE
           ELSE FALSE END;
    IF v_bad THEN
        RAISE EXCEPTION 'Configuration "%" must be a valid value of type %', NEW.config_key, NEW.value_type
            USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.value_type = 'J' THEN PERFORM NEW.config_value::JSONB; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_system_configurations_validate BEFORE INSERT OR UPDATE OF config_value, value_type ON system_configurations
    FOR EACH ROW EXECUTE FUNCTION fn_validate_config_value();

INSERT INTO system_configurations (config_group, config_key, config_value, value_type, is_public, description) VALUES
    ('company', 'company.store_name',    'RT Crackers', 'S', TRUE,  'Store name'),
    ('company', 'company.support_email', '',            'E', TRUE,  'Customer support e-mail address'),
    ('company', 'company.support_phone', '',            'P', TRUE,  'Customer support phone number'),
    ('company', 'company.gst_number',    '',            'G', TRUE,  'GSTIN printed on invoices'),
    ('company', 'company.address',       '',            'S', TRUE,  'Registered company address'),
    ('company', 'company.logo_url',      '',            'U', TRUE,  'Company logo URL'),
    ('company', 'company.terms_url',     '',            'U', TRUE,  'Terms and conditions page URL'),
    ('company', 'company.privacy_url',   '',            'U', TRUE,  'Privacy policy page URL');

CREATE VIEW v_company_profile WITH (security_invoker = true) AS
SELECT MAX(config_value) FILTER (WHERE config_key = 'company.store_name')    AS store_name,
       MAX(config_value) FILTER (WHERE config_key = 'company.support_email') AS support_email,
       MAX(config_value) FILTER (WHERE config_key = 'company.support_phone') AS support_phone,
       MAX(config_value) FILTER (WHERE config_key = 'company.gst_number')    AS gst_number,
       MAX(config_value) FILTER (WHERE config_key = 'company.address')       AS company_address,
       MAX(config_value) FILTER (WHERE config_key = 'company.logo_url')      AS company_logo_url,
       MAX(config_value) FILTER (WHERE config_key = 'company.terms_url')     AS terms_url,
       MAX(config_value) FILTER (WHERE config_key = 'company.privacy_url')   AS privacy_url
  FROM system_configurations
 WHERE config_group = 'company' AND is_active;

CREATE VIEW v_company_profile_gaps WITH (security_invoker = true) AS
SELECT config_key, description FROM system_configurations
 WHERE config_group = 'company' AND is_active AND BTRIM(config_value) = '';

-- RT CRACKERS | 21_UPGRADE_V3/015_U33_Security_Audit_Enhancement.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 33 - SECURITY AUDIT ENHANCEMENT
-- audit_logs gets session, device, browser, operating system, country and city.
-- Filled automatically from the same session settings the audit trigger already reads:
--   SET LOCAL app.session_id = '<uuid>';  app.device_type = 'W|M|T|O';  app.browser;  app.os;
--   app.country;  app.city      (plus the existing app.current_user_id / app.client_ip / app.user_agent)
-- When app.browser / app.os / app.device_type are missing they are worked out from app.user_agent.
-- country / city need a geo-IP lookup in your application: the database cannot guess them.
-- session_id has no foreign key on purpose: audit rows must survive session clean-up.
-- =====================================================================
ALTER TABLE audit_logs
    ADD COLUMN session_id        UUID,
    ADD COLUMN device_type       CHAR(1),
    ADD COLUMN browser           VARCHAR(60),
    ADD COLUMN operating_system  VARCHAR(60),
    ADD COLUMN country           VARCHAR(80),
    ADD COLUMN city              VARCHAR(100),
    ADD CONSTRAINT ck_audit_logs_device_type CHECK (device_type IS NULL OR device_type IN ('W','M','T','O'));
CREATE INDEX idx_audit_logs_session ON audit_logs (session_id) WHERE session_id IS NOT NULL;

CREATE OR REPLACE FUNCTION fn_ua_browser(p_ua TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN p_ua IS NULL OR BTRIM(p_ua) = '' THEN NULL
                WHEN p_ua ~* 'Edg(e|A|iOS)?/'                    THEN 'Edge'
                WHEN p_ua ~* 'OPR/|Opera'                        THEN 'Opera'
                WHEN p_ua ~* 'SamsungBrowser'                    THEN 'Samsung Internet'
                WHEN p_ua ~* 'Firefox/|FxiOS'                    THEN 'Firefox'
                WHEN p_ua ~* 'Chrome/|CriOS'                     THEN 'Chrome'
                WHEN p_ua ~* 'Safari/'                           THEN 'Safari'
                WHEN p_ua ~* 'curl|wget|postman|python|okhttp|axios|node-fetch|insomnia' THEN 'API client'
                ELSE 'Other' END
$$;

CREATE OR REPLACE FUNCTION fn_ua_os(p_ua TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN p_ua IS NULL OR BTRIM(p_ua) = '' THEN NULL
                WHEN p_ua ~* 'Windows'                          THEN 'Windows'
                WHEN p_ua ~* 'Android'                          THEN 'Android'
                WHEN p_ua ~* 'iPhone|iPad|iPod'                 THEN 'iOS'
                WHEN p_ua ~* 'Mac OS X|Macintosh'               THEN 'macOS'
                WHEN p_ua ~* 'CrOS'                             THEN 'ChromeOS'
                WHEN p_ua ~* 'Linux|X11'                        THEN 'Linux'
                ELSE 'Other' END
$$;

CREATE OR REPLACE FUNCTION fn_ua_device_type(p_ua TEXT)
RETURNS CHAR(1) LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN p_ua IS NULL OR BTRIM(p_ua) = '' THEN NULL
                WHEN p_ua ~* 'iPad|Tablet'                      THEN 'T'
                WHEN p_ua ~* 'Android' AND p_ua !~* 'Mobile'    THEN 'T'
                WHEN p_ua ~* 'Mobi|iPhone|Android'              THEN 'M'
                WHEN p_ua ~* 'bot|crawler|spider|curl|wget|postman|python|okhttp' THEN 'O'
                ELSE 'W' END
$$;

-- same behaviour as v2 (arg 0 = primary key column, further args = JSON keys to strip) plus the new context columns
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk      TEXT   := TG_ARGV[0];
    v_redact  TEXT[] := CASE WHEN TG_NARGS > 1 THEN TG_ARGV[1:TG_NARGS - 1] ELSE ARRAY[]::TEXT[] END;
    v_old     JSONB;
    v_new     JSONB;
    v_ua      TEXT   := LEFT(NULLIF(current_setting('app.user_agent', TRUE), ''), 500);
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN v_old := to_jsonb(OLD) - v_redact; END IF;
    IF TG_OP IN ('INSERT','UPDATE') THEN v_new := to_jsonb(NEW) - v_redact; END IF;
    INSERT INTO audit_logs (table_name, record_id, action_type, old_value, new_value, changed_by, ip_address, user_agent,
                            session_id, device_type, browser, operating_system, country, city)
    VALUES (TG_TABLE_NAME, COALESCE(v_new ->> v_pk, v_old ->> v_pk), TG_OP, v_old, v_new,
            NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT,
            NULLIF(current_setting('app.client_ip', TRUE), '')::INET,
            v_ua,
            NULLIF(current_setting('app.session_id', TRUE), '')::UUID,
            COALESCE(NULLIF(current_setting('app.device_type', TRUE), ''), fn_ua_device_type(v_ua)),
            COALESCE(NULLIF(current_setting('app.browser', TRUE), ''),     fn_ua_browser(v_ua)),
            COALESCE(NULLIF(current_setting('app.os', TRUE), ''),          fn_ua_os(v_ua)),
            NULLIF(current_setting('app.country', TRUE), ''),
            NULLIF(current_setting('app.city', TRUE), ''));
    RETURN NULL;
END;
$$;

-- LOGIN entries now carry the session and the device details
CREATE OR REPLACE FUNCTION fn_login_history_effects()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_device CHAR(1);
BEGIN
    IF NEW.user_id IS NULL THEN RETURN NULL; END IF;
    IF NEW.login_status = 'S' THEN
        UPDATE users SET last_login_ip = NEW.ip_address, last_device = LEFT(NEW.user_agent, 255)
         WHERE user_id = NEW.user_id;
        SELECT s.device_type INTO v_device FROM sessions s WHERE s.session_id = NEW.session_id;
        INSERT INTO audit_logs (table_name, record_id, action_type, new_value, changed_by, ip_address, user_agent,
                                session_id, device_type, browser, operating_system, country, city)
        VALUES ('users', NEW.user_id::TEXT, 'LOGIN', jsonb_build_object('session_id', NEW.session_id),
                NEW.user_id, NEW.ip_address, NEW.user_agent,
                NEW.session_id,
                COALESCE(v_device, fn_ua_device_type(NEW.user_agent)),
                fn_ua_browser(NEW.user_agent), fn_ua_os(NEW.user_agent),
                NULLIF(current_setting('app.country', TRUE), ''), NULLIF(current_setting('app.city', TRUE), ''));
    ELSIF NEW.login_status = 'F' THEN
        UPDATE users SET last_failed_login = NEW.created_at WHERE user_id = NEW.user_id;
    END IF;
    RETURN NULL;
END;
$$;

-- LOGOUT entries too
CREATE OR REPLACE FUNCTION fn_session_logout_audit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_logs (table_name, record_id, action_type, new_value, changed_by, ip_address, user_agent,
                            session_id, device_type, browser, operating_system, country, city)
    VALUES ('users', NEW.user_id::TEXT, 'LOGOUT', jsonb_build_object('session_id', NEW.session_id),
            NEW.user_id, NEW.ip_address, NEW.user_agent,
            NEW.session_id, NEW.device_type, fn_ua_browser(NEW.user_agent), fn_ua_os(NEW.user_agent),
            NULLIF(current_setting('app.country', TRUE), ''), NULLIF(current_setting('app.city', TRUE), ''));
    RETURN NULL;
END;
$$;

-- RT CRACKERS | 21_UPGRADE_V3/016_U36_Document_Management.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 36 - DOCUMENT MANAGEMENT
-- Manuals, safety data sheets, licences and certificates. The file itself lives in storage
-- (Supabase Storage / S3); the database keeps the metadata and what each document is attached to.
-- document_links is polymorphic: entity_name is a table name, entity_id its primary key as text.
-- =====================================================================
CREATE TABLE document_types (
    document_type_id   SMALLINT      GENERATED ALWAYS AS IDENTITY,
    type_code          VARCHAR(30)   NOT NULL,
    type_name          VARCHAR(80)   NOT NULL,
    description        VARCHAR(255),
    requires_expiry    BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_document_types PRIMARY KEY (document_type_id),
    CONSTRAINT uq_document_types_code UNIQUE (type_code),
    CONSTRAINT uq_document_types_name UNIQUE (type_name),
    CONSTRAINT ck_document_types_code CHECK (type_code = UPPER(type_code))
);
INSERT INTO document_types (type_code, type_name, description, requires_expiry) VALUES
    ('USER_MANUAL',        'User manual',             'How to use a product',                         FALSE),
    ('SAFETY_DATA_SHEET',  'Safety data sheet',       'Handling, storage and fire-safety information', FALSE),
    ('PESO_LICENCE',       'PESO licence',            'Explosives licence for manufacture, storage or sale', TRUE),
    ('TEST_CERTIFICATE',   'Test certificate',        'Laboratory or batch test report',              TRUE),
    ('COMPLIANCE_CERT',    'Compliance certificate',  'Statutory or quality certification',           TRUE),
    ('PRODUCT_BROCHURE',   'Product brochure',        'Marketing material',                           FALSE),
    ('LEGAL_POLICY',       'Legal policy',            'Terms, privacy, returns policy',               FALSE),
    ('OTHER',              'Other',                   'Anything else',                                FALSE);

CREATE TABLE documents (
    document_id        BIGINT        GENERATED ALWAYS AS IDENTITY,
    document_number    VARCHAR(20)   NOT NULL DEFAULT fn_next_business_code('DOCUMENT'),
    document_type_id   SMALLINT      NOT NULL,
    classification_id  SMALLINT,
    title              VARCHAR(200)  NOT NULL,
    description        TEXT,
    file_url           VARCHAR(500)  NOT NULL,
    file_name          VARCHAR(255),
    mime_type          VARCHAR(100),
    file_size_bytes    BIGINT,
    checksum_sha256    CHAR(64),
    version_label      VARCHAR(20)   NOT NULL DEFAULT '1.0',
    issued_by          VARCHAR(150),
    issue_date         DATE,
    expiry_date        DATE,
    is_public          BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE,
    uploaded_by        BIGINT,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_documents PRIMARY KEY (document_id),
    CONSTRAINT uq_documents_number UNIQUE (document_number),
    CONSTRAINT fk_documents_type           FOREIGN KEY (document_type_id)  REFERENCES document_types (document_type_id)       ON DELETE RESTRICT,
    CONSTRAINT fk_documents_classification FOREIGN KEY (classification_id) REFERENCES data_classification (classification_id) ON DELETE RESTRICT,
    CONSTRAINT fk_documents_uploaded_by    FOREIGN KEY (uploaded_by)       REFERENCES users (user_id)                          ON DELETE SET NULL,
    CONSTRAINT ck_documents_number   CHECK (document_number ~ '^DOC[0-9]{8}$'),
    CONSTRAINT ck_documents_file_url CHECK (file_url ~* '^(https?://|/|[a-z0-9_-]+/)'),
    CONSTRAINT ck_documents_size     CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0),
    CONSTRAINT ck_documents_checksum CHECK (checksum_sha256 IS NULL OR checksum_sha256 ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_documents_dates    CHECK (issue_date IS NULL OR expiry_date IS NULL OR expiry_date >= issue_date)
);
CREATE INDEX idx_documents_type        ON documents (document_type_id);
CREATE INDEX idx_documents_expiry      ON documents (expiry_date) WHERE expiry_date IS NOT NULL AND is_active;
CREATE INDEX idx_documents_uploaded_by ON documents (uploaded_by) WHERE uploaded_by IS NOT NULL;

CREATE TABLE document_links (
    document_link_id  BIGINT       GENERATED ALWAYS AS IDENTITY,
    document_id       BIGINT       NOT NULL,
    entity_name       VARCHAR(63)  NOT NULL,
    entity_id         VARCHAR(64)  NOT NULL,
    link_role         VARCHAR(30)  NOT NULL DEFAULT 'ATTACHMENT',
    display_order     SMALLINT     NOT NULL DEFAULT 0,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_document_links PRIMARY KEY (document_link_id),
    CONSTRAINT uq_document_links_target UNIQUE (document_id, entity_name, entity_id, link_role),
    CONSTRAINT fk_document_links_document FOREIGN KEY (document_id) REFERENCES documents (document_id) ON DELETE CASCADE,
    CONSTRAINT ck_document_links_role CHECK (link_role = UPPER(link_role))
);
CREATE INDEX idx_document_links_entity ON document_links (entity_name, entity_id);

CREATE OR REPLACE FUNCTION fn_document_link_check()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF to_regclass(format('public.%I', NEW.entity_name)) IS NULL THEN
        RAISE EXCEPTION 'document_links.entity_name "%" is not a table', NEW.entity_name USING ERRCODE = 'foreign_key_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_document_links_check BEFORE INSERT OR UPDATE OF entity_name ON document_links
    FOR EACH ROW EXECUTE FUNCTION fn_document_link_check();

-- licences / certificates that need an expiry date must carry one
CREATE OR REPLACE FUNCTION fn_document_expiry_check()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.expiry_date IS NULL AND EXISTS (SELECT 1 FROM document_types t WHERE t.document_type_id = NEW.document_type_id AND t.requires_expiry) THEN
        RAISE EXCEPTION 'This document type requires an expiry_date' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_documents_expiry_check BEFORE INSERT OR UPDATE OF document_type_id, expiry_date ON documents
    FOR EACH ROW EXECUTE FUNCTION fn_document_expiry_check();

-- RT CRACKERS | 21_UPGRADE_V3/017_U37_System_Health_Monitoring.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 37 - SYSTEM HEALTH MONITORING
-- fn_record_system_health() stores one reading. The database knows its own size and the number of
-- open login sessions; CPU and memory come from the platform, so your scheduler passes them in:
--   SELECT fn_record_system_health(37.5, 61.2);
-- Warning / critical thresholds are business rules (health.* in business_rules).
-- =====================================================================
CREATE TABLE system_health_checks (
    health_check_id      BIGINT        GENERATED ALWAYS AS IDENTITY,
    checked_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cpu_usage            NUMERIC(5,2),
    memory_usage         NUMERIC(5,2),
    database_size_bytes  BIGINT        NOT NULL,
    active_sessions      INTEGER       NOT NULL,
    db_connections       INTEGER,
    health_status        CHAR(1)       NOT NULL DEFAULT 'H',      -- H healthy, W warning, C critical
    source               VARCHAR(40)   NOT NULL DEFAULT 'database',
    notes                VARCHAR(255),
    CONSTRAINT pk_system_health_checks PRIMARY KEY (health_check_id),
    CONSTRAINT ck_system_health_checks_cpu      CHECK (cpu_usage    IS NULL OR cpu_usage    BETWEEN 0 AND 100),
    CONSTRAINT ck_system_health_checks_memory   CHECK (memory_usage IS NULL OR memory_usage BETWEEN 0 AND 100),
    CONSTRAINT ck_system_health_checks_size     CHECK (database_size_bytes >= 0),
    CONSTRAINT ck_system_health_checks_sessions CHECK (active_sessions >= 0 AND (db_connections IS NULL OR db_connections >= 0)),
    CONSTRAINT ck_system_health_checks_status   CHECK (health_status IN ('H','W','C'))
);
CREATE INDEX idx_system_health_checks_time ON system_health_checks (checked_at DESC);

CREATE OR REPLACE FUNCTION fn_record_system_health(p_cpu NUMERIC DEFAULT NULL, p_memory NUMERIC DEFAULT NULL, p_source TEXT DEFAULT 'database')
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_status  CHAR(1) := 'H';
    v_id      BIGINT;
BEGIN
    IF p_cpu    >= COALESCE(fn_rule_number('health.cpu_critical_percent'),    101)
    OR p_memory >= COALESCE(fn_rule_number('health.memory_critical_percent'), 101) THEN
        v_status := 'C';
    ELSIF p_cpu    >= COALESCE(fn_rule_number('health.cpu_warning_percent'),    101)
       OR p_memory >= COALESCE(fn_rule_number('health.memory_warning_percent'), 101) THEN
        v_status := 'W';
    END IF;
    INSERT INTO system_health_checks (cpu_usage, memory_usage, database_size_bytes, active_sessions, db_connections, health_status, source)
    VALUES (p_cpu, p_memory, pg_database_size(current_database()),
            (SELECT COUNT(*) FROM sessions WHERE ended_at IS NULL AND expires_at > CURRENT_TIMESTAMP),
            (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = current_database()),
            v_status, LEFT(p_source, 40))
    RETURNING health_check_id INTO v_id;
    RETURN v_id;
END;
$$;

-- RT CRACKERS | 21_UPGRADE_V3/018_U34_Data_Ownership_Tracking.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 34 - DATA OWNERSHIP TRACKING
-- created_by / updated_by on the major tables, stamped by trigger from the session setting the
-- application already sets for auditing:  SET LOCAL app.current_user_id = '<users.user_id>';
--   * new columns point at users (same convention as deleted_by from U4)
--   * tables that already had admin-based created_by / updated_by (coupons, banners, newsletters,
--     notifications, settings) keep pointing at admins and are stamped from app.current_admin_id
-- created_by never changes after insert. updated_by changes only when the session identifies a user.
-- Foreign keys on these columns are intentionally not indexed (low selectivity, never filtered on).
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_stamp_owner_user()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_uid BIGINT := NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.created_by := COALESCE(NEW.created_by, v_uid);
        NEW.updated_by := COALESCE(NEW.updated_by, v_uid);
    ELSE
        NEW.created_by := OLD.created_by;
        IF v_uid IS NOT NULL THEN NEW.updated_by := v_uid; END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_stamp_owner_admin()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_aid INTEGER := NULLIF(current_setting('app.current_admin_id', TRUE), '')::INTEGER;
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.created_by := COALESCE(NEW.created_by, v_aid);
        NEW.updated_by := COALESCE(NEW.updated_by, v_aid);
    ELSE
        NEW.created_by := OLD.created_by;
        IF v_aid IS NOT NULL THEN NEW.updated_by := v_aid; END IF;
    END IF;
    RETURN NEW;
END;
$$;

DO $$
DECLARE
    t    TEXT;
    c    TEXT;
BEGIN
    -- users-based ownership
    FOREACH t IN ARRAY ARRAY[
        'users','products','product_variants','product_images','product_seo','categories','subcategories','brands','inventory',
        'orders','invoices','return_requests','replacement_requests','refunds','shipments','reviews','addresses','festivals',
        'delivery_zones','shipping_methods','payment_methods','feature_flags','system_configurations','roles','permissions',
        'business_rules','country_configurations','data_retention_policies','data_quality_rules','reference_data','product_types',
        'collections','seasons','search_synonyms','search_redirects','documents','document_types','data_classification',
        'data_classification_assignments'] LOOP
        FOREACH c IN ARRAY ARRAY['created_by','updated_by'] LOOP
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = c) THEN
                EXECUTE format('ALTER TABLE %I ADD COLUMN %I BIGINT', t, c);
                EXECUTE format('ALTER TABLE %I ADD CONSTRAINT fk_%s_%s FOREIGN KEY (%I) REFERENCES users (user_id) ON DELETE SET NULL', t, t, c, c);
            END IF;
        END LOOP;
        EXECUTE format('CREATE TRIGGER trg_%1$s_owner BEFORE INSERT OR UPDATE ON %1$I FOR EACH ROW EXECUTE FUNCTION fn_stamp_owner_user()', t);
    END LOOP;

    -- admin-based ownership (these tables already had admin-typed columns)
    FOREACH t IN ARRAY ARRAY['coupons','banners','newsletters','notifications','settings'] LOOP
        FOREACH c IN ARRAY ARRAY['created_by','updated_by'] LOOP
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = c) THEN
                EXECUTE format('ALTER TABLE %I ADD COLUMN %I INTEGER', t, c);
                EXECUTE format('ALTER TABLE %I ADD CONSTRAINT fk_%s_%s FOREIGN KEY (%I) REFERENCES admins (admin_id) ON DELETE SET NULL', t, t, c, c);
            END IF;
        END LOOP;
        EXECUTE format('CREATE TRIGGER trg_%1$s_owner BEFORE INSERT OR UPDATE ON %1$I FOR EACH ROW EXECUTE FUNCTION fn_stamp_owner_admin()', t);
    END LOOP;
END;
$$;

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

-- RT CRACKERS | 21_UPGRADE_V3/021_U40_Database_Documentation_Table.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 40 - DATABASE DOCUMENTATION TABLE
-- database_metadata: one row per table - what it is for, who owns it, which module it belongs to.
--   * seeded for every table that exists after this upgrade
--   * description defaults to the table's COMMENT when it has one, otherwise to the business purpose
--   * the owner column holds a team name, not a person: change it to match your organisation
--   * fn_refresh_database_metadata() adds a placeholder row for any table created later;
--     v_undocumented_tables lists tables that still have none, v_stale_metadata lists rows whose table was dropped
-- =====================================================================
CREATE TABLE database_metadata (
    metadata_id       INTEGER       GENERATED ALWAYS AS IDENTITY,
    table_name        VARCHAR(63)   NOT NULL,
    business_purpose  VARCHAR(255)  NOT NULL,
    owner             VARCHAR(80)   NOT NULL,
    module            VARCHAR(40)   NOT NULL,
    description       TEXT          NOT NULL,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_database_metadata PRIMARY KEY (metadata_id),
    CONSTRAINT uq_database_metadata_table UNIQUE (table_name),
    CONSTRAINT ck_database_metadata_purpose CHECK (BTRIM(business_purpose) <> ''),
    CONSTRAINT ck_database_metadata_module CHECK (module ~ '^[A-Z_]+$')
);
CREATE INDEX idx_database_metadata_module ON database_metadata (module);
COMMENT ON TABLE database_metadata IS 'Self-documenting database: purpose, owner and module of every table.';

INSERT INTO database_metadata (table_name, module, owner, business_purpose, description)
SELECT v.table_name, v.module, v.owner, v.purpose, COALESCE(obj_description(to_regclass('public.' || v.table_name), 'pg_class'), v.purpose)
FROM (VALUES
    ('users', 'AUTHENTICATION', 'Security & Access', 'Customer accounts: login identity, contact details and status'),
    ('user_profiles', 'AUTHENTICATION', 'Security & Access', 'Extra personal details for each customer account'),
    ('roles', 'AUTHENTICATION', 'Security & Access', 'Named access roles (customer, staff, admin)'),
    ('permissions', 'AUTHENTICATION', 'Security & Access', 'Individual permissions that roles can be granted'),
    ('role_permissions', 'AUTHENTICATION', 'Security & Access', 'Which permissions each role holds'),
    ('user_roles', 'AUTHENTICATION', 'Security & Access', 'Which roles each user has'),
    ('sessions', 'AUTHENTICATION', 'Security & Access', 'Active and past login sessions'),
    ('refresh_tokens', 'AUTHENTICATION', 'Security & Access', 'Long-lived tokens used to renew login sessions'),
    ('login_history', 'AUTHENTICATION', 'Security & Access', 'Every sign-in attempt with outcome and device'),
    ('password_reset_tokens', 'AUTHENTICATION', 'Security & Access', 'One-time tokens for password recovery'),
    ('user_status_master', 'AUTHENTICATION', 'Security & Access', 'Lookup of account statuses (active, blocked, ...)'),
    ('genders', 'AUTHENTICATION', 'Security & Access', 'Lookup of gender values for user profiles'),
    ('admins', 'ADMIN', 'Security & Access', 'Back-office staff accounts'),
    ('admin_roles', 'ADMIN', 'Security & Access', 'Roles available to back-office staff'),
    ('admin_permissions', 'ADMIN', 'Security & Access', 'Permissions granted to back-office roles'),
    ('admin_activity_logs', 'ADMIN', 'Security & Access', 'What each admin did in the back office'),
    ('admin_notifications', 'ADMIN', 'Security & Access', 'Alerts shown to back-office staff'),
    ('countries', 'GEOGRAPHY', 'Data Management', 'Countries the store can serve'),
    ('states', 'GEOGRAPHY', 'Data Management', 'States / provinces within a country'),
    ('districts', 'GEOGRAPHY', 'Data Management', 'Districts within a state'),
    ('cities', 'GEOGRAPHY', 'Data Management', 'Cities and towns within a district'),
    ('postal_codes', 'GEOGRAPHY', 'Data Management', 'Postal (PIN) codes with their city and delivery coverage'),
    ('address_types', 'GEOGRAPHY', 'Data Management', 'Lookup of address labels (home, office, warehouse, other)'),
    ('country_configurations', 'GEOGRAPHY', 'Data Management', 'Per-country currency, tax rate, phone and postal rules'),
    ('addresses', 'CUSTOMERS', 'Customer Experience', 'Customer delivery and billing addresses'),
    ('saved_addresses', 'CUSTOMERS', 'Customer Experience', 'Addresses a customer has bookmarked for reuse'),
    ('recently_viewed_products', 'CUSTOMERS', 'Customer Experience', 'Products a customer looked at recently'),
    ('categories', 'MASTER_DATA', 'Catalogue Team', 'Top-level product categories'),
    ('subcategories', 'MASTER_DATA', 'Catalogue Team', 'Second-level product categories'),
    ('brands', 'MASTER_DATA', 'Catalogue Team', 'Product brands'),
    ('product_attributes', 'MASTER_DATA', 'Catalogue Team', 'Attribute definitions such as colour, size, shots'),
    ('attribute_values', 'MASTER_DATA', 'Catalogue Team', 'Allowed values for each product attribute'),
    ('product_types', 'MASTER_DATA', 'Catalogue Team', 'Lookup of product types used for filtering'),
    ('collections', 'MASTER_DATA', 'Catalogue Team', 'Curated product collections'),
    ('seasons', 'MASTER_DATA', 'Catalogue Team', 'Seasonal groupings such as Diwali or New Year'),
    ('reference_data', 'MASTER_DATA', 'Catalogue Team', 'Central lookup values (languages, currencies, device types, ...)'),
    ('products', 'PRODUCTS', 'Catalogue Team', 'The product catalogue: price, stock, SKU and descriptive data'),
    ('product_images', 'PRODUCTS', 'Catalogue Team', 'Images attached to products'),
    ('product_variants', 'PRODUCTS', 'Catalogue Team', 'Sellable variants of a product (pack size, colour)'),
    ('product_seo', 'PRODUCTS', 'Catalogue Team', 'Search-engine titles, descriptions and slugs for products'),
    ('product_audit_logs', 'PRODUCTS', 'Catalogue Team', 'History of changes made to products'),
    ('product_collections', 'PRODUCTS', 'Catalogue Team', 'Links products to collections'),
    ('product_seasons', 'PRODUCTS', 'Catalogue Team', 'Links products to seasons'),
    ('inventory', 'INVENTORY', 'Warehouse & Inventory', 'Current stock level per product or variant'),
    ('inventory_movements', 'INVENTORY', 'Warehouse & Inventory', 'Every stock-in, stock-out and adjustment'),
    ('carts', 'CART', 'Customer Experience', 'Shopping carts, one per customer or guest session'),
    ('cart_items', 'CART', 'Customer Experience', 'Lines inside a shopping cart'),
    ('cart_abandonment_logs', 'CART', 'Customer Experience', 'Carts left without checkout, for follow-up'),
    ('wishlists', 'WISHLIST', 'Customer Experience', 'Customer wishlists'),
    ('wishlist_items', 'WISHLIST', 'Customer Experience', 'Products saved in a wishlist'),
    ('comparisons', 'COMPARISON', 'Customer Experience', 'Product comparison sessions'),
    ('comparison_items', 'COMPARISON', 'Customer Experience', 'Products placed in a comparison'),
    ('orders', 'ORDERS', 'Order Management', 'Customer orders with totals, addresses and current status'),
    ('order_items', 'ORDERS', 'Order Management', 'Product lines of each order'),
    ('order_status_history', 'ORDERS', 'Order Management', 'Every status change an order went through'),
    ('order_tracking_events', 'ORDERS', 'Order Management', 'Tracking milestones shown to the customer'),
    ('invoices', 'ORDERS', 'Order Management', 'Tax invoices issued for orders'),
    ('return_requests', 'ORDERS', 'Order Management', 'Customer requests to return items'),
    ('replacement_requests', 'ORDERS', 'Order Management', 'Customer requests to replace items'),
    ('order_status_master', 'ORDERS', 'Order Management', 'Lookup of order statuses'),
    ('payment_methods', 'PAYMENTS', 'Finance', 'Accepted payment methods'),
    ('cod_transactions', 'PAYMENTS', 'Finance', 'Cash-on-delivery payment records'),
    ('cash_collection_logs', 'PAYMENTS', 'Finance', 'Cash handed over by delivery agents'),
    ('refunds', 'PAYMENTS', 'Finance', 'Refunds issued to customers'),
    ('payment_status_master', 'PAYMENTS', 'Finance', 'Lookup of payment statuses'),
    ('delivery_zones', 'SHIPPING', 'Logistics', 'Delivery zones and their coverage'),
    ('shipping_methods', 'SHIPPING', 'Logistics', 'Available shipping options'),
    ('shipments', 'SHIPPING', 'Logistics', 'Shipments created for orders'),
    ('zone_shipping_rates', 'SHIPPING', 'Logistics', 'Shipping charges by zone and method'),
    ('shipment_status_master', 'SHIPPING', 'Logistics', 'Lookup of shipment statuses'),
    ('reviews', 'REVIEWS', 'Customer Experience', 'Customer product reviews and ratings'),
    ('review_images', 'REVIEWS', 'Customer Experience', 'Photos attached to reviews'),
    ('review_reports', 'REVIEWS', 'Customer Experience', 'Customer reports of inappropriate reviews'),
    ('review_status_master', 'REVIEWS', 'Customer Experience', 'Lookup of review moderation statuses'),
    ('coupons', 'MARKETING', 'Marketing', 'Discount coupons and their rules'),
    ('coupon_usage', 'MARKETING', 'Marketing', 'Every redemption of a coupon'),
    ('banners', 'MARKETING', 'Marketing', 'Homepage and promotional banners'),
    ('newsletters', 'MARKETING', 'Marketing', 'Newsletters prepared for sending'),
    ('newsletter_subscribers', 'MARKETING', 'Marketing', 'People subscribed to the newsletter'),
    ('referral_rewards', 'MARKETING', 'Marketing', 'Rewards earned through referral codes'),
    ('notifications', 'NOTIFICATIONS', 'Customer Experience', 'Notification messages defined by the business'),
    ('user_notifications', 'NOTIFICATIONS', 'Customer Experience', 'Notifications delivered to each user'),
    ('email_templates', 'NOTIFICATIONS', 'Customer Experience', 'Reusable e-mail templates'),
    ('festivals', 'FESTIVALS', 'Marketing', 'Festival campaigns and their dates'),
    ('festival_products', 'FESTIVALS', 'Marketing', 'Products featured in a festival'),
    ('festival_banners', 'FESTIVALS', 'Marketing', 'Banners shown during a festival'),
    ('festival_discounts', 'FESTIVALS', 'Marketing', 'Discounts that apply during a festival'),
    ('page_views', 'ANALYTICS', 'Analytics', 'Website page view events'),
    ('product_views', 'ANALYTICS', 'Analytics', 'Product page view events'),
    ('search_logs', 'ANALYTICS', 'Analytics', 'What customers searched for and what they found'),
    ('sales_reports', 'ANALYTICS', 'Analytics', 'Pre-aggregated sales figures'),
    ('user_activity_logs', 'ANALYTICS', 'Analytics', 'Customer activity trail for analysis'),
    ('dashboard_metrics', 'ANALYTICS', 'Analytics', 'Metrics shown on the admin dashboard'),
    ('revenue_analytics', 'ANALYTICS', 'Analytics', 'Revenue broken down by period and dimension'),
    ('product_analytics', 'ANALYTICS', 'Analytics', 'Per-product performance figures'),
    ('customer_analytics', 'ANALYTICS', 'Analytics', 'Per-customer behaviour figures'),
    ('conversion_analytics', 'ANALYTICS', 'Analytics', 'Funnel and conversion figures'),
    ('settings', 'SYSTEM', 'Platform Engineering', 'General store settings'),
    ('feature_flags', 'SYSTEM', 'Platform Engineering', 'Switches that turn features on or off'),
    ('system_configurations', 'SYSTEM', 'Platform Engineering', 'Typed application configuration (store name, support contact, GST number, URLs)'),
    ('error_logs', 'SYSTEM', 'Platform Engineering', 'Application and database errors'),
    ('audit_logs', 'SYSTEM', 'Platform Engineering', 'Row-level change history with user, session and device'),
    ('business_rules', 'SYSTEM', 'Platform Engineering', 'Business limits and periods kept as data (cart size, return days, ...)'),
    ('system_health_checks', 'SYSTEM', 'Platform Engineering', 'Periodic CPU, memory, size and session readings'),
    ('business_code_definitions', 'GOVERNANCE', 'Data Management', 'Format of every business code (PRD, ORD, INV, RET, CPN, ...)'),
    ('business_code_counters', 'GOVERNANCE', 'Data Management', 'Last number issued for each business code and year'),
    ('schema_versions', 'GOVERNANCE', 'Data Management', 'Which upgrade scripts have been applied'),
    ('data_retention_policies', 'GOVERNANCE', 'Data Management', 'How long each kind of data is kept and when it is archived'),
    ('archive_runs', 'GOVERNANCE', 'Data Management', 'Log of each archive job and how many rows it moved'),
    ('archived_orders', 'GOVERNANCE', 'Data Management', 'Old orders moved out of the active table'),
    ('archived_logs', 'GOVERNANCE', 'Data Management', 'Old log rows moved out of the active tables'),
    ('archived_notifications', 'GOVERNANCE', 'Data Management', 'Old notifications moved out of the active table'),
    ('search_keywords', 'GOVERNANCE', 'Data Management', 'Keywords that drive search suggestions and ranking'),
    ('search_synonyms', 'GOVERNANCE', 'Data Management', 'Words treated as equivalent in search'),
    ('search_redirects', 'GOVERNANCE', 'Data Management', 'Search terms that jump straight to a page'),
    ('data_quality_rules', 'GOVERNANCE', 'Data Management', 'Validation rules used to detect invalid data'),
    ('data_quality_results', 'GOVERNANCE', 'Data Management', 'Outcome of each data quality run'),
    ('data_classification', 'GOVERNANCE', 'Data Management', 'Sensitivity levels: PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED'),
    ('data_classification_assignments', 'GOVERNANCE', 'Data Management', 'Sensitivity level assigned to each table or column'),
    ('entity_versions', 'GOVERNANCE', 'Data Management', 'Version history of master data rows'),
    ('documents', 'GOVERNANCE', 'Data Management', 'Manuals, certificates and other files'),
    ('document_types', 'GOVERNANCE', 'Data Management', 'Lookup of document kinds'),
    ('document_links', 'GOVERNANCE', 'Data Management', 'Links documents to products or other records'),
    ('database_metadata', 'GOVERNANCE', 'Data Management', 'This catalogue: what each table is for, who owns it, which module it belongs to')
) AS v(table_name, module, owner, purpose);

CREATE OR REPLACE FUNCTION fn_refresh_database_metadata()
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_added INTEGER;
BEGIN
    INSERT INTO database_metadata (table_name, business_purpose, owner, module, description)
    SELECT t.tablename, 'To be documented', 'Unassigned', 'UNASSIGNED',
           COALESCE(obj_description(format('public.%I', t.tablename)::regclass, 'pg_class'), 'To be documented')
      FROM pg_tables t
     WHERE t.schemaname = 'public' AND NOT EXISTS (SELECT 1 FROM database_metadata m WHERE m.table_name = t.tablename);
    GET DIAGNOSTICS v_added = ROW_COUNT;
    RETURN v_added;
END;
$$;

CREATE VIEW v_undocumented_tables WITH (security_invoker = true) AS
SELECT t.tablename AS table_name
  FROM pg_tables t
 WHERE t.schemaname = 'public'
   AND NOT EXISTS (SELECT 1 FROM database_metadata m WHERE m.table_name = t.tablename AND m.module <> 'UNASSIGNED');

CREATE VIEW v_stale_metadata WITH (security_invoker = true) AS
SELECT m.table_name, m.module
  FROM database_metadata m
 WHERE to_regclass(format('public.%I', m.table_name)) IS NULL;

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

-- RT CRACKERS | 21_UPGRADE_V3/023_Verification.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- VERIFICATION  (any miss aborts and rolls back the whole upgrade)
-- =====================================================================
DO $$
DECLARE
    v_missing TEXT;
    v_tables  INTEGER;
    v_fks     INTEGER;
    v_cons    INTEGER;
    v_cols    INTEGER;
BEGIN
    -- every table the upgrade promises
    SELECT string_agg(req.name, ', ') INTO v_missing
      FROM (VALUES
        ('business_code_definitions'), ('business_code_counters'), ('order_status_master'), ('payment_status_master'),
        ('shipment_status_master'), ('review_status_master'), ('user_status_master'), ('genders'), ('address_types'),
        ('business_rules'), ('country_configurations'), ('product_types'), ('collections'), ('seasons'),
        ('data_retention_policies'), ('archived_orders'), ('archived_logs'), ('archived_notifications'),
        ('search_keywords'), ('search_synonyms'), ('search_redirects'), ('data_quality_rules'), ('reference_data'),
        ('entity_versions'), ('documents'), ('document_types'), ('document_links'), ('system_health_checks'),
        ('data_classification'), ('database_metadata')
      ) AS req(name)
     WHERE to_regclass('public.' || req.name) IS NULL;
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, missing tables: %', v_missing;
    END IF;

    -- U33 audit columns
    SELECT string_agg(req.name, ', ') INTO v_missing
      FROM (VALUES ('session_id'), ('device_type'), ('browser'), ('operating_system'), ('country'), ('city')) AS req(name)
     WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns
                        WHERE table_schema = 'public' AND table_name = 'audit_logs' AND column_name = req.name);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, audit_logs is missing columns: %', v_missing;
    END IF;

    -- U22/U23 status and lookup foreign keys
    SELECT string_agg(req.name, ', ') INTO v_missing
      FROM (VALUES ('fk_users_gender'), ('fk_addresses_address_label')) AS req(name)
     WHERE NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conname = req.name);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, missing constraints: %', v_missing;
    END IF;

    -- U40: nothing left undocumented, nothing documented that does not exist
    SELECT string_agg(table_name, ', ') INTO v_missing FROM v_undocumented_tables;
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, tables missing from database_metadata: %', v_missing;
    END IF;
    SELECT string_agg(table_name, ', ') INTO v_missing FROM v_stale_metadata;
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, database_metadata lists tables that do not exist: %', v_missing;
    END IF;

    -- U39: every foreign key has a supporting index, except the ownership columns left unindexed on purpose (U34)
    SELECT string_agg(table_name || '.' || fk_columns, ', ') INTO v_missing
      FROM v_missing_fk_indexes WHERE fk_columns !~ '^(created_by|updated_by|deleted_by)$' AND table_name IN (
            SELECT tablename FROM pg_tables WHERE schemaname = 'public'
               AND tablename IN (SELECT table_name FROM database_metadata WHERE module = 'GOVERNANCE'));
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, unindexed foreign keys on new governance tables: %', v_missing;
    END IF;

    -- row level security everywhere
    SELECT string_agg(tablename, ', ') INTO v_missing FROM pg_tables WHERE schemaname = 'public' AND NOT rowsecurity;
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade V3 verification failed, row level security is off for: %', v_missing;
    END IF;

    SELECT COUNT(*) INTO v_tables FROM pg_tables WHERE schemaname = 'public';
    SELECT COUNT(*) INTO v_fks    FROM pg_constraint c WHERE c.connamespace = 'public'::regnamespace AND c.contype = 'f';
    SELECT COUNT(*) INTO v_cons   FROM pg_constraint c WHERE c.connamespace = 'public'::regnamespace AND c.contype IN ('p','f','u','c');
    SELECT COUNT(*) INTO v_cols   FROM information_schema.columns
                                   WHERE table_schema = 'public' AND table_name IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public');
    RAISE NOTICE 'RT Crackers upgrade V3 OK: % tables, % columns, % foreign keys, % constraints (PK/FK/UNIQUE/CHECK)',
                 v_tables, v_cols, v_fks, v_cons;
END;
$$;


COMMIT;
