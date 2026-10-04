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
