-- =====================================================================
-- RT CRACKERS | 16_FESTIVALS/004_Festival_discounts.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- festival_discounts | Purpose: festival price cuts scoped to a product, a category, or the whole festival (both NULL).
-- Keys : PK(festival_discount_id) | CK/AK: (festival_id, product_id|0, category_id|0) via unique index
-- Rel  : N:1 festivals, products, categories
-- BCNF : discount attributes depend on the candidate key (festival + scope).
-- ---------------------------------------------------------------------
CREATE TABLE festival_discounts (
    festival_discount_id  INTEGER        GENERATED ALWAYS AS IDENTITY,
    festival_id           INTEGER        NOT NULL,
    product_id            BIGINT,
    category_id           INTEGER,
    discount_percentage   DECIMAL(5,2)   NOT NULL,
    min_order_amount      NUMERIC(12,2)  NOT NULL DEFAULT 0,
    max_discount_amount   NUMERIC(12,2),
    is_active             BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_festival_discounts PRIMARY KEY (festival_discount_id),
    CONSTRAINT fk_festival_discounts_festival FOREIGN KEY (festival_id) REFERENCES festivals (festival_id)   ON DELETE CASCADE,
    CONSTRAINT fk_festival_discounts_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)     ON DELETE CASCADE,
    CONSTRAINT fk_festival_discounts_category FOREIGN KEY (category_id) REFERENCES categories (category_id)  ON DELETE CASCADE,
    CONSTRAINT ck_festival_discounts_pct    CHECK (discount_percentage > 0 AND discount_percentage <= 100),
    CONSTRAINT ck_festival_discounts_scope  CHECK (product_id IS NULL OR category_id IS NULL),
    CONSTRAINT ck_festival_discounts_amount CHECK (min_order_amount >= 0 AND (max_discount_amount IS NULL OR max_discount_amount > 0))
);
CREATE UNIQUE INDEX uq_festival_discounts_scope ON festival_discounts (festival_id, COALESCE(product_id, 0), COALESCE(category_id, 0));
