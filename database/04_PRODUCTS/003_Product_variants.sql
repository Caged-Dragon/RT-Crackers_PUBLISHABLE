-- =====================================================================
-- RT CRACKERS | 04_PRODUCTS/003_Product_variants.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_variants | Purpose: pack sizes / options with their own price (e.g. Box of 10, Box of 25).
-- Keys : PK(variant_id) | CK/AK: variant_sku, barcode, (product_id, variant_name), (product_id, variant_id)
-- Rel  : N:1 products; 1:N inventory, attribute_values, cart_items, order_items
-- BCNF : price/weight depend on the variant; (product_id, variant_id) pair enables composite FKs.
-- ---------------------------------------------------------------------
CREATE TABLE product_variants (
    variant_id     BIGINT         GENERATED ALWAYS AS IDENTITY,
    product_id     BIGINT         NOT NULL,
    variant_sku    VARCHAR(40)    NOT NULL,
    barcode        VARCHAR(32),
    variant_name   VARCHAR(120)   NOT NULL,
    pack_size      SMALLINT       NOT NULL DEFAULT 1,
    mrp            NUMERIC(12,2)  NOT NULL,
    selling_price  NUMERIC(12,2)  NOT NULL,
    cost_price     NUMERIC(12,2)  NOT NULL,
    weight         NUMERIC(10,3)  NOT NULL DEFAULT 0,
    is_active      BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_variants PRIMARY KEY (variant_id),
    CONSTRAINT uq_product_variants_sku      UNIQUE (variant_sku),
    CONSTRAINT uq_product_variants_barcode  UNIQUE (barcode),
    CONSTRAINT uq_product_variants_name     UNIQUE (product_id, variant_name),
    CONSTRAINT uq_product_variants_prod_var UNIQUE (product_id, variant_id),
    CONSTRAINT fk_product_variants_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT ck_product_variants_pack   CHECK (pack_size > 0),
    CONSTRAINT ck_product_variants_prices CHECK (mrp > 0 AND selling_price > 0 AND cost_price > 0 AND selling_price <= mrp),
    CONSTRAINT ck_product_variants_weight CHECK (weight >= 0)
);
