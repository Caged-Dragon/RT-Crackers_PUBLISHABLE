-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/002_Pincodes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- pincodes | Purpose: serviceable-area master; owns district/state/country so addresses stay BCNF.
-- Keys : PK(pincode)
-- Rel  : N:1 delivery_zones; 1:N addresses
-- BCNF : pincode -> district, state, country, zone (pincode is the key). Removing these from
--        addresses eliminates the transitive dependency postal_code -> district/state.
-- ---------------------------------------------------------------------
CREATE TABLE pincodes (
    pincode         CHAR(6)      NOT NULL,
    district        VARCHAR(80)  NOT NULL,
    state           VARCHAR(80)  NOT NULL,
    country_code    CHAR(2)      NOT NULL DEFAULT 'IN',
    zone_id         SMALLINT     NOT NULL,
    is_serviceable  BOOLEAN      NOT NULL DEFAULT FALSE,   -- fireworks are restricted in some areas
    cod_available   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_pincodes PRIMARY KEY (pincode),
    CONSTRAINT fk_pincodes_zone FOREIGN KEY (zone_id) REFERENCES delivery_zones (zone_id) ON DELETE RESTRICT,
    CONSTRAINT ck_pincodes_format CHECK (pincode ~ '^[1-9][0-9]{5}$')
);
