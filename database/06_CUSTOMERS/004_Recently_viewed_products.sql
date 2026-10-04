-- =====================================================================
-- RT CRACKERS | 06_CUSTOMERS/004_Recently_viewed_products.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- recently_viewed_products | Purpose: per-user browsing shortcuts.
-- Keys : COMPOSITE PK(user_id, product_id)
-- Rel  : N:1 users, N:1 products
-- BCNF : last_viewed_at/view_count depend on the whole key.
-- ---------------------------------------------------------------------
CREATE TABLE recently_viewed_products (
    user_id         BIGINT     NOT NULL,
    product_id      BIGINT     NOT NULL,
    view_count      INTEGER    NOT NULL DEFAULT 1,
    last_viewed_at  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_recently_viewed_products PRIMARY KEY (user_id, product_id),
    CONSTRAINT fk_recently_viewed_user    FOREIGN KEY (user_id)    REFERENCES users (user_id)       ON DELETE CASCADE,
    CONSTRAINT fk_recently_viewed_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT ck_recently_viewed_count CHECK (view_count > 0)
);
