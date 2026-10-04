-- =====================================================================
-- RT CRACKERS | 09_COMPARISON/002_Comparison_items.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- comparison_items | Purpose: products inside a comparison (max 4 slots).
-- Keys : COMPOSITE PK(comparison_id, product_id) | AK: (comparison_id, slot_no)
-- Rel  : N:1 comparisons, N:1 products
-- BCNF : slot_no determined by the key and is itself unique per comparison (candidate key).
-- ---------------------------------------------------------------------
CREATE TABLE comparison_items (
    comparison_id  BIGINT     NOT NULL,
    product_id     BIGINT     NOT NULL,
    slot_no        SMALLINT   NOT NULL,
    created_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_comparison_items PRIMARY KEY (comparison_id, product_id),
    CONSTRAINT uq_comparison_items_slot UNIQUE (comparison_id, slot_no),
    CONSTRAINT fk_comparison_items_comparison FOREIGN KEY (comparison_id) REFERENCES comparisons (comparison_id) ON DELETE CASCADE,
    CONSTRAINT fk_comparison_items_product    FOREIGN KEY (product_id)    REFERENCES products (product_id)       ON DELETE CASCADE,
    CONSTRAINT ck_comparison_items_slot CHECK (slot_no BETWEEN 1 AND 4)
);
