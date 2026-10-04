-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/003_Shipping_methods.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- shipping_methods | Purpose: delivery speeds offered (standard, express).
-- Keys : PK(shipping_method_id) | CK/AK: method_code, method_name
-- Rel  : 1:N zone_shipping_rates, orders
-- BCNF : attributes depend only on the method; price depends on (zone, method) so lives in zone_shipping_rates.
-- ---------------------------------------------------------------------
CREATE TABLE shipping_methods (
    shipping_method_id  SMALLINT     GENERATED ALWAYS AS IDENTITY,
    method_code         VARCHAR(10)  NOT NULL,
    method_name         VARCHAR(60)  NOT NULL,
    description         VARCHAR(255),
    min_delivery_days   SMALLINT     NOT NULL DEFAULT 1,
    max_delivery_days   SMALLINT     NOT NULL DEFAULT 7,
    slot_start          TIME,
    slot_end            TIME,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_shipping_methods PRIMARY KEY (shipping_method_id),
    CONSTRAINT uq_shipping_methods_method_code UNIQUE (method_code),
    CONSTRAINT uq_shipping_methods_method_name UNIQUE (method_name),
    CONSTRAINT ck_shipping_methods_days CHECK (min_delivery_days >= 0 AND max_delivery_days >= min_delivery_days),
    CONSTRAINT ck_shipping_methods_slot CHECK (slot_start IS NULL OR slot_end IS NULL OR slot_start < slot_end)
);
