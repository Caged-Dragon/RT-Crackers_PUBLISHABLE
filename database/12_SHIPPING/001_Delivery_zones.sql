-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/001_Delivery_zones.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- delivery_zones | Purpose: groups of pincodes sharing delivery rules.
-- Keys : PK(zone_id) | CK/AK: zone_code, zone_name
-- Rel  : 1:N pincodes, zone_shipping_rates
-- BCNF : attributes depend only on the zone.
-- ---------------------------------------------------------------------
CREATE TABLE delivery_zones (
    zone_id            SMALLINT     GENERATED ALWAYS AS IDENTITY,
    zone_code          VARCHAR(10)  NOT NULL,
    zone_name          VARCHAR(80)  NOT NULL,
    description        VARCHAR(255),
    order_cutoff_time  TIME         NOT NULL DEFAULT '16:00',
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_delivery_zones PRIMARY KEY (zone_id),
    CONSTRAINT uq_delivery_zones_zone_code UNIQUE (zone_code),
    CONSTRAINT uq_delivery_zones_zone_name UNIQUE (zone_name)
);
