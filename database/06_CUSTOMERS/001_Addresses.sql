-- =====================================================================
-- RT CRACKERS | 06_CUSTOMERS/001_Addresses.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- addresses | Purpose: a user's delivery/billing addresses. district/state/country come from pincodes
--             (see view v_addresses_full which exposes them as columns).
-- Keys : PK(address_id)
-- Rel  : N:1 users, N:1 pincodes; 1:N orders (billing/shipping), 1:1 saved_addresses
-- BCNF : every attribute depends on address_id; postal_code's dependents were moved out. Rows referenced by
--        an order are immutable (trigger) so order history stays correct.
-- ---------------------------------------------------------------------
CREATE TABLE addresses (
    address_id       BIGINT            GENERATED ALWAYS AS IDENTITY,
    user_id          BIGINT            NOT NULL,
    recipient_name   VARCHAR(120)      NOT NULL,
    recipient_phone  CHAR(10)          NOT NULL,
    house_no         VARCHAR(30)       NOT NULL,
    street           VARCHAR(150)      NOT NULL,
    area             VARCHAR(100)      NOT NULL,
    landmark         VARCHAR(150),
    city             VARCHAR(80)       NOT NULL,
    postal_code      CHAR(6)           NOT NULL,
    latitude         DOUBLE PRECISION,
    longitude        DOUBLE PRECISION,
    address_type     CHAR(1)           NOT NULL DEFAULT 'H',   -- H home, W work, O other
    is_default       BOOLEAN           NOT NULL DEFAULT FALSE,
    is_archived      BOOLEAN           NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_addresses PRIMARY KEY (address_id),
    CONSTRAINT fk_addresses_user    FOREIGN KEY (user_id)     REFERENCES users (user_id)       ON DELETE CASCADE,
    CONSTRAINT fk_addresses_pincode FOREIGN KEY (postal_code) REFERENCES pincodes (pincode)    ON DELETE RESTRICT,
    CONSTRAINT ck_addresses_phone   CHECK (recipient_phone ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_addresses_type    CHECK (address_type IN ('H','W','O')),
    CONSTRAINT ck_addresses_latitude  CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_addresses_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);
CREATE UNIQUE INDEX uq_addresses_one_default_per_user ON addresses (user_id) WHERE is_default AND NOT is_archived;

CREATE VIEW v_addresses_full AS
SELECT a.address_id, a.user_id, a.recipient_name, a.recipient_phone, a.house_no, a.street, a.area,
       a.landmark, a.city, p.district, p.state, p.country_code AS country, a.postal_code,
       a.latitude, a.longitude, a.address_type, a.is_default, a.is_archived, a.created_at, a.updated_at
FROM addresses a
JOIN pincodes p ON p.pincode = a.postal_code;

-- addresses used by an order are immutable (create a new address instead)
CREATE OR REPLACE FUNCTION fn_protect_used_address()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF ROW(NEW.recipient_name, NEW.recipient_phone, NEW.house_no, NEW.street, NEW.area, NEW.landmark, NEW.city, NEW.postal_code)
       IS DISTINCT FROM
       ROW(OLD.recipient_name, OLD.recipient_phone, OLD.house_no, OLD.street, OLD.area, OLD.landmark, OLD.city, OLD.postal_code)
       AND EXISTS (SELECT 1 FROM orders WHERE billing_address_id = OLD.address_id OR shipping_address_id = OLD.address_id)
    THEN
        RAISE EXCEPTION 'Address % is referenced by an order and cannot be edited; create a new address and archive this one', OLD.address_id;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_addresses_protect_used BEFORE UPDATE ON addresses
    FOR EACH ROW EXECUTE FUNCTION fn_protect_used_address();
