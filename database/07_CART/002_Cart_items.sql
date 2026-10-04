-- =====================================================================
-- RT CRACKERS | 07_CART/002_Cart_items.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- cart_items | Purpose: lines inside a cart.
-- Keys : PK(cart_item_id) | CK/AK: (cart_id, product_id, variant_id|0) via unique index
-- Rel  : N:1 carts, products, product_variants (composite FK)
-- BCNF : quantity depends on the candidate key (cart, item).
-- ---------------------------------------------------------------------
CREATE TABLE cart_items (
    cart_item_id  BIGINT     GENERATED ALWAYS AS IDENTITY,
    cart_id       BIGINT     NOT NULL,
    product_id    BIGINT     NOT NULL,
    variant_id    BIGINT,
    quantity      INTEGER    NOT NULL DEFAULT 1,
    created_at    TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cart_items PRIMARY KEY (cart_item_id),
    CONSTRAINT fk_cart_items_cart    FOREIGN KEY (cart_id)    REFERENCES carts (cart_id)         ON DELETE CASCADE,
    CONSTRAINT fk_cart_items_product FOREIGN KEY (product_id) REFERENCES products (product_id)   ON DELETE CASCADE,
    CONSTRAINT fk_cart_items_variant FOREIGN KEY (product_id, variant_id) REFERENCES product_variants (product_id, variant_id) ON DELETE CASCADE,
    CONSTRAINT ck_cart_items_quantity CHECK (quantity > 0 AND quantity <= 1000)
);
CREATE UNIQUE INDEX uq_cart_items_line ON cart_items (cart_id, product_id, COALESCE(variant_id, 0));
