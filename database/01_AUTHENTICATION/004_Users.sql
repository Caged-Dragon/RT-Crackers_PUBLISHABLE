-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/004_Users.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- users | Purpose: every account (customer or staff login identity).
-- Keys : PK(user_id) | CK/AK: email, phone, referral_code
-- Rel  : self N:1 (referred_by); 1:1 user_profiles, admins; 1:N addresses, orders, reviews, carts...
-- BCNF : all attributes describe one account; contact/profile extras live in user_profiles.
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id               BIGINT        GENERATED ALWAYS AS IDENTITY,
    email                 VARCHAR(255)  NOT NULL,
    password_hash         VARCHAR(255)  NOT NULL,
    phone                 CHAR(10)      NOT NULL,
    first_name            VARCHAR(60)   NOT NULL,
    middle_name           VARCHAR(60),
    last_name             VARCHAR(60),
    gender                CHAR(1),                              -- M, F, O
    dob                   DATE,
    profile_image         VARCHAR(500),
    status                CHAR(1)       NOT NULL DEFAULT 'A',   -- A active, I inactive, S suspended, B blocked, D deleted
    email_verified        BOOLEAN       NOT NULL DEFAULT FALSE,
    phone_verified        BOOLEAN       NOT NULL DEFAULT FALSE,
    failed_login_count    SMALLINT      NOT NULL DEFAULT 0,
    account_locked        BOOLEAN       NOT NULL DEFAULT FALSE,
    last_login            TIMESTAMP,
    last_password_change  TIMESTAMP,
    preferred_language    CHAR(2)       NOT NULL DEFAULT 'en',
    preferred_currency    CHAR(3)       NOT NULL DEFAULT 'INR',
    referral_code         VARCHAR(12)   NOT NULL DEFAULT UPPER(SUBSTRING(MD5(RANDOM()::TEXT || CLOCK_TIMESTAMP()::TEXT) FROM 1 FOR 8)),
    referred_by           BIGINT,
    created_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_users PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email         UNIQUE (email),
    CONSTRAINT uq_users_phone         UNIQUE (phone),
    CONSTRAINT uq_users_referral_code UNIQUE (referral_code),
    CONSTRAINT fk_users_referred_by   FOREIGN KEY (referred_by) REFERENCES users (user_id) ON DELETE SET NULL,
    CONSTRAINT ck_users_email_format  CHECK (email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT ck_users_email_lower   CHECK (email = LOWER(email)),
    CONSTRAINT ck_users_phone_format  CHECK (phone ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_users_gender        CHECK (gender IS NULL OR gender IN ('M','F','O')),
    CONSTRAINT ck_users_status        CHECK (status IN ('A','I','S','B','D')),
    CONSTRAINT ck_users_failed_login  CHECK (failed_login_count >= 0),
    CONSTRAINT ck_users_dob_adult     CHECK (dob IS NULL OR dob <= CURRENT_DATE - INTERVAL '18 years'),  -- fireworks: buyers must be 18+
    CONSTRAINT ck_users_self_referral CHECK (referred_by IS NULL OR referred_by <> user_id)
);
