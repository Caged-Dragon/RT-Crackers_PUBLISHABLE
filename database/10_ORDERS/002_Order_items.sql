-- =====================================================================
-- RT CRACKERS | 10_ORDERS/002_Order_items.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- order_items | Purpose: order lines with price snapshots at purchase time (history, not current price).
-- Keys : PK(order_item_id) | CK/AK: (order_id, product_id, variant_id|0) via unique index
-- Rel  : N:1 orders, products, product_variants (composite FK); 1:N return_requests, replacement_requests; 1:1 reviews
-- BCNF : snapshots are facts about this line at order time; line_total is GENERATED.
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id          BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id               BIGINT         NOT NULL,
    product_id             BIGINT         NOT NULL,
    variant_id             BIGINT,
    sku_snapshot           VARCHAR(40)    NOT NULL,
    product_name_snapshot  VARCHAR(200)   NOT NULL,
    quantity               INTEGER        NOT NULL,
    mrp                    NUMERIC(12,2)  NOT NULL,
    unit_price             NUMERIC(12,2)  NOT NULL,
    gst_percentage         NUMERIC(5,2)   NOT NULL,
    discount_amount        NUMERIC(12,2)  NOT NULL DEFAULT 0,
    tax_amount             NUMERIC(12,2)  NOT NULL DEFAULT 0,
    line_total             NUMERIC(12,2)  GENERATED ALWAYS AS (unit_price * quantity - discount_amount + tax_amount) STORED,
    created_at             TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_order_items PRIMARY KEY (order_item_id),
    CONSTRAINT fk_order_items_order   FOREIGN KEY (order_id)   REFERENCES orders (order_id)     ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT,
    CONSTRAINT fk_order_items_variant FOREIGN KEY (product_id, variant_id) REFERENCES product_variants (product_id, variant_id) ON DELETE RESTRICT,
    CONSTRAINT ck_order_items_quantity  CHECK (quantity > 0),
    CONSTRAINT ck_order_items_prices    CHECK (mrp > 0 AND unit_price > 0 AND unit_price <= mrp),
    CONSTRAINT ck_order_items_gst       CHECK (gst_percentage BETWEEN 0 AND 40),
    CONSTRAINT ck_order_items_amounts   CHECK (discount_amount >= 0 AND tax_amount >= 0 AND discount_amount <= unit_price * quantity)
);
CREATE UNIQUE INDEX uq_order_items_line ON order_items (order_id, product_id, COALESCE(variant_id, 0));
