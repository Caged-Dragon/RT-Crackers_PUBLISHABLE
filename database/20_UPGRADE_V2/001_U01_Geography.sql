-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/001_U01_Geography.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U1 Geographical normalization (countries..postal_codes, addresses FK)
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

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

