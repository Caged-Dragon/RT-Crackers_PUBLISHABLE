-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/009_U07_Order_tracking_events.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U7 Order tracking events
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

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

