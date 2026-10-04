-- =====================================================================
-- RT CRACKERS | 10_ORDERS/006_Invoices.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- invoices | Purpose: GST invoice for an order (one per order).
-- Keys : PK(invoice_id) | CK/AK: invoice_number, order_id
-- Rel  : 1:1 orders, N:1 admins
-- BCNF : amounts are read from the order, not copied.
-- ---------------------------------------------------------------------
CREATE TABLE invoices (
    invoice_id         BIGINT        GENERATED ALWAYS AS IDENTITY,
    invoice_number     VARCHAR(25)   NOT NULL DEFAULT ('INV' || TO_CHAR(CURRENT_DATE, 'YYMM') || LPAD(NEXTVAL('seq_invoice_number')::TEXT, 6, '0')),
    order_id           BIGINT        NOT NULL,
    invoice_date       DATE          NOT NULL DEFAULT CURRENT_DATE,
    customer_gstin     CHAR(15),
    invoice_pdf_url    VARCHAR(500),
    status             CHAR(1)       NOT NULL DEFAULT 'G',       -- G generated, C cancelled
    cancelled_at       TIMESTAMP,
    issued_by          INTEGER,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_invoices PRIMARY KEY (invoice_id),
    CONSTRAINT uq_invoices_invoice_number UNIQUE (invoice_number),
    CONSTRAINT uq_invoices_order_id       UNIQUE (order_id),
    CONSTRAINT fk_invoices_order     FOREIGN KEY (order_id)  REFERENCES orders (order_id) ON DELETE RESTRICT,
    CONSTRAINT fk_invoices_issued_by FOREIGN KEY (issued_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_invoices_status    CHECK (status IN ('G','C')),
    CONSTRAINT ck_invoices_cancelled CHECK ((status = 'C') = (cancelled_at IS NOT NULL)),
    CONSTRAINT ck_invoices_gstin     CHECK (customer_gstin IS NULL OR customer_gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
);
