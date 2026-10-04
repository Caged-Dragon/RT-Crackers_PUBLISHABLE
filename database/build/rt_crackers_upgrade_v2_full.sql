-- =====================================================================
-- RT CRACKERS : ENTERPRISE UPGRADE v2.0  (migration, not a fresh build)
-- Engine   : PostgreSQL 15+ (Supabase)
-- Applies  : on top of the database created by rt_crackers_schema.sql
-- Runs as  : ONE transaction. Any error rolls everything back.
-- Re-run   : refuses to run twice (pre-flight check below).
--
-- HOW TO RUN
--   Supabase SQL editor : paste the whole file and run.
--   psql                : psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f rt_crackers_upgrade_v2.sql
--   Take a backup / Supabase snapshot first.
--
-- WHAT EACH UPGRADE DID TO YOUR EXISTING SCHEMA (read before running)
--   U1  NEW countries/states/districts/cities/postal_codes. pincodes is replaced by postal_codes
--       (a read-only compatibility view "pincodes" is kept). addresses.city and addresses.postal_code
--       are REPLACED by addresses.postal_code_id (city/district/state/country come from the chain).
--   U2  NEW product_seo. products.meta_title/meta_description/meta_keywords are MOVED into it.
--   U3  NEW product_audit_logs + trigger on products.
--   U4  Soft delete on 8 tables. A plain DELETE on them becomes a soft delete (see fn_soft_delete).
--   U5  users security columns + automatic lockout trigger.
--   U6  inventory: stock buckets, reorder settings, generated available_stock / stock_status.
--       inventory.reserved_quantity is RENAMED reserved_stock.
--   U7  NEW order_tracking_events.
--   U8  addresses: label, instructions, verification, contact. address_type is REPLACED by address_label.
--   U9  NEW analytics tables (dashboard_metrics, revenue/customer/product/conversion analytics,
--       cart_abandonment_logs). page_views/product_views/search_logs/user_activity_logs already exist.
--   U10 reviews.status is RENAMED moderation_status; adds moderated_by / moderated_at.
--   U11 coupons: columns RENAMED to the spec names; remaining_uses added and trigger-maintained.
--   U12 cart_items: ALREADY protected, by a variant-aware unique index (kept on purpose, see section).
--   U13 wishlist_items: one product per user across all of that user's wishlists (trigger).
--   U14-U16 already satisfied by the original schema; only the missing user checks are added, then verified.
--   U17 system_configurations: config_key globally UNIQUE, is_active added.
--   U18 feature_flags: flag_id/flag_key RENAMED feature_id/feature_name.
--   U19 error_logs: columns RENAMED to the spec names.
--   U20 audit_logs: columns RENAMED, action_type words, ip_address/user_agent added; LOGIN/LOGOUT tracked.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 0. PRE-FLIGHT
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.pincodes') IS NULL OR to_regclass('public.addresses') IS NULL THEN
        RAISE EXCEPTION 'Base schema not found: run rt_crackers_schema.sql first.';
    END IF;
    IF to_regclass('public.upg_v2_pin_city') IS NOT NULL THEN
        RAISE EXCEPTION 'A previous upgrade run stopped halfway (staging table upg_v2_pin_city exists). Clean up first, see the notes at the top of rt_crackers_upgrade_v2_cleanup.sql.';
    END IF;
    IF to_regclass('public.postal_codes') IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade v2 appears to be applied already (postal_codes exists).';
    END IF;
END;
$$;

-- Backfills below must not fire audit / updated_at triggers.
ALTER TABLE addresses  DISABLE TRIGGER USER;
ALTER TABLE users      DISABLE TRIGGER USER;
ALTER TABLE inventory  DISABLE TRIGGER USER;
ALTER TABLE reviews    DISABLE TRIGGER USER;
ALTER TABLE coupons    DISABLE TRIGGER USER;

-- =====================================================================
-- UPGRADE 1 - GEOGRAPHICAL NORMALIZATION
-- Countries -> States -> Districts -> Cities -> Postal_codes
-- =====================================================================

-- ---------------------------------------------------------------------
-- countries | Purpose: ISO country master.
-- Keys : PK(country_id) | CK/AK: country_code, country_name
-- Rel  : 1:N states
-- BCNF : attributes depend only on the country.
-- ---------------------------------------------------------------------
CREATE TABLE countries (
    country_id    SMALLINT     GENERATED ALWAYS AS IDENTITY,
    country_code  CHAR(2)      NOT NULL,
    country_name  VARCHAR(80)  NOT NULL,
    phone_code    VARCHAR(6),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_countries PRIMARY KEY (country_id),
    CONSTRAINT uq_countries_country_code UNIQUE (country_code),
    CONSTRAINT uq_countries_country_name UNIQUE (country_name),
    CONSTRAINT ck_countries_code_upper   CHECK (country_code = UPPER(country_code))
);

-- ---------------------------------------------------------------------
-- states | Purpose: state / union-territory master.
-- Keys : PK(state_id) | CK/AK: (country_id, state_name)
-- Rel  : N:1 countries; 1:N districts
-- BCNF : attributes depend only on the state.
-- ---------------------------------------------------------------------
CREATE TABLE states (
    state_id    SMALLINT     GENERATED ALWAYS AS IDENTITY,
    country_id  SMALLINT     NOT NULL,
    state_name  VARCHAR(80)  NOT NULL,
    state_code  VARCHAR(5),
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_states PRIMARY KEY (state_id),
    CONSTRAINT uq_states_country_name UNIQUE (country_id, state_name),
    CONSTRAINT fk_states_country FOREIGN KEY (country_id) REFERENCES countries (country_id) ON DELETE RESTRICT,
    CONSTRAINT ck_states_name_not_empty CHECK (BTRIM(state_name) <> '')
);

-- ---------------------------------------------------------------------
-- districts | Purpose: district master.
-- Keys : PK(district_id) | CK/AK: (state_id, district_name)
-- Rel  : N:1 states; 1:N cities
-- BCNF : attributes depend only on the district.
-- ---------------------------------------------------------------------
CREATE TABLE districts (
    district_id    INTEGER      GENERATED ALWAYS AS IDENTITY,
    state_id       SMALLINT     NOT NULL,
    district_name  VARCHAR(80)  NOT NULL,
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_districts PRIMARY KEY (district_id),
    CONSTRAINT uq_districts_state_name UNIQUE (state_id, district_name),
    CONSTRAINT fk_districts_state FOREIGN KEY (state_id) REFERENCES states (state_id) ON DELETE RESTRICT,
    CONSTRAINT ck_districts_name_not_empty CHECK (BTRIM(district_name) <> '')
);

-- ---------------------------------------------------------------------
-- cities | Purpose: city / town master.
-- Keys : PK(city_id) | CK/AK: (district_id, city_name)
-- Rel  : N:1 districts; 1:N postal_codes
-- BCNF : attributes depend only on the city.
-- ---------------------------------------------------------------------
CREATE TABLE cities (
    city_id      INTEGER      GENERATED ALWAYS AS IDENTITY,
    district_id  INTEGER      NOT NULL,
    city_name    VARCHAR(80)  NOT NULL,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cities PRIMARY KEY (city_id),
    CONSTRAINT uq_cities_district_name UNIQUE (district_id, city_name),
    CONSTRAINT fk_cities_district FOREIGN KEY (district_id) REFERENCES districts (district_id) ON DELETE RESTRICT,
    CONSTRAINT ck_cities_name_not_empty CHECK (BTRIM(city_name) <> '')
);

