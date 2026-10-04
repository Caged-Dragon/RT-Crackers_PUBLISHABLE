-- =====================================================================
-- RT CRACKERS | 07_CART/001_Carts.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- carts | Purpose: a user's shopping cart; at most one active cart per user.
-- Keys : PK(cart_id)
-- Rel  : N:1 users, N:1 coupons; 1:N cart_items
-- BCNF : attributes depend on the cart. Prices are NOT stored: they come from products at checkout.
-- ---------------------------------------------------------------------
CREATE TABLE carts (
    cart_id     BIGINT     GENERATED ALWAYS AS IDENTITY,
    user_id     BIGINT     NOT NULL,
    coupon_id   INTEGER,
    status      CHAR(1)    NOT NULL DEFAULT 'A',               -- A active, C converted to order, X abandoned
    created_at  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_carts PRIMARY KEY (cart_id),
    CONSTRAINT fk_carts_user   FOREIGN KEY (user_id)   REFERENCES users (user_id)     ON DELETE CASCADE,
    CONSTRAINT fk_carts_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (coupon_id) ON DELETE SET NULL,
    CONSTRAINT ck_carts_status CHECK (status IN ('A','C','X'))
);
CREATE UNIQUE INDEX uq_carts_one_active_per_user ON carts (user_id) WHERE status = 'A';
