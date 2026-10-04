-- =====================================================================
-- RT CRACKERS | 08_WISHLIST/002_Wishlist_items.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- wishlist_items | Purpose: products saved in a wishlist.
-- Keys : COMPOSITE PK(wishlist_id, product_id)
-- Rel  : N:1 wishlists, N:1 products
-- BCNF : no non-key determinants.
-- ---------------------------------------------------------------------
CREATE TABLE wishlist_items (
    wishlist_id  BIGINT     NOT NULL,
    product_id   BIGINT     NOT NULL,
    created_at   TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_wishlist_items PRIMARY KEY (wishlist_id, product_id),
    CONSTRAINT fk_wishlist_items_wishlist FOREIGN KEY (wishlist_id) REFERENCES wishlists (wishlist_id) ON DELETE CASCADE,
    CONSTRAINT fk_wishlist_items_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)   ON DELETE CASCADE
);