-- ---------------------------------------------------------------------
-- postal_codes | Purpose: serviceable-area master (replaces pincodes). One postal code -> one city,
--                which fixes district, state and country.
-- Keys : PK(postal_code_id) | CK/AK: postal_code
-- Rel  : N:1 cities, N:1 delivery_zones; 1:N addresses
-- BCNF : postal_code -> city, zone, flags; district/state/country follow from the city chain.
-- ---------------------------------------------------------------------
CREATE TABLE postal_codes (
    postal_code_id  INTEGER      GENERATED ALWAYS AS IDENTITY,
    postal_code     CHAR(6)      NOT NULL,
    city_id         INTEGER      NOT NULL,
    zone_id         SMALLINT     NOT NULL,
    is_serviceable  BOOLEAN      NOT NULL DEFAULT FALSE,   -- fireworks are restricted in some areas
    cod_available   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_postal_codes PRIMARY KEY (postal_code_id),
    CONSTRAINT uq_postal_codes_postal_code UNIQUE (postal_code),
    CONSTRAINT fk_postal_codes_city FOREIGN KEY (city_id) REFERENCES cities (city_id)              ON DELETE RESTRICT,
    CONSTRAINT fk_postal_codes_zone FOREIGN KEY (zone_id) REFERENCES delivery_zones (zone_id)      ON DELETE RESTRICT,
    CONSTRAINT ck_postal_codes_format CHECK (postal_code ~ '^[1-9][0-9]{5}$')
);

-- ---- migrate existing pincodes / address cities into the master tables
INSERT INTO countries (country_code, country_name) VALUES ('IN', 'India');
INSERT INTO countries (country_code, country_name)
SELECT DISTINCT p.country_code, p.country_code
FROM pincodes p
ON CONFLICT (country_code) DO NOTHING;

INSERT INTO states (country_id, state_name)
SELECT DISTINCT c.country_id, INITCAP(BTRIM(p.state))
FROM pincodes p JOIN countries c ON c.country_code = p.country_code;

INSERT INTO districts (state_id, district_name)
SELECT DISTINCT s.state_id, INITCAP(BTRIM(p.district))
FROM pincodes p
JOIN countries c ON c.country_code = p.country_code
JOIN states s    ON s.country_id = c.country_id AND s.state_name = INITCAP(BTRIM(p.state));

-- city of a postal code = most common city typed on its addresses, else the district name
CREATE TABLE upg_v2_pin_city AS
SELECT p.pincode,
       d.district_id,
       COALESCE(
         (SELECT INITCAP(BTRIM(a.city))
            FROM addresses a
           WHERE a.postal_code = p.pincode AND BTRIM(a.city) <> ''
           GROUP BY INITCAP(BTRIM(a.city))
           ORDER BY COUNT(*) DESC, INITCAP(BTRIM(a.city))
           LIMIT 1),
         INITCAP(BTRIM(p.district))) AS city_name
FROM pincodes p
JOIN countries c ON c.country_code = p.country_code
JOIN states s    ON s.country_id = c.country_id AND s.state_name = INITCAP(BTRIM(p.state))
JOIN districts d ON d.state_id = s.state_id AND d.district_name = INITCAP(BTRIM(p.district));

INSERT INTO cities (district_id, city_name)
SELECT DISTINCT district_id, city_name FROM upg_v2_pin_city;

INSERT INTO postal_codes (postal_code, city_id, zone_id, is_serviceable, cod_available, created_at, updated_at)
SELECT p.pincode, ci.city_id, p.zone_id, p.is_serviceable, p.cod_available, p.created_at, p.updated_at
FROM pincodes p
JOIN upg_v2_pin_city t ON t.pincode = p.pincode
JOIN cities ci      ON ci.district_id = t.district_id AND ci.city_name = t.city_name;

DO $$
DECLARE v_n BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_n
    FROM addresses a
    JOIN upg_v2_pin_city t ON t.pincode = a.postal_code
    WHERE INITCAP(BTRIM(a.city)) <> t.city_name;
    IF v_n > 0 THEN
        RAISE NOTICE 'U1: % address(es) had a city different from the one assigned to their postal code; they now use the postal code''s city.', v_n;
    END IF;
END;
$$;

DROP TABLE upg_v2_pin_city;   -- staging table, no longer needed

-- ---- addresses -> postal_codes (single FK; city/district/state/country are derived through the chain)
DROP VIEW v_addresses_full;

ALTER TABLE addresses ADD COLUMN postal_code_id INTEGER;
UPDATE addresses a SET postal_code_id = pc.postal_code_id
FROM postal_codes pc WHERE pc.postal_code = a.postal_code;
ALTER TABLE addresses ALTER COLUMN postal_code_id SET NOT NULL;
ALTER TABLE addresses ADD CONSTRAINT fk_addresses_postal_code
    FOREIGN KEY (postal_code_id) REFERENCES postal_codes (postal_code_id) ON DELETE RESTRICT;

ALTER TABLE addresses DROP COLUMN city;
ALTER TABLE addresses DROP COLUMN postal_code;      -- also drops fk_addresses_pincode and idx_addresses_postal_code

DROP TABLE pincodes;                                -- also drops idx_pincodes_zone_id

-- Immutability guard for addresses used by orders, now on postal_code_id
CREATE OR REPLACE FUNCTION fn_protect_used_address()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF ROW(NEW.recipient_name, NEW.recipient_phone, NEW.house_no, NEW.street, NEW.area, NEW.landmark, NEW.postal_code_id)
       IS DISTINCT FROM
       ROW(OLD.recipient_name, OLD.recipient_phone, OLD.house_no, OLD.street, OLD.area, OLD.landmark, OLD.postal_code_id)
       AND EXISTS (SELECT 1 FROM orders WHERE billing_address_id = OLD.address_id OR shipping_address_id = OLD.address_id)
    THEN
        RAISE EXCEPTION 'Address % is referenced by an order and cannot be edited; create a new address and archive this one', OLD.address_id;
    END IF;
    RETURN NEW;
END;
$$;

-- =====================================================================
-- UPGRADE 8 - ADVANCED ADDRESS MANAGEMENT  (done here because the view below needs it)
-- latitude/longitude and landmark already existed.
-- =====================================================================
ALTER TABLE addresses
    ADD COLUMN delivery_instructions  VARCHAR(500),
    ADD COLUMN address_label          VARCHAR(10)  NOT NULL DEFAULT 'HOME',
    ADD COLUMN is_verified            BOOLEAN      NOT NULL DEFAULT FALSE,
    ADD COLUMN verification_date      TIMESTAMP,
    ADD COLUMN contact_person         VARCHAR(120),
    ADD COLUMN contact_phone          CHAR(10);

UPDATE addresses SET address_label = CASE address_type WHEN 'W' THEN 'OFFICE' WHEN 'O' THEN 'OTHER' ELSE 'HOME' END;
ALTER TABLE addresses DROP COLUMN address_type;     -- replaced by address_label (also drops ck_addresses_type)

ALTER TABLE addresses
    ADD CONSTRAINT ck_addresses_label        CHECK (address_label IN ('HOME','OFFICE','WAREHOUSE','OTHER')),
    ADD CONSTRAINT ck_addresses_verified     CHECK (is_verified = (verification_date IS NOT NULL)),
    ADD CONSTRAINT ck_addresses_contact_phone CHECK (contact_phone IS NULL OR contact_phone ~ '^[6-9][0-9]{9}$'),
    ADD CONSTRAINT ck_addresses_contact_person CHECK (contact_person IS NULL OR BTRIM(contact_person) <> ''),
    ADD CONSTRAINT ck_addresses_geo_pair     CHECK ((latitude IS NULL) = (longitude IS NULL));

CREATE INDEX idx_addresses_postal_code_id ON addresses (postal_code_id);

-- Same columns the old view exposed (address_type is computed from the new label), plus the new ones.
CREATE VIEW v_addresses_full WITH (security_invoker = true) AS
SELECT a.address_id, a.user_id, a.recipient_name, a.recipient_phone, a.house_no, a.street, a.area,
       a.landmark, ci.city_name AS city, d.district_name AS district, s.state_name AS state,
       co.country_code AS country, pc.postal_code,
       a.latitude, a.longitude,
       CASE a.address_label WHEN 'OFFICE' THEN 'W' WHEN 'HOME' THEN 'H' ELSE 'O' END::CHAR(1) AS address_type,
       a.address_label, a.delivery_instructions, a.is_verified, a.verification_date,
       a.contact_person, a.contact_phone,
       a.is_default, a.is_archived, a.created_at, a.updated_at,
       a.postal_code_id, ci.city_id, d.district_id, s.state_id, co.country_id
