-- =====================================================================
-- RT CRACKERS | 14_MARKETING/002_Coupon_usage.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- coupon_usage | Purpose: one row per order that redeemed a coupon.
-- Keys : PK(coupon_usage_id) | CK/AK: order_id
-- Rel  : composite FK (order_id, user_id, coupon_id) -> orders keeps user and coupon consistent with the order
-- BCNF : order_id is a candidate key, so order_id -> user_id, coupon_id is a key dependency.
-- ---------------------------------------------------------------------
CREATE TABLE coupon_usage (
    coupon_usage_id  BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id         BIGINT         NOT NULL,
    user_id          BIGINT         NOT NULL,
    coupon_id        INTEGER        NOT NULL,
    discount_applied NUMERIC(12,2)  NOT NULL,
    status           CHAR(1)        NOT NULL DEFAULT 'A',      -- A applied, R reversed (order cancelled)
    created_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_coupon_usage PRIMARY KEY (coupon_usage_id),
    CONSTRAINT uq_coupon_usage_order UNIQUE (order_id),
    CONSTRAINT fk_coupon_usage_order  FOREIGN KEY (order_id, user_id, coupon_id) REFERENCES orders (order_id, user_id, coupon_id) ON DELETE CASCADE,
    CONSTRAINT fk_coupon_usage_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (coupon_id) ON DELETE RESTRICT,
    CONSTRAINT ck_coupon_usage_discount CHECK (discount_applied >= 0),
    CONSTRAINT ck_coupon_usage_status   CHECK (status IN ('A','R'))
);
