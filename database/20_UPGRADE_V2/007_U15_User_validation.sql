-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/007_U15_User_validation.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U15 User validation rules
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 15 - USER VALIDATION RULES (U14 and U16 are verified in section 21)
-- phone format/uniqueness, email format already existed.
-- last_name stays optional (single-name users); when present it cannot be blank.
-- =====================================================================
UPDATE users SET last_name = NULL WHERE last_name IS NOT NULL AND BTRIM(last_name) = '';
ALTER TABLE users
    ADD CONSTRAINT ck_users_phone_length     CHECK (LENGTH(phone) = 10),
    ADD CONSTRAINT ck_users_email_not_empty  CHECK (BTRIM(email) <> ''),
    ADD CONSTRAINT ck_users_first_name_not_empty CHECK (BTRIM(first_name) <> ''),
    ADD CONSTRAINT ck_users_last_name_not_empty  CHECK (last_name IS NULL OR BTRIM(last_name) <> '');