FROM addresses a
JOIN postal_codes pc ON pc.postal_code_id = a.postal_code_id
JOIN cities ci       ON ci.city_id        = pc.city_id
JOIN districts d     ON d.district_id     = ci.district_id
JOIN states s        ON s.state_id        = d.state_id
JOIN countries co    ON co.country_id     = s.country_id;

-- Read-only compatibility view for code that still reads the old pincodes table.
CREATE VIEW pincodes WITH (security_invoker = true) AS
SELECT pc.postal_code AS pincode, d.district_name AS district, s.state_name AS state,
       co.country_code, pc.zone_id, pc.is_serviceable, pc.cod_available, pc.created_at, pc.updated_at
FROM postal_codes pc
JOIN cities ci    ON ci.city_id    = pc.city_id
JOIN districts d  ON d.district_id = ci.district_id
JOIN states s     ON s.state_id    = d.state_id
JOIN countries co ON co.country_id = s.country_id;

CREATE INDEX idx_states_country_id        ON states (country_id);
CREATE INDEX idx_districts_state_id       ON districts (state_id);
CREATE INDEX idx_cities_district_id       ON cities (district_id);
CREATE INDEX idx_postal_codes_city_id     ON postal_codes (city_id);
CREATE INDEX idx_postal_codes_zone_id     ON postal_codes (zone_id);

-- =====================================================================
-- UPGRADE 2 - PRODUCT SEO ARCHITECTURE
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_seo | Purpose: search-engine and social-share metadata, one row per product.
-- Keys : PK(seo_id) | CK/AK: product_id
-- Rel  : 1:1 products
-- BCNF : every attribute depends on the product's SEO row; the three meta_* columns formerly on
--        products moved here so SEO data lives in one place.
-- ---------------------------------------------------------------------
CREATE TABLE product_seo (
    seo_id               BIGINT        GENERATED ALWAYS AS IDENTITY,
    product_id           BIGINT        NOT NULL,
    meta_title           VARCHAR(160),
    meta_description     VARCHAR(320),
    meta_keywords        VARCHAR(255),
    canonical_url        VARCHAR(500),
    schema_markup        JSONB,
    robots_index         BOOLEAN       NOT NULL DEFAULT TRUE,     -- TRUE = index, FALSE = noindex
    og_title             VARCHAR(160),
    og_description       VARCHAR(320),
    og_image             VARCHAR(500),
    twitter_title        VARCHAR(160),
    twitter_description  VARCHAR(320),
    twitter_image        VARCHAR(500),
    created_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_seo PRIMARY KEY (seo_id),
    CONSTRAINT uq_product_seo_product_id UNIQUE (product_id),
    CONSTRAINT fk_product_seo_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT ck_product_seo_canonical CHECK (canonical_url IS NULL OR canonical_url ~* '^https?://'),
    CONSTRAINT ck_product_seo_schema    CHECK (schema_markup IS NULL OR jsonb_typeof(schema_markup) IN ('object','array')),
    CONSTRAINT ck_product_seo_og_image  CHECK (og_image IS NULL OR og_image ~* '^(https?://|/)'),
    CONSTRAINT ck_product_seo_tw_image  CHECK (twitter_image IS NULL OR twitter_image ~* '^(https?://|/)')
);

INSERT INTO product_seo (product_id, meta_title, meta_description, meta_keywords)
SELECT product_id, meta_title, meta_description, meta_keywords
FROM products
WHERE meta_title IS NOT NULL OR meta_description IS NOT NULL OR meta_keywords IS NOT NULL;

ALTER TABLE products
    DROP COLUMN meta_title,
    DROP COLUMN meta_description,
    DROP COLUMN meta_keywords;

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


-- =====================================================================
-- UPGRADE 5 - USER SECURITY ENHANCEMENTS
-- failed_login_count, account_locked, last_password_change already existed.
-- mfa_secret and security_answer_hash must be stored encrypted/hashed by the application.
-- =====================================================================
ALTER TABLE users
    ADD COLUMN last_failed_login      TIMESTAMP,
    ADD COLUMN account_locked_until   TIMESTAMP,
    ADD COLUMN password_expiry_date   DATE,
    ADD COLUMN last_login_ip          INET,
    ADD COLUMN last_device            VARCHAR(255),
    ADD COLUMN security_question      VARCHAR(255),
    ADD COLUMN security_answer_hash   VARCHAR(255),
    ADD COLUMN mfa_enabled            BOOLEAN       NOT NULL DEFAULT FALSE,
    ADD COLUMN mfa_secret             VARCHAR(255);

ALTER TABLE users
    ADD CONSTRAINT ck_users_security_qa    CHECK ((security_question IS NULL) = (security_answer_hash IS NULL)),
    ADD CONSTRAINT ck_users_mfa_secret     CHECK (NOT mfa_enabled OR mfa_secret IS NOT NULL),
    ADD CONSTRAINT ck_users_lock_until     CHECK (account_locked_until IS NULL OR account_locked),
    ADD CONSTRAINT ck_users_password_expiry CHECK (password_expiry_date IS NULL OR last_password_change IS NULL
                                                   OR password_expiry_date >= last_password_change::DATE);

-- Brute-force protection: lock after N failures (system_configurations 'security.max_failed_logins',
-- default 5) for M minutes ('security.lockout_minutes', default 30). Unlocking resets the counter.
CREATE OR REPLACE FUNCTION fn_users_security()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_max     INTEGER;
    v_minutes INTEGER;
BEGIN
    IF OLD.account_locked AND NOT NEW.account_locked THEN
        NEW.failed_login_count  := 0;
        NEW.account_locked_until := NULL;
        RETURN NEW;
    END IF;
    IF NEW.failed_login_count > OLD.failed_login_count THEN
        NEW.last_failed_login := CURRENT_TIMESTAMP;
        SELECT COALESCE(MAX(config_value::INTEGER) FILTER (WHERE config_key = 'security.max_failed_logins'), 5),
               COALESCE(MAX(config_value::INTEGER) FILTER (WHERE config_key = 'security.lockout_minutes'), 30)
          INTO v_max, v_minutes
          FROM system_configurations
         WHERE is_active AND config_key IN ('security.max_failed_logins', 'security.lockout_minutes');
        IF NEW.failed_login_count >= v_max AND NOT NEW.account_locked THEN
            NEW.account_locked := TRUE;
            NEW.account_locked_until := CURRENT_TIMESTAMP + make_interval(mins => v_minutes);
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_users_security BEFORE UPDATE OF failed_login_count, account_locked ON users
    FOR EACH ROW EXECUTE FUNCTION fn_users_security();

-- =====================================================================
-- UPGRADE 15 - USER VALIDATION RULES (U14 and U16 are verified in section 21)
-- phone format/uniqueness, email format already existed.
-- last_name stays optional (single-name users); when present it cannot be blank.
-- =====================================================================
UPDATE users SET last_name = NULL WHERE last_name IS NOT NULL AND BTRIM(last_name) = '';
ALTER TABLE users
    ADD CONSTRAINT ck_users_phone_length     CHECK (LENGTH(phone) = 10),
    ADD CONSTRAINT ck_users_email_not_empty  CHECK (BTRIM(email) <> ''),
    ADD CONSTRAINT ck_users_first_name_not_empty CHECK (BTRIM(first_name) <> ''),
    ADD CONSTRAINT ck_users_last_name_not_empty  CHECK (last_name IS NULL OR BTRIM(last_name) <> '');

-- =====================================================================
-- UPGRADE 6 - ADVANCED INVENTORY MANAGEMENT
--   quantity_on_hand  = physical units (kept; existing triggers rely on it)
--   reserved_stock    = renamed from reserved_quantity
--   available_stock   = GENERATED: quantity_on_hand - reserved_stock (cannot drift)
--   sold/returned/damaged_stock = running totals maintained by the movement trigger
--   stock_status      = GENERATED: O out of stock, L low (<= reorder_level), X over maximum, I in stock
-- =====================================================================
ALTER TABLE inventory RENAME COLUMN reserved_quantity TO reserved_stock;

