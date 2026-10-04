-- =====================================================================
-- RT CRACKERS | 14_MARKETING/001_Coupons.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- coupons | Purpose: discount codes (percentage or flat).
-- Keys : PK(coupon_id) | CK/AK: coupon_code
-- Rel  : 1:N carts, orders, coupon_usage, referral_rewards
-- BCNF : rule attributes depend only on the coupon. Usage counts are derived from coupon_usage, not stored.
-- ---------------------------------------------------------------------
CREATE TABLE coupons (
    coupon_id             INTEGER        GENERATED ALWAYS AS IDENTITY,
    coupon_code           VARCHAR(30)    NOT NULL,
    description           VARCHAR(255),
    discount_type         CHAR(1)        NOT NULL,                 -- P percentage, F flat amount
    discount_percentage   NUMERIC(5,2),
    discount_amount       NUMERIC(12,2),
    max_discount_amount   NUMERIC(12,2),
    min_order_amount      NUMERIC(12,2)  NOT NULL DEFAULT 0,
    usage_limit           INTEGER,
    usage_limit_per_user  SMALLINT       NOT NULL DEFAULT 1,
    valid_from            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_until           TIMESTAMP      NOT NULL,
    first_order_only      BOOLEAN        NOT NULL DEFAULT FALSE,
    is_active             BOOLEAN        NOT NULL DEFAULT TRUE,
    created_by            INTEGER,
    created_at            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_coupons PRIMARY KEY (coupon_id),
    CONSTRAINT uq_coupons_coupon_code UNIQUE (coupon_code),
    CONSTRAINT fk_coupons_created_by FOREIGN KEY (created_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_coupons_code_upper    CHECK (coupon_code = UPPER(coupon_code)),
    CONSTRAINT ck_coupons_discount_pct  CHECK (discount_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_coupons_type_shape    CHECK ((discount_type = 'P' AND discount_percentage IS NOT NULL AND discount_amount IS NULL)
                                            OR (discount_type = 'F' AND discount_amount IS NOT NULL AND discount_percentage IS NULL)),
    CONSTRAINT ck_coupons_amounts       CHECK ((discount_amount IS NULL OR discount_amount > 0)
                                           AND (max_discount_amount IS NULL OR max_discount_amount > 0)
                                           AND min_order_amount >= 0),
    CONSTRAINT ck_coupons_limits        CHECK ((usage_limit IS NULL OR usage_limit > 0) AND usage_limit_per_user > 0),
    CONSTRAINT ck_coupons_validity      CHECK (valid_until > valid_from)
);
