-- =====================================================================
-- RT CRACKERS | 10_ORDERS/007_Return_requests.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- return_requests | Purpose: customer return requests (damaged, wrong item...). Customer = order's user.
-- Keys : PK(return_request_id) | CK/AK: return_number
-- Rel  : N:1 order_items, N:1 admins; 1:N refunds
-- BCNF : attributes depend on the request.
-- ---------------------------------------------------------------------
CREATE TABLE return_requests (
    return_request_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    return_number      VARCHAR(25)   NOT NULL DEFAULT ('RET' || TO_CHAR(CURRENT_DATE, 'YYMM') || LPAD(NEXTVAL('seq_return_number')::TEXT, 6, '0')),
    order_item_id      BIGINT        NOT NULL,
    quantity           INTEGER       NOT NULL,
    reason_code        CHAR(1)       NOT NULL,                -- D damaged, W wrong item, Q quality, M missing, O other
    reason_text        VARCHAR(500),
    evidence_url       VARCHAR(500),
    status             CHAR(1)       NOT NULL DEFAULT 'R',    -- R requested, A approved, J rejected, P picked up, C completed
    resolved_by        INTEGER,
    resolved_at        TIMESTAMP,
    admin_remarks      VARCHAR(500),
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_return_requests PRIMARY KEY (return_request_id),
    CONSTRAINT uq_return_requests_number UNIQUE (return_number),
    CONSTRAINT fk_return_requests_order_item FOREIGN KEY (order_item_id) REFERENCES order_items (order_item_id) ON DELETE RESTRICT,
    CONSTRAINT fk_return_requests_resolved_by FOREIGN KEY (resolved_by)  REFERENCES admins (admin_id)           ON DELETE SET NULL,
    CONSTRAINT ck_return_requests_quantity CHECK (quantity > 0),
    CONSTRAINT ck_return_requests_reason   CHECK (reason_code IN ('D','W','Q','M','O')),
    CONSTRAINT ck_return_requests_status   CHECK (status IN ('R','A','J','P','C')),
    CONSTRAINT ck_return_requests_resolved CHECK ((status = 'R') = (resolved_at IS NULL))
);