ALTER TABLE inventory
    ADD COLUMN returned_stock     INTEGER    NOT NULL DEFAULT 0,
    ADD COLUMN damaged_stock      INTEGER    NOT NULL DEFAULT 0,
    ADD COLUMN sold_stock         INTEGER    NOT NULL DEFAULT 0,
    ADD COLUMN reorder_level      INTEGER    NOT NULL DEFAULT 10,
    ADD COLUMN reorder_quantity   INTEGER    NOT NULL DEFAULT 50,
    ADD COLUMN minimum_stock      INTEGER    NOT NULL DEFAULT 0,
    ADD COLUMN maximum_stock      INTEGER    NOT NULL DEFAULT 1000,
    ADD COLUMN last_stock_update  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- start from the per-product levels already configured on products
UPDATE inventory i
   SET minimum_stock = p.min_stock_level,
       maximum_stock = p.max_stock_level,
       reorder_level = GREATEST(p.min_stock_level, 0),
       last_stock_update = i.updated_at
  FROM products p
 WHERE p.product_id = i.product_id;

-- rebuild the running totals from the ledger
UPDATE inventory i
   SET sold_stock     = GREATEST(m.sold - m.cancelled, 0),
       returned_stock = m.returned,
       damaged_stock  = m.damaged
  FROM (SELECT inventory_id,
               COALESCE(SUM(-quantity_change) FILTER (WHERE movement_type = 'S'), 0) AS sold,
               COALESCE(SUM( quantity_change) FILTER (WHERE movement_type = 'C'), 0) AS cancelled,
               COALESCE(SUM( quantity_change) FILTER (WHERE movement_type = 'R'), 0) AS returned,
               COALESCE(SUM(-quantity_change) FILTER (WHERE movement_type = 'D'), 0) AS damaged
          FROM inventory_movements GROUP BY inventory_id) m
 WHERE m.inventory_id = i.inventory_id;

ALTER TABLE inventory
    ADD COLUMN available_stock INTEGER GENERATED ALWAYS AS (quantity_on_hand - reserved_stock) STORED;
ALTER TABLE inventory
    ADD COLUMN stock_status CHAR(1) GENERATED ALWAYS AS (
        CASE WHEN quantity_on_hand - reserved_stock <= 0              THEN 'O'
             WHEN quantity_on_hand - reserved_stock <= reorder_level  THEN 'L'
             WHEN quantity_on_hand > maximum_stock                    THEN 'X'
             ELSE 'I' END) STORED;

ALTER TABLE inventory
    ADD CONSTRAINT ck_inventory_stock_nonneg CHECK (available_stock >= 0 AND reserved_stock >= 0 AND returned_stock >= 0
                                                    AND damaged_stock >= 0 AND sold_stock >= 0),
    ADD CONSTRAINT ck_inventory_reorder      CHECK (reorder_level >= 0 AND reorder_quantity >= 0),
    ADD CONSTRAINT ck_inventory_stock_limits CHECK (minimum_stock >= 0 AND maximum_stock >= minimum_stock),
    ADD CONSTRAINT ck_inventory_stock_status CHECK (stock_status IN ('O','L','I','X'));

CREATE INDEX idx_inventory_stock_status ON inventory (stock_status) WHERE stock_status IN ('O','L');

-- movement ledger now also maintains the running totals
CREATE OR REPLACE FUNCTION fn_apply_inventory_movement()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE inventory
       SET quantity_on_hand  = quantity_on_hand + NEW.quantity_change,
           sold_stock        = CASE NEW.movement_type
                                   WHEN 'S' THEN sold_stock - NEW.quantity_change
                                   WHEN 'C' THEN GREATEST(sold_stock - NEW.quantity_change, 0)
                                   ELSE sold_stock END,
           returned_stock    = returned_stock + CASE WHEN NEW.movement_type = 'R' THEN NEW.quantity_change ELSE 0 END,
           damaged_stock     = damaged_stock  + CASE WHEN NEW.movement_type = 'D' THEN -NEW.quantity_change ELSE 0 END,
           last_restocked_at = CASE WHEN NEW.movement_type = 'P' THEN CURRENT_TIMESTAMP ELSE last_restocked_at END
     WHERE inventory_id = NEW.inventory_id;
    RETURN NEW;
END;
$$;

-- last_stock_update follows any change to physical or reserved units
CREATE OR REPLACE FUNCTION fn_inventory_touch()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.quantity_on_hand IS DISTINCT FROM OLD.quantity_on_hand
       OR NEW.reserved_stock IS DISTINCT FROM OLD.reserved_stock THEN
        NEW.last_stock_update := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_inventory_touch BEFORE UPDATE ON inventory
    FOR EACH ROW EXECUTE FUNCTION fn_inventory_touch();

-- =====================================================================
-- UPGRADE 7 - ORDER TRACKING EVENTS
-- =====================================================================
ALTER TABLE shipments ADD CONSTRAINT uq_shipments_shipment_order UNIQUE (shipment_id, order_id);

-- ---------------------------------------------------------------------
-- order_tracking_events | Purpose: every milestone of an order / shipment.
-- Keys : PK(tracking_event_id)
-- Rel  : N:1 orders; N:1 shipments (composite FK guarantees the shipment belongs to the same order)
-- BCNF : attributes describe one event.
-- ---------------------------------------------------------------------
CREATE TABLE order_tracking_events (
    tracking_event_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    order_id           BIGINT        NOT NULL,
    shipment_id        BIGINT,
    status             CHAR(1)       NOT NULL,   -- P placed, C confirmed, K packed, S dispatched, T in transit, O out for delivery, D delivered, F attempt failed, X cancelled, R returned
    description        VARCHAR(500),
    location           VARCHAR(200),
    event_time         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_order_tracking_events PRIMARY KEY (tracking_event_id),
    CONSTRAINT fk_order_tracking_events_order    FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_tracking_events_shipment FOREIGN KEY (shipment_id, order_id) REFERENCES shipments (shipment_id, order_id) ON DELETE CASCADE,
    CONSTRAINT ck_order_tracking_events_status   CHECK (status IN ('P','C','K','S','T','O','D','F','X','R'))
);
CREATE INDEX idx_order_tracking_events_order    ON order_tracking_events (order_id, event_time);
CREATE INDEX idx_order_tracking_events_shipment ON order_tracking_events (shipment_id, event_time) WHERE shipment_id IS NOT NULL;

-- =====================================================================
-- UPGRADE 9 - ANALYTICS EXPANSION
-- page_views, product_views, search_logs, user_activity_logs already exist.
-- =====================================================================

-- ---------------------------------------------------------------------
-- dashboard_metrics | Purpose: pre-computed KPI values for the admin dashboard.
-- Keys : PK(metric_id) | CK/AK: (period_type, period_date, metric_key)
-- BCNF : metric_value depends on the whole (period, date, key).
-- ---------------------------------------------------------------------
CREATE TABLE dashboard_metrics (
    metric_id     BIGINT         GENERATED ALWAYS AS IDENTITY,
    metric_key    VARCHAR(60)    NOT NULL,
    period_type   CHAR(1)        NOT NULL,           -- D daily, W weekly, M monthly, Y yearly
    period_date   DATE           NOT NULL,
    metric_value  NUMERIC(18,4)  NOT NULL,
    unit          VARCHAR(20),
    calculated_at TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_dashboard_metrics PRIMARY KEY (metric_id),
    CONSTRAINT uq_dashboard_metrics_key_period UNIQUE (period_type, period_date, metric_key),
    CONSTRAINT ck_dashboard_metrics_period CHECK (period_type IN ('D','W','M','Y')),
    CONSTRAINT ck_dashboard_metrics_key    CHECK (BTRIM(metric_key) <> '')
);

