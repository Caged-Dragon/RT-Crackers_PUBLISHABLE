-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/009_Zone_shipping_rates.sql
-- Source: rt_crackers_schema.sql (split by module) | extra file, not in original tree
-- =====================================================================

-- ---------------------------------------------------------------------
-- zone_shipping_rates | Purpose: shipping price per (zone, method).
-- Keys : COMPOSITE PK(zone_id, shipping_method_id)
-- Rel  : N:1 delivery_zones, N:1 shipping_methods
-- BCNF : charges depend on the full composite key, not on either half.
-- ---------------------------------------------------------------------
CREATE TABLE zone_shipping_rates (
    zone_id                  SMALLINT       NOT NULL,
    shipping_method_id       SMALLINT       NOT NULL,
    base_charge              NUMERIC(10,2)  NOT NULL DEFAULT 0,
    per_kg_charge            NUMERIC(10,2)  NOT NULL DEFAULT 0,
    free_shipping_threshold  NUMERIC(12,2),
    is_active                BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at               TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_zone_shipping_rates PRIMARY KEY (zone_id, shipping_method_id),
    CONSTRAINT fk_zone_shipping_rates_zone   FOREIGN KEY (zone_id)            REFERENCES delivery_zones (zone_id)            ON DELETE CASCADE,
    CONSTRAINT fk_zone_shipping_rates_method FOREIGN KEY (shipping_method_id) REFERENCES shipping_methods (shipping_method_id) ON DELETE CASCADE,
    CONSTRAINT ck_zone_shipping_rates_charges CHECK (base_charge >= 0 AND per_kg_charge >= 0),
    CONSTRAINT ck_zone_shipping_rates_free    CHECK (free_shipping_threshold IS NULL OR free_shipping_threshold > 0)
);
