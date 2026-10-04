-- =====================================================================
-- RT CRACKERS | 11_PAYMENTS/004_Refunds.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- refunds | Purpose: money returned to customers (bank transfer or cash) for cancelled/returned COD orders.
-- Keys : PK(refund_id) | CK/AK: refund_number
-- Rel  : N:1 orders, N:1 return_requests, N:1 admins
-- BCNF : attributes depend on the refund. Only the last 4 digits of the account are stored.
-- ---------------------------------------------------------------------
CREATE TABLE refunds (
    refund_id               BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id                BIGINT         NOT NULL,
    return_request_id       BIGINT,
    refund_amount           NUMERIC(12,2)  NOT NULL,
    refund_method           CHAR(1)        NOT NULL,             -- B bank transfer, C cash
    account_holder_name     VARCHAR(120),
    bank_name               VARCHAR(100),
    account_last4           CHAR(4),
    ifsc_code               CHAR(11),
    transaction_reference   VARCHAR(60),
    reason                  VARCHAR(255),
    status                  CHAR(1)        NOT NULL DEFAULT 'P', -- P pending, A approved, C completed, R rejected
    processed_by            INTEGER,
    processed_at            TIMESTAMP,
    created_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_refunds PRIMARY KEY (refund_id),
    CONSTRAINT fk_refunds_order   FOREIGN KEY (order_id)          REFERENCES orders (order_id)                   ON DELETE RESTRICT,
    CONSTRAINT fk_refunds_return  FOREIGN KEY (return_request_id) REFERENCES return_requests (return_request_id) ON DELETE SET NULL,
    CONSTRAINT fk_refunds_admin   FOREIGN KEY (processed_by)      REFERENCES admins (admin_id)                   ON DELETE SET NULL,
    CONSTRAINT ck_refunds_amount  CHECK (refund_amount > 0),
    CONSTRAINT ck_refunds_method  CHECK (refund_method IN ('B','C')),
    CONSTRAINT ck_refunds_status  CHECK (status IN ('P','A','C','R')),
    CONSTRAINT ck_refunds_bank    CHECK (refund_method = 'C' OR (account_holder_name IS NOT NULL AND ifsc_code IS NOT NULL AND account_last4 IS NOT NULL)),
    CONSTRAINT ck_refunds_last4   CHECK (account_last4 IS NULL OR account_last4 ~ '^[0-9]{4}$'),
    CONSTRAINT ck_refunds_ifsc    CHECK (ifsc_code IS NULL OR ifsc_code ~ '^[A-Z]{4}0[A-Z0-9]{6}$'),
    CONSTRAINT ck_refunds_completed CHECK ((status IN ('C','R')) = (processed_at IS NOT NULL))
);