-- ---------------------------------------------------------------------
-- revenue_analytics | Purpose: revenue per period, overall (category_id NULL) or per category.
-- Keys : PK(revenue_id) | CK/AK: (period_type, period_date, category_id|0) via unique index
-- Rel  : N:1 categories (optional)
-- BCNF : net_revenue and average_order_value are GENERATED from the stored amounts.
-- ---------------------------------------------------------------------
CREATE TABLE revenue_analytics (
    revenue_id           BIGINT         GENERATED ALWAYS AS IDENTITY,
    period_type          CHAR(1)        NOT NULL,     -- D, W, M
    period_date          DATE           NOT NULL,
    category_id          INTEGER,
    orders_count         INTEGER        NOT NULL DEFAULT 0,
    units_sold           INTEGER        NOT NULL DEFAULT 0,
    gross_revenue        NUMERIC(14,2)  NOT NULL DEFAULT 0,
    discount_total       NUMERIC(14,2)  NOT NULL DEFAULT 0,
    tax_total            NUMERIC(14,2)  NOT NULL DEFAULT 0,
    shipping_total       NUMERIC(14,2)  NOT NULL DEFAULT 0,
    refund_total         NUMERIC(14,2)  NOT NULL DEFAULT 0,
    cod_collected        NUMERIC(14,2)  NOT NULL DEFAULT 0,
    net_revenue          NUMERIC(14,2)  GENERATED ALWAYS AS (gross_revenue - discount_total + tax_total + shipping_total - refund_total) STORED,
    average_order_value  NUMERIC(14,2)  GENERATED ALWAYS AS (ROUND((gross_revenue - discount_total + tax_total + shipping_total - refund_total) / NULLIF(orders_count, 0), 2)) STORED,
    calculated_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_revenue_analytics PRIMARY KEY (revenue_id),
    CONSTRAINT fk_revenue_analytics_category FOREIGN KEY (category_id) REFERENCES categories (category_id) ON DELETE CASCADE,
    CONSTRAINT ck_revenue_analytics_period  CHECK (period_type IN ('D','W','M')),
    CONSTRAINT ck_revenue_analytics_counts  CHECK (orders_count >= 0 AND units_sold >= 0),
    CONSTRAINT ck_revenue_analytics_amounts CHECK (gross_revenue >= 0 AND discount_total >= 0 AND tax_total >= 0
                                                   AND shipping_total >= 0 AND refund_total >= 0 AND cod_collected >= 0)
);
CREATE UNIQUE INDEX uq_revenue_analytics_scope ON revenue_analytics (period_type, period_date, COALESCE(category_id, 0));
CREATE INDEX idx_revenue_analytics_category ON revenue_analytics (category_id) WHERE category_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- customer_analytics | Purpose: one summary row per customer (segment, lifetime value, recency).
-- Keys : PK(user_id) which is also FK
-- Rel  : 1:1 users
-- BCNF : sole determinant is user_id; average_order_value is GENERATED.
-- ---------------------------------------------------------------------
CREATE TABLE customer_analytics (
    user_id              BIGINT         NOT NULL,
    total_orders         INTEGER        NOT NULL DEFAULT 0,
    delivered_orders     INTEGER        NOT NULL DEFAULT 0,
    cancelled_orders     INTEGER        NOT NULL DEFAULT 0,
    returned_orders      INTEGER        NOT NULL DEFAULT 0,
    lifetime_value       NUMERIC(14,2)  NOT NULL DEFAULT 0,
    average_order_value  NUMERIC(14,2)  GENERATED ALWAYS AS (CASE WHEN delivered_orders > 0 THEN ROUND(lifetime_value / delivered_orders, 2) ELSE 0 END) STORED,
    first_order_at       TIMESTAMP,
    last_order_at        TIMESTAMP,
    last_active_at       TIMESTAMP,
    customer_segment     CHAR(1)        NOT NULL DEFAULT 'N',   -- N new, R regular, L loyal, V vip, D dormant
    calculated_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_customer_analytics PRIMARY KEY (user_id),
    CONSTRAINT fk_customer_analytics_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_customer_analytics_segment CHECK (customer_segment IN ('N','R','L','V','D')),
    CONSTRAINT ck_customer_analytics_counts  CHECK (total_orders >= 0 AND delivered_orders >= 0 AND cancelled_orders >= 0
                                                    AND returned_orders >= 0
                                                    AND delivered_orders <= total_orders AND cancelled_orders <= total_orders
                                                    AND returned_orders <= total_orders),
    CONSTRAINT ck_customer_analytics_value   CHECK (lifetime_value >= 0),
    CONSTRAINT ck_customer_analytics_dates   CHECK (first_order_at IS NULL OR last_order_at IS NULL OR last_order_at >= first_order_at)
);
CREATE INDEX idx_customer_analytics_segment ON customer_analytics (customer_segment);

-- ---------------------------------------------------------------------
-- product_analytics | Purpose: daily funnel numbers per product.
-- Keys : COMPOSITE PK(product_id, stat_date)
-- Rel  : N:1 products
-- BCNF : conversion_rate is GENERATED from orders_count and views_count.
-- ---------------------------------------------------------------------
CREATE TABLE product_analytics (
    product_id       BIGINT         NOT NULL,
    stat_date        DATE           NOT NULL,
    views_count      INTEGER        NOT NULL DEFAULT 0,
    unique_viewers   INTEGER        NOT NULL DEFAULT 0,
    cart_adds        INTEGER        NOT NULL DEFAULT 0,
    wishlist_adds    INTEGER        NOT NULL DEFAULT 0,
    orders_count     INTEGER        NOT NULL DEFAULT 0,
    units_sold       INTEGER        NOT NULL DEFAULT 0,
    returns_count    INTEGER        NOT NULL DEFAULT 0,
    revenue          NUMERIC(14,2)  NOT NULL DEFAULT 0,
    conversion_rate  NUMERIC(7,2)   GENERATED ALWAYS AS (ROUND(orders_count * 100.0 / NULLIF(views_count, 0), 2)) STORED,
    created_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_analytics PRIMARY KEY (product_id, stat_date),
    CONSTRAINT fk_product_analytics_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT ck_product_analytics_counts  CHECK (views_count >= 0 AND unique_viewers >= 0 AND cart_adds >= 0 AND wishlist_adds >= 0
                                                   AND orders_count >= 0 AND units_sold >= 0 AND returns_count >= 0 AND revenue >= 0),
    CONSTRAINT ck_product_analytics_unique  CHECK (unique_viewers <= views_count)
);
CREATE INDEX idx_product_analytics_date ON product_analytics (stat_date);

-- ---------------------------------------------------------------------
-- conversion_analytics | Purpose: daily sales funnel for the whole store.
-- Keys : PK(conversion_id) | CK/AK: stat_date
-- BCNF : the three rates are GENERATED from the stored counts.
-- ---------------------------------------------------------------------
CREATE TABLE conversion_analytics (
    conversion_id            BIGINT        GENERATED ALWAYS AS IDENTITY,
    stat_date                DATE          NOT NULL,
    sessions_count           INTEGER       NOT NULL DEFAULT 0,
    product_views            INTEGER       NOT NULL DEFAULT 0,
    add_to_cart_count        INTEGER       NOT NULL DEFAULT 0,
    checkout_started_count   INTEGER       NOT NULL DEFAULT 0,
    orders_placed_count      INTEGER       NOT NULL DEFAULT 0,
    orders_delivered_count   INTEGER       NOT NULL DEFAULT 0,
    visit_to_cart_rate       NUMERIC(7,2)  GENERATED ALWAYS AS (ROUND(add_to_cart_count * 100.0 / NULLIF(sessions_count, 0), 2)) STORED,
    cart_to_order_rate       NUMERIC(7,2)  GENERATED ALWAYS AS (ROUND(orders_placed_count * 100.0 / NULLIF(add_to_cart_count, 0), 2)) STORED,
    overall_conversion_rate  NUMERIC(7,2)  GENERATED ALWAYS AS (ROUND(orders_placed_count * 100.0 / NULLIF(sessions_count, 0), 2)) STORED,
    created_at               TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_conversion_analytics PRIMARY KEY (conversion_id),
    CONSTRAINT uq_conversion_analytics_date UNIQUE (stat_date),
    CONSTRAINT ck_conversion_analytics_counts CHECK (sessions_count >= 0 AND product_views >= 0 AND add_to_cart_count >= 0
                                                     AND checkout_started_count >= 0 AND orders_placed_count >= 0
                                                     AND orders_delivered_count >= 0 AND orders_delivered_count <= orders_placed_count)
);

