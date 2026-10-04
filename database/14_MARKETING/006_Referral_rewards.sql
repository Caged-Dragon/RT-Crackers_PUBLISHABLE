-- =====================================================================
-- RT CRACKERS | 14_MARKETING/006_Referral_rewards.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- referral_rewards | Purpose: rewards for both sides of a referral. The referrer is users.referred_by of the referred user.
-- Keys : PK(referral_reward_id) | CK/AK: (referred_user_id, beneficiary_role)
-- Rel  : N:1 users (referred), N:1 orders (qualifying order), N:1 coupons (reward coupon)
-- BCNF : beneficiary is derived from role + referred user, so no duplicate referrer column is stored.
-- ---------------------------------------------------------------------
CREATE TABLE referral_rewards (
    referral_reward_id   BIGINT         GENERATED ALWAYS AS IDENTITY,
    referred_user_id     BIGINT         NOT NULL,
    beneficiary_role     CHAR(1)        NOT NULL,              -- R referrer, E referee (the referred user)
    qualifying_order_id  BIGINT,
    reward_amount        NUMERIC(12,2)  NOT NULL,
    coupon_id            INTEGER,
    status               CHAR(1)        NOT NULL DEFAULT 'P',  -- P pending, G granted, X expired
    granted_at           TIMESTAMP,
    expires_at           TIMESTAMP,
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_referral_rewards PRIMARY KEY (referral_reward_id),
    CONSTRAINT uq_referral_rewards_user_role UNIQUE (referred_user_id, beneficiary_role),
    CONSTRAINT fk_referral_rewards_user   FOREIGN KEY (referred_user_id)    REFERENCES users (user_id)     ON DELETE CASCADE,
    CONSTRAINT fk_referral_rewards_order  FOREIGN KEY (qualifying_order_id) REFERENCES orders (order_id)   ON DELETE SET NULL,
    CONSTRAINT fk_referral_rewards_coupon FOREIGN KEY (coupon_id)           REFERENCES coupons (coupon_id) ON DELETE SET NULL,
    CONSTRAINT ck_referral_rewards_role   CHECK (beneficiary_role IN ('R','E')),
    CONSTRAINT ck_referral_rewards_amount CHECK (reward_amount > 0),
    CONSTRAINT ck_referral_rewards_status CHECK (status IN ('P','G','X')),
    CONSTRAINT ck_referral_rewards_granted CHECK ((status = 'G') = (granted_at IS NOT NULL))
);
