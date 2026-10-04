-- =====================================================================
-- RT CRACKERS | 11_PAYMENTS/002_Cod_transactions.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- cod_transactions | Purpose: cash collected at the doorstep for an order (one per order).
-- Keys : PK(cod_transaction_id) | CK/AK: order_id, receipt_number
-- Rel  : 1:1 orders, N:1 admins (delivery agent); 1:1 cash_collection_logs
-- BCNF : amount due is read from orders.total_amount (not copied); only the collected amount is recorded.
-- ---------------------------------------------------------------------
CREATE TABLE cod_transactions (
    cod_transaction_id  BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id            BIGINT         NOT NULL,
    receipt_number      VARCHAR(25)    NOT NULL DEFAULT ('COD' || TO_CHAR(CURRENT_DATE, 'YYMM') || LPAD(NEXTVAL('seq_cod_receipt')::TEXT, 6, '0')),
    amount_collected    NUMERIC(12,2)  NOT NULL DEFAULT 0,
    status              CHAR(1)        NOT NULL DEFAULT 'P',     -- P pending, C collected, F failed/refused, X cancelled
    collected_by        INTEGER,
    collected_at        TIMESTAMP,
    failure_reason      VARCHAR(255),
    created_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cod_transactions PRIMARY KEY (cod_transaction_id),
    CONSTRAINT uq_cod_transactions_order   UNIQUE (order_id),
    CONSTRAINT uq_cod_transactions_receipt UNIQUE (receipt_number),
    CONSTRAINT fk_cod_transactions_order    FOREIGN KEY (order_id)     REFERENCES orders (order_id) ON DELETE RESTRICT,
    CONSTRAINT fk_cod_transactions_agent    FOREIGN KEY (collected_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_cod_transactions_status   CHECK (status IN ('P','C','F','X')),
    CONSTRAINT ck_cod_transactions_amount   CHECK (amount_collected >= 0),
    CONSTRAINT ck_cod_transactions_collected CHECK ((status = 'C' AND amount_collected > 0 AND collected_by IS NOT NULL AND collected_at IS NOT NULL)
                                                 OR (status <> 'C' AND amount_collected = 0))
);

-- cod_transactions: collected amount must equal the order total; marks the order as paid
CREATE OR REPLACE FUNCTION fn_cod_collected()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_total NUMERIC(12,2);
BEGIN
    IF NEW.status = 'C' THEN
        SELECT total_amount INTO v_total FROM orders WHERE order_id = NEW.order_id;
        IF NEW.amount_collected <> v_total THEN
            RAISE EXCEPTION 'COD amount collected (%) does not match order total (%)', NEW.amount_collected, v_total;
        END IF;
        UPDATE orders SET payment_status = 'C' WHERE order_id = NEW.order_id;
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_cod_transactions_collected AFTER INSERT OR UPDATE OF status, amount_collected ON cod_transactions
    FOR EACH ROW EXECUTE FUNCTION fn_cod_collected();