-- ---------------------------------------------------------------------
-- cart_abandonment_logs | Purpose: carts left without ordering, reminders sent, and recovery.
-- Keys : PK(abandonment_id) | CK/AK: cart_id
-- Rel  : 1:1 carts; N:1 orders (the order that recovered it)
-- BCNF : the customer is reached through carts.user_id, so user_id is not repeated here.
-- ---------------------------------------------------------------------
CREATE TABLE cart_abandonment_logs (
    abandonment_id      BIGINT         GENERATED ALWAYS AS IDENTITY,
    cart_id             BIGINT         NOT NULL,
    abandoned_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    items_count         INTEGER        NOT NULL DEFAULT 0,
    cart_value          NUMERIC(12,2)  NOT NULL DEFAULT 0,        -- snapshot at the time of abandonment
    reminder_count      SMALLINT       NOT NULL DEFAULT 0,
    last_reminder_at    TIMESTAMP,
    is_recovered        BOOLEAN        NOT NULL DEFAULT FALSE,
    recovered_order_id  BIGINT,
    recovered_at        TIMESTAMP,
    created_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cart_abandonment_logs PRIMARY KEY (abandonment_id),
    CONSTRAINT uq_cart_abandonment_logs_cart UNIQUE (cart_id),
    CONSTRAINT fk_cart_abandonment_logs_cart  FOREIGN KEY (cart_id)            REFERENCES carts (cart_id)   ON DELETE CASCADE,
    CONSTRAINT fk_cart_abandonment_logs_order FOREIGN KEY (recovered_order_id) REFERENCES orders (order_id) ON DELETE SET NULL,
    CONSTRAINT ck_cart_abandonment_logs_counts   CHECK (items_count >= 0 AND cart_value >= 0 AND reminder_count >= 0),
    CONSTRAINT ck_cart_abandonment_logs_reminder CHECK ((reminder_count = 0) = (last_reminder_at IS NULL)),
    CONSTRAINT ck_cart_abandonment_logs_recovery CHECK (is_recovered = (recovered_at IS NOT NULL)
                                                        AND (recovered_order_id IS NULL OR is_recovered))
);
CREATE INDEX idx_cart_abandonment_logs_open  ON cart_abandonment_logs (abandoned_at) WHERE NOT is_recovered;
CREATE INDEX idx_cart_abandonment_logs_order ON cart_abandonment_logs (recovered_order_id) WHERE recovered_order_id IS NOT NULL;

-- =====================================================================
-- UPGRADE 10 - REVIEW MODERATION SYSTEM
-- verified_purchase, helpful_count, reported_count and the rating / counter checks already existed.
-- status is renamed moderation_status (single source of truth, P pending, A approved, R rejected, H hidden).
-- =====================================================================
ALTER TABLE reviews RENAME COLUMN status TO moderation_status;
ALTER TABLE reviews RENAME CONSTRAINT ck_reviews_status TO ck_reviews_moderation_status;
ALTER TABLE reviews
    ADD COLUMN moderated_by  INTEGER,
    ADD COLUMN moderated_at  TIMESTAMP;

UPDATE reviews SET moderated_at = updated_at WHERE moderation_status <> 'P';

