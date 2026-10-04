-- =====================================================================
-- RT CRACKERS | 10_ORDERS/008_Replacement_requests.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- replacement_requests | Purpose: request to replace a faulty/wrong item; may spawn a zero-value replacement order.
-- Keys : PK(replacement_request_id) | CK/AK: replacement_number, replacement_order_id
-- Rel  : N:1 order_items, N:1 return_requests (optional), N:1 orders (replacement order), N:1 admins
-- BCNF : attributes depend on the request.
-- ---------------------------------------------------------------------
CREATE TABLE replacement_requests (
    replacement_request_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    replacement_number      VARCHAR(25)   NOT NULL DEFAULT ('REP' || TO_CHAR(CURRENT_DATE, 'YYMM') || LPAD(NEXTVAL('seq_replacement_number')::TEXT, 6, '0')),
    order_item_id           BIGINT        NOT NULL,
    return_request_id       BIGINT,
    replacement_order_id    BIGINT,
    quantity                INTEGER       NOT NULL,
    reason_code             CHAR(1)       NOT NULL,           -- D damaged, W wrong item, Q quality, M missing, O other
    reason_text             VARCHAR(500),
    status                  CHAR(1)       NOT NULL DEFAULT 'R', -- R requested, A approved, J rejected, S shipped, C completed
    resolved_by             INTEGER,
    resolved_at             TIMESTAMP,
    admin_remarks           VARCHAR(500),
    created_at              TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_replacement_requests PRIMARY KEY (replacement_request_id),
    CONSTRAINT uq_replacement_requests_number   UNIQUE (replacement_number),
    CONSTRAINT uq_replacement_requests_order    UNIQUE (replacement_order_id),
    CONSTRAINT fk_replacement_requests_item     FOREIGN KEY (order_item_id)        REFERENCES order_items (order_item_id)         ON DELETE RESTRICT,
    CONSTRAINT fk_replacement_requests_return   FOREIGN KEY (return_request_id)    REFERENCES return_requests (return_request_id) ON DELETE SET NULL,
    CONSTRAINT fk_replacement_requests_order    FOREIGN KEY (replacement_order_id) REFERENCES orders (order_id)                   ON DELETE SET NULL,
    CONSTRAINT fk_replacement_requests_resolver FOREIGN KEY (resolved_by)          REFERENCES admins (admin_id)                   ON DELETE SET NULL,
    CONSTRAINT ck_replacement_requests_quantity CHECK (quantity > 0),
    CONSTRAINT ck_replacement_requests_reason   CHECK (reason_code IN ('D','W','Q','M','O')),
    CONSTRAINT ck_replacement_requests_status   CHECK (status IN ('R','A','J','S','C')),
    CONSTRAINT ck_replacement_requests_resolved CHECK ((status = 'R') = (resolved_at IS NULL))
);
