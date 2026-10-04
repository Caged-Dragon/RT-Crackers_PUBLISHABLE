-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/005_User_profiles.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- user_profiles | Purpose: optional 1:1 profile/consent extras kept out of users.
-- Keys : PK(user_id) which is also FK
-- Rel  : 1:1 users
-- BCNF : sole determinant is user_id (the key).
-- ---------------------------------------------------------------------
CREATE TABLE user_profiles (
    user_id             BIGINT       NOT NULL,
    display_name        VARCHAR(100),
    bio                 TEXT,
    alternate_phone     CHAR(10),
    whatsapp_number     CHAR(10),
    occupation          VARCHAR(80),
    timezone            VARCHAR(50)  NOT NULL DEFAULT 'Asia/Kolkata',
    age_verified        BOOLEAN      NOT NULL DEFAULT FALSE,
    age_verified_at     TIMESTAMP,
    email_opt_in        BOOLEAN      NOT NULL DEFAULT TRUE,
    sms_opt_in          BOOLEAN      NOT NULL DEFAULT TRUE,
    whatsapp_opt_in     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user_profiles PRIMARY KEY (user_id),
    CONSTRAINT fk_user_profiles_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_user_profiles_alt_phone CHECK (alternate_phone IS NULL OR alternate_phone ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_user_profiles_whatsapp  CHECK (whatsapp_number IS NULL OR whatsapp_number ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_user_profiles_age_verified CHECK (age_verified = (age_verified_at IS NOT NULL))
);
