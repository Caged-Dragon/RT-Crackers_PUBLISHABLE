-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/004_Shipments.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- shipments | Purpose: physical dispatch records for an order (an order may ship in several packages).
-- Keys : PK(shipment_id) | CK/AK: carrier_awb_number
-- Rel  : N:1 orders, N:1 admins (delivery agent)
-- BCNF : expected/actual delivery dates live on orders only, so they are not duplicated here.
-- ---------------------------------------------------------------------
CREATE TABLE shipments (
    shipment_id          BIGINT       GENERATED ALWAYS AS IDENTITY,
    order_id             BIGINT       NOT NULL,
    carrier_awb_number   VARCHAR(40),
    delivery_partner     VARCHAR(80),
    delivery_agent_id    INTEGER,
    package_count        SMALLINT     NOT NULL DEFAULT 1,
    package_weight_kg    REAL,
    packed_at            TIMESTAMP,
    shipped_at           TIMESTAMP,
    notes                VARCHAR(500),
    created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_shipments PRIMARY KEY (shipment_id),
    CONSTRAINT uq_shipments_awb UNIQUE (carrier_awb_number),
    CONSTRAINT fk_shipments_order FOREIGN KEY (order_id)          REFERENCES orders (order_id) ON DELETE RESTRICT,
    CONSTRAINT fk_shipments_agent FOREIGN KEY (delivery_agent_id) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_shipments_package_count  CHECK (package_count > 0),
    CONSTRAINT ck_shipments_package_weight CHECK (package_weight_kg IS NULL OR package_weight_kg > 0),
    CONSTRAINT ck_shipments_dispatch_order CHECK (packed_at IS NULL OR shipped_at IS NULL OR shipped_at >= packed_at)
);
