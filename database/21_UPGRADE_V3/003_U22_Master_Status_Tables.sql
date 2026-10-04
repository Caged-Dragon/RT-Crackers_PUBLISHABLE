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