ALTER TABLE reviews
    ADD CONSTRAINT fk_reviews_moderated_by FOREIGN KEY (moderated_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    ADD CONSTRAINT ck_reviews_moderation_stamp CHECK ((moderation_status = 'P') = (moderated_at IS NULL));
CREATE INDEX idx_reviews_moderated_by ON reviews (moderated_by) WHERE moderated_by IS NOT NULL;

-- the rating cache reads the renamed column
CREATE OR REPLACE FUNCTION fn_sync_product_rating()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_product_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN v_product_id := OLD.product_id; ELSE v_product_id := NEW.product_id; END IF;
    UPDATE products p
       SET rating_count   = s.cnt,
           rating_average = s.avg_rating
      FROM (SELECT COUNT(*)::INTEGER AS cnt,
                   COALESCE(ROUND(AVG(rating), 2), 0) AS avg_rating
              FROM reviews WHERE product_id = v_product_id AND moderation_status = 'A' AND NOT is_deleted) s
     WHERE p.product_id = v_product_id;
    RETURN NULL;
END;
$$;
-- also re-run the cache when a review is soft deleted / restored
DROP TRIGGER trg_reviews_sync_rating ON reviews;
CREATE TRIGGER trg_reviews_sync_rating AFTER INSERT OR DELETE OR UPDATE OF rating, moderation_status, is_deleted ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_sync_product_rating();

-- stamp moderator and time automatically so the pending/moderated check always holds
CREATE OR REPLACE FUNCTION fn_review_moderation_stamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.moderation_status = 'P' THEN
        NEW.moderated_at := NULL;
        NEW.moderated_by := NULL;
    ELSIF TG_OP = 'INSERT' OR NEW.moderation_status IS DISTINCT FROM OLD.moderation_status THEN
        NEW.moderated_at := COALESCE(NEW.moderated_at, CURRENT_TIMESTAMP);
        NEW.moderated_by := COALESCE(NEW.moderated_by, NULLIF(current_setting('app.current_admin_id', TRUE), '')::INTEGER);
    ELSIF NEW.moderated_at IS NULL THEN
        NEW.moderated_at := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_reviews_moderation_stamp BEFORE INSERT OR UPDATE ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_review_moderation_stamp();

-- =====================================================================
-- UPGRADE 11 - ADVANCED COUPON MANAGEMENT
-- Renamed to the spec names: min_order_amount -> minimum_order_amount,
-- max_discount_amount -> maximum_discount_amount, usage_limit_per_user -> per_user_limit,
-- valid_until -> valid_to. remaining_uses is NULL for unlimited coupons.
-- =====================================================================
ALTER TABLE coupons RENAME COLUMN min_order_amount     TO minimum_order_amount;
ALTER TABLE coupons RENAME COLUMN max_discount_amount  TO maximum_discount_amount;
ALTER TABLE coupons RENAME COLUMN usage_limit_per_user TO per_user_limit;
ALTER TABLE coupons RENAME COLUMN valid_until          TO valid_to;

ALTER TABLE coupons ADD COLUMN remaining_uses INTEGER;
UPDATE coupons c
   SET remaining_uses = GREATEST(c.usage_limit - (SELECT COUNT(*) FROM coupon_usage u WHERE u.coupon_id = c.coupon_id AND u.status = 'A'), 0)
 WHERE c.usage_limit IS NOT NULL;

ALTER TABLE coupons
    ADD CONSTRAINT ck_coupons_remaining_uses CHECK ((usage_limit IS NULL) = (remaining_uses IS NULL)
                                                    AND (remaining_uses IS NULL OR (remaining_uses >= 0 AND remaining_uses <= usage_limit)));

CREATE OR REPLACE FUNCTION fn_coupon_set_remaining()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.usage_limit IS NULL THEN
        NEW.remaining_uses := NULL;
    ELSE
        NEW.remaining_uses := NEW.usage_limit - (SELECT COUNT(*) FROM coupon_usage WHERE coupon_id = NEW.coupon_id AND status = 'A');
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_coupons_remaining BEFORE INSERT OR UPDATE OF usage_limit ON coupons
    FOR EACH ROW EXECUTE FUNCTION fn_coupon_set_remaining();

-- using a coupon more often than its limit raises a CHECK violation (remaining_uses >= 0)
CREATE OR REPLACE FUNCTION fn_coupon_usage_sync()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_coupon_id INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN v_coupon_id := OLD.coupon_id; ELSE v_coupon_id := NEW.coupon_id; END IF;
    UPDATE coupons
       SET remaining_uses = usage_limit - (SELECT COUNT(*) FROM coupon_usage WHERE coupon_id = v_coupon_id AND status = 'A')
     WHERE coupon_id = v_coupon_id AND usage_limit IS NOT NULL;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_coupon_usage_sync AFTER INSERT OR DELETE OR UPDATE OF status, coupon_id ON coupon_usage
    FOR EACH ROW EXECUTE FUNCTION fn_coupon_usage_sync();

-- =====================================================================
-- UPGRADE 12 - CART PROTECTION
-- Already enforced: uq_cart_items_line UNIQUE (cart_id, product_id, COALESCE(variant_id, 0)).
-- That stops duplicate lines but still lets a customer hold two pack sizes (variants) of one product.
-- A plain UNIQUE (cart_id, product_id) would forbid that. If you really want it, uncomment:
--
--   DROP INDEX uq_cart_items_line;
--   ALTER TABLE cart_items ADD CONSTRAINT uq_cart_items_cart_product UNIQUE (cart_id, product_id);
-- =====================================================================

-- =====================================================================
-- UPGRADE 13 - WISHLIST PROTECTION
-- wishlist_items has no user_id (adding one would break BCNF), so UNIQUE (user_id, product_id) is
-- enforced by a trigger: a product can appear only once across all of a user's wishlists.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_wishlist_item_unique_per_user()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_user_id BIGINT;
BEGIN
    SELECT user_id INTO v_user_id FROM wishlists WHERE wishlist_id = NEW.wishlist_id;
    PERFORM pg_advisory_xact_lock(hashtextextended('wishlist_items:' || v_user_id::TEXT, 0));
    IF EXISTS (SELECT 1
                 FROM wishlist_items wi
                 JOIN wishlists w ON w.wishlist_id = wi.wishlist_id
                WHERE w.user_id = v_user_id
                  AND wi.product_id = NEW.product_id
                  AND wi.wishlist_id <> NEW.wishlist_id
                  AND NOT (TG_OP = 'UPDATE' AND wi.wishlist_id = OLD.wishlist_id AND wi.product_id = OLD.product_id))
    THEN
        RAISE EXCEPTION 'Product % is already in another wishlist of user %', NEW.product_id, v_user_id
            USING ERRCODE = 'unique_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_wishlist_items_unique_per_user BEFORE INSERT OR UPDATE OF wishlist_id, product_id ON wishlist_items
    FOR EACH ROW EXECUTE FUNCTION fn_wishlist_item_unique_per_user();

-- =====================================================================
-- UPGRADE 17 - SYSTEM CONFIGURATION MODULE
-- =====================================================================
ALTER TABLE system_configurations ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE system_configurations DROP CONSTRAINT uq_system_configurations_group_key;
ALTER TABLE system_configurations ADD CONSTRAINT uq_system_configurations_config_key UNIQUE (config_key);
ALTER TABLE system_configurations ADD CONSTRAINT ck_system_configurations_key CHECK (BTRIM(config_key) <> '');

INSERT INTO system_configurations (config_group, config_key, config_value, description) VALUES
    ('security', 'security.max_failed_logins',     '5',  'Failed logins before an account is locked'),
    ('security', 'security.lockout_minutes',       '30', 'Minutes an account stays locked after too many failures'),
    ('security', 'security.password_expiry_days',  '90', 'Days before a password must be changed')
ON CONFLICT (config_key) DO NOTHING;

-- =====================================================================
-- UPGRADE 18 - FEATURE FLAGS
-- =====================================================================
ALTER TABLE feature_flags RENAME COLUMN flag_id  TO feature_id;
ALTER TABLE feature_flags RENAME COLUMN flag_key TO feature_name;
ALTER TABLE feature_flags RENAME CONSTRAINT uq_feature_flags_key TO uq_feature_flags_feature_name;

INSERT INTO feature_flags (feature_name, description, is_enabled) VALUES
    ('notifications', 'Customer notifications', TRUE),
    ('analytics',     'Analytics collection',   TRUE)
ON CONFLICT (feature_name) DO NOTHING;

-- =====================================================================
-- UPGRADE 19 - ERROR LOGGING
-- =====================================================================
ALTER TABLE error_logs RENAME COLUMN error_log_id TO error_id;
ALTER TABLE error_logs RENAME COLUMN source       TO module_name;
ALTER TABLE error_logs RENAME COLUMN error_level  TO severity;          -- W warning, E error, F fatal
ALTER TABLE error_logs RENAME COLUMN user_id      TO reported_by;
ALTER TABLE error_logs RENAME CONSTRAINT fk_error_logs_user  TO fk_error_logs_reported_by;
ALTER TABLE error_logs RENAME CONSTRAINT ck_error_logs_level TO ck_error_logs_severity;

UPDATE error_logs SET module_name = 'application' WHERE module_name IS NULL;
ALTER TABLE error_logs ALTER COLUMN module_name SET DEFAULT 'application';
ALTER TABLE error_logs ALTER COLUMN module_name SET NOT NULL;
CREATE INDEX idx_error_logs_module ON error_logs (module_name, created_at DESC);

-- =====================================================================
-- UPGRADE 20 - AUDIT LOGGING
-- =====================================================================
ALTER TABLE audit_logs RENAME COLUMN audit_log_id TO audit_id;
ALTER TABLE audit_logs RENAME COLUMN action       TO action_type;
ALTER TABLE audit_logs RENAME COLUMN old_data     TO old_value;
ALTER TABLE audit_logs RENAME COLUMN new_data     TO new_value;
ALTER TABLE audit_logs RENAME COLUMN created_at   TO changed_at;

ALTER TABLE audit_logs DROP CONSTRAINT ck_audit_logs_action;
ALTER TABLE audit_logs ALTER COLUMN action_type TYPE VARCHAR(10)
    USING CASE action_type WHEN 'I' THEN 'INSERT' WHEN 'U' THEN 'UPDATE' WHEN 'D' THEN 'DELETE' END;
ALTER TABLE audit_logs
    ADD COLUMN ip_address  INET,
    ADD COLUMN user_agent  VARCHAR(500),
    ADD CONSTRAINT ck_audit_logs_action_type CHECK (action_type IN ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT'));
CREATE INDEX idx_audit_logs_time   ON audit_logs (changed_at DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs (action_type, changed_at DESC) WHERE action_type IN ('LOGIN','LOGOUT');

-- Row audit: arg 0 = primary-key column; further args = JSON keys to strip (secrets).
-- Session settings read when present: app.current_user_id, app.client_ip, app.user_agent.
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk     TEXT   := TG_ARGV[0];
    v_redact TEXT[] := CASE WHEN TG_NARGS > 1 THEN TG_ARGV[1:TG_NARGS - 1] ELSE ARRAY[]::TEXT[] END;
    v_old    JSONB;
    v_new    JSONB;
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN v_old := to_jsonb(OLD) - v_redact; END IF;
    IF TG_OP IN ('INSERT','UPDATE') THEN v_new := to_jsonb(NEW) - v_redact; END IF;
    INSERT INTO audit_logs (table_name, record_id, action_type, old_value, new_value, changed_by, ip_address, user_agent)
    VALUES (TG_TABLE_NAME, COALESCE(v_new ->> v_pk, v_old ->> v_pk), TG_OP, v_old, v_new,
            NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT,
            NULLIF(current_setting('app.client_ip', TRUE), '')::INET,
            LEFT(NULLIF(current_setting('app.user_agent', TRUE), ''), 500));
    RETURN NULL;
END;
$$;

-- more tables under audit (users: secrets stripped, login bookkeeping columns excluded)
CREATE TRIGGER trg_users_audit AFTER INSERT OR DELETE OR UPDATE OF email, phone, first_name, middle_name, last_name,
        status, email_verified, phone_verified, account_locked, account_locked_until, password_hash, mfa_enabled,
        mfa_secret, security_answer_hash, referred_by, is_deleted ON users
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log('user_id', 'password_hash', 'security_answer_hash', 'mfa_secret');
CREATE TRIGGER trg_categories_audit            AFTER INSERT OR UPDATE OR DELETE ON categories            FOR EACH ROW EXECUTE FUNCTION fn_audit_log('category_id');
CREATE TRIGGER trg_subcategories_audit         AFTER INSERT OR UPDATE OR DELETE ON subcategories         FOR EACH ROW EXECUTE FUNCTION fn_audit_log('subcategory_id');
CREATE TRIGGER trg_brands_audit                AFTER INSERT OR UPDATE OR DELETE ON brands                FOR EACH ROW EXECUTE FUNCTION fn_audit_log('brand_id');
CREATE TRIGGER trg_reviews_audit               AFTER INSERT OR UPDATE OR DELETE ON reviews               FOR EACH ROW EXECUTE FUNCTION fn_audit_log('review_id');
CREATE TRIGGER trg_system_configurations_audit AFTER INSERT OR UPDATE OR DELETE ON system_configurations FOR EACH ROW EXECUTE FUNCTION fn_audit_log('config_id');
CREATE TRIGGER trg_feature_flags_audit         AFTER INSERT OR UPDATE OR DELETE ON feature_flags         FOR EACH ROW EXECUTE FUNCTION fn_audit_log('feature_id');

-- LOGIN: a successful login_history row writes a LOGIN audit entry and refreshes users.last_login_ip /
-- last_device; a failed one refreshes users.last_failed_login. (Counting failures stays with the app.)
CREATE OR REPLACE FUNCTION fn_login_history_effects()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.user_id IS NULL THEN RETURN NULL; END IF;
    IF NEW.login_status = 'S' THEN
        UPDATE users SET last_login_ip = NEW.ip_address, last_device = LEFT(NEW.user_agent, 255)
         WHERE user_id = NEW.user_id;
        INSERT INTO audit_logs (table_name, record_id, action_type, new_value, changed_by, ip_address, user_agent)
        VALUES ('users', NEW.user_id::TEXT, 'LOGIN', jsonb_build_object('session_id', NEW.session_id),
                NEW.user_id, NEW.ip_address, NEW.user_agent);
    ELSIF NEW.login_status = 'F' THEN
        UPDATE users SET last_failed_login = NEW.created_at WHERE user_id = NEW.user_id;
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_login_history_effects AFTER INSERT ON login_history
    FOR EACH ROW EXECUTE FUNCTION fn_login_history_effects();

-- LOGOUT: a session getting its ended_at stamped.
CREATE OR REPLACE FUNCTION fn_session_logout_audit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_logs (table_name, record_id, action_type, new_value, changed_by, ip_address, user_agent)
    VALUES ('users', NEW.user_id::TEXT, 'LOGOUT', jsonb_build_object('session_id', NEW.session_id),
            NEW.user_id, NEW.ip_address, NEW.user_agent);
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_sessions_logout_audit AFTER UPDATE OF ended_at ON sessions
    FOR EACH ROW WHEN (OLD.ended_at IS NULL AND NEW.ended_at IS NOT NULL)
    EXECUTE FUNCTION fn_session_logout_audit();

-- =====================================================================
-- SUPPORTING INDEXES for the new foreign keys / filters
-- =====================================================================
CREATE INDEX idx_products_not_deleted  ON products (category_id) WHERE NOT is_deleted;
CREATE INDEX idx_orders_not_deleted    ON orders (user_id, created_at DESC) WHERE NOT is_deleted;
CREATE INDEX idx_users_security_lock   ON users (account_locked_until) WHERE account_locked;
CREATE INDEX idx_reviews_not_deleted   ON reviews (product_id) WHERE NOT is_deleted AND moderation_status = 'A';

-- =====================================================================
-- TABLE COMMENTS (relationship map for the new tables)
-- =====================================================================
COMMENT ON TABLE countries              IS 'Geography root. 1:N states';
COMMENT ON TABLE states                 IS 'N:1 countries, 1:N districts';
COMMENT ON TABLE districts              IS 'N:1 states, 1:N cities';
COMMENT ON TABLE cities                 IS 'N:1 districts, 1:N postal_codes';
COMMENT ON TABLE postal_codes           IS 'N:1 cities, N:1 delivery_zones, 1:N addresses. Replaces pincodes';
COMMENT ON TABLE product_seo            IS '1:1 products. SEO / social metadata';
COMMENT ON TABLE product_audit_logs     IS 'N:1 products, N:1 users. One row per changed product field';
COMMENT ON TABLE order_tracking_events  IS 'N:1 orders, N:1 shipments (same order). Shipment milestones';
COMMENT ON TABLE dashboard_metrics      IS 'Pre-computed KPIs per period';
COMMENT ON TABLE revenue_analytics      IS 'Revenue per period, optionally per category';
COMMENT ON TABLE customer_analytics     IS '1:1 users. Segment and lifetime value';
COMMENT ON TABLE product_analytics      IS 'Daily per-product funnel';
COMMENT ON TABLE conversion_analytics   IS 'Daily store-wide funnel';
COMMENT ON TABLE cart_abandonment_logs  IS '1:1 carts. Abandonment, reminders, recovery';

-- =====================================================================
-- Re-enable triggers disabled for the backfills
-- =====================================================================
ALTER TABLE addresses  ENABLE TRIGGER USER;
ALTER TABLE users      ENABLE TRIGGER USER;
ALTER TABLE inventory  ENABLE TRIGGER USER;
ALTER TABLE reviews    ENABLE TRIGGER USER;
ALTER TABLE coupons    ENABLE TRIGGER USER;

-- =====================================================================
-- updated_at triggers + row level security for every NEW table
-- (same behaviour the base schema applied to its own tables)
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

-- =====================================================================
-- 21. VERIFICATION  (U14, U15, U16 plus structure checks). Any miss aborts and rolls back the upgrade.
-- =====================================================================
DO $$
DECLARE
    v_missing TEXT;
    v_tables  INTEGER;
    v_fks     INTEGER;
    v_cons    INTEGER;
    v_cols    INTEGER;
BEGIN
    SELECT string_agg(req.name, ', ') INTO v_missing
    FROM (VALUES
        -- U14 product validation
        ('ck_products_mrp'), ('ck_products_selling_price'), ('ck_products_cost_price'), ('ck_products_price_le_mrp'),
        ('ck_products_discount_pct'), ('ck_products_stock_qty'), ('ck_products_dimensions'), ('ck_products_gst'),
        -- U16 candidate keys
        ('uq_users_email'), ('uq_users_phone'), ('uq_products_sku'), ('uq_products_barcode'), ('uq_products_slug'),
        ('uq_orders_order_number'), ('uq_invoices_invoice_number'), ('uq_coupons_coupon_code'),
        -- U15 user validation
        ('ck_users_phone_length'), ('ck_users_email_not_empty'), ('ck_users_first_name_not_empty'), ('ck_users_last_name_not_empty'),
        -- U10 / U11 / U12 / U17
        ('ck_reviews_rating'), ('ck_reviews_counts'), ('ck_coupons_discount_pct'), ('ck_coupons_remaining_uses'),
        ('uq_system_configurations_config_key')
    ) AS req(name)
    WHERE NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conname = req.name);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade verification failed, missing constraints: %', v_missing;
    END IF;

    IF to_regclass('public.uq_cart_items_line') IS NULL THEN
        RAISE EXCEPTION 'Upgrade verification failed: cart duplicate protection (uq_cart_items_line) is missing';
    END IF;

    SELECT COUNT(*) INTO v_tables FROM pg_tables WHERE schemaname = 'public';
    SELECT COUNT(*) INTO v_fks    FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace WHERE n.nspname = 'public' AND c.contype = 'f';
    SELECT COUNT(*) INTO v_cons   FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace WHERE n.nspname = 'public' AND c.contype IN ('p','f','u','c');
    SELECT COUNT(*) INTO v_cols   FROM information_schema.columns WHERE table_schema = 'public'
                                     AND table_name IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public');
    RAISE NOTICE 'RT Crackers upgrade v2 OK: % tables, % columns, % foreign keys, % constraints (PK/FK/UNIQUE/CHECK)',
                 v_tables, v_cols, v_fks, v_cons;
END;
$$;

COMMIT;
