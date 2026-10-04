-- =====================================================================
-- RT CRACKERS | 16_FESTIVALS/002_Festival_products.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- festival_products | Purpose: products featured in a festival.
-- Keys : COMPOSITE PK(festival_id, product_id)
-- Rel  : N:1 festivals, N:1 products
-- BCNF : display_order/is_highlighted depend on the whole pair.
-- ---------------------------------------------------------------------
CREATE TABLE festival_products (
    festival_id     INTEGER    NOT NULL,
    product_id      BIGINT     NOT NULL,
    display_order   SMALLINT   NOT NULL DEFAULT 0,
    is_highlighted  BOOLEAN    NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_festival_products PRIMARY KEY (festival_id, product_id),
    CONSTRAINT fk_festival_products_festival FOREIGN KEY (festival_id) REFERENCES festivals (festival_id) ON DELETE CASCADE,
    CONSTRAINT fk_festival_products_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)   ON DELETE CASCADE
);
