-- =====================================================================
-- RT CRACKERS | 17_ANALYTICS/004_Sales_reports.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- sales_reports | Purpose: pre-aggregated daily/weekly/monthly sales snapshots filled by a scheduled job.
-- Keys : PK(sales_report_id) | CK/AK: (report_type, report_date)
-- Rel  : none (derived reporting table)
-- BCNF : net_sales is GENERATED; all other figures depend on the (type, date) candidate key.
-- ---------------------------------------------------------------------
CREATE TABLE sales_reports (
    sales_report_id   INTEGER        GENERATED ALWAYS AS IDENTITY,
    report_type       CHAR(1)        NOT NULL,                -- D daily, W weekly, M monthly
    report_date       DATE           NOT NULL,
    total_orders      INTEGER        NOT NULL DEFAULT 0,
    cancelled_orders  INTEGER        NOT NULL DEFAULT 0,
    returned_orders   INTEGER        NOT NULL DEFAULT 0,
    items_sold        INTEGER        NOT NULL DEFAULT 0,
    gross_sales       NUMERIC(14,2)  NOT NULL DEFAULT 0,
    discount_total    NUMERIC(14,2)  NOT NULL DEFAULT 0,
    tax_total         NUMERIC(14,2)  NOT NULL DEFAULT 0,
    shipping_total    NUMERIC(14,2)  NOT NULL DEFAULT 0,
    net_sales         NUMERIC(14,2)  GENERATED ALWAYS AS (gross_sales - discount_total + tax_total + shipping_total) STORED,
    cod_collected     NUMERIC(14,2)  NOT NULL DEFAULT 0,
    created_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_sales_reports PRIMARY KEY (sales_report_id),
    CONSTRAINT uq_sales_reports_type_date UNIQUE (report_type, report_date),
    CONSTRAINT ck_sales_reports_type    CHECK (report_type IN ('D','W','M')),
    CONSTRAINT ck_sales_reports_counts  CHECK (total_orders >= 0 AND cancelled_orders >= 0 AND returned_orders >= 0 AND items_sold >= 0),
    CONSTRAINT ck_sales_reports_amounts CHECK (gross_sales >= 0 AND discount_total >= 0 AND tax_total >= 0 AND shipping_total >= 0 AND cod_collected >= 0)
);
