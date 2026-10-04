-- =====================================================================
-- RT CRACKERS | 11_PAYMENTS/003_Cash_collection_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- cash_collection_logs | Purpose: hand-over of collected cash from delivery agent to store cashier, per COD transaction.
-- Keys : PK(log_id) | CK/AK: cod_transaction_id
-- Rel  : 1:1 cod_transactions, N:1 admins (agent), N:1 admins (receiver)
-- BCNF : attributes depend on the hand-over record.
-- ---------------------------------------------------------------------
CREATE TABLE cash_collection_logs (
    log_id               BIGINT         GENERATED ALWAYS AS IDENTITY,
    cod_transaction_id   BIGINT         NOT NULL,
    handed_over_by       INTEGER        NOT NULL,
    received_by          INTEGER,
    handed_over_amount   NUMERIC(12,2)  NOT NULL,
    handed_over_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status               CHAR(1)        NOT NULL DEFAULT 'P',    -- P pending verification, V verified, D discrepancy
    remarks              VARCHAR(500),
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cash_collection_logs PRIMARY KEY (log_id),
    CONSTRAINT uq_cash_collection_logs_cod UNIQUE (cod_transaction_id),
    CONSTRAINT fk_cash_collection_logs_cod      FOREIGN KEY (cod_transaction_id) REFERENCES cod_transactions (cod_transaction_id) ON DELETE RESTRICT,
    CONSTRAINT fk_cash_collection_logs_agent    FOREIGN KEY (handed_over_by)     REFERENCES admins (admin_id)                     ON DELETE RESTRICT,
    CONSTRAINT fk_cash_collection_logs_receiver FOREIGN KEY (received_by)        REFERENCES admins (admin_id)                     ON DELETE SET NULL,
    CONSTRAINT ck_cash_collection_logs_amount   CHECK (handed_over_amount > 0),
    CONSTRAINT ck_cash_collection_logs_status   CHECK (status IN ('P','V','D'))
);
