-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/006_U05_User_security.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U5 User security enhancements
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 5 - USER SECURITY ENHANCEMENTS
-- failed_login_count, account_locked, last_password_change already existed.
-- mfa_secret and security_answer_hash must be stored encrypted/hashed by the application.
-- =====================================================================
ALTER TABLE users
    ADD COLUMN last_failed_login      TIMESTAMP,
    ADD COLUMN account_locked_until   TIMESTAMP,
    ADD COLUMN password_expiry_date   DATE,
    ADD COLUMN last_login_ip          INET,
    ADD COLUMN last_device            VARCHAR(255),
    ADD COLUMN security_question      VARCHAR(255),
    ADD COLUMN security_answer_hash   VARCHAR(255),
    ADD COLUMN mfa_enabled            BOOLEAN       NOT NULL DEFAULT FALSE,
    ADD COLUMN mfa_secret             VARCHAR(255);

ALTER TABLE users
    ADD CONSTRAINT ck_users_security_qa    CHECK ((security_question IS NULL) = (security_answer_hash IS NULL)),
    ADD CONSTRAINT ck_users_mfa_secret     CHECK (NOT mfa_enabled OR mfa_secret IS NOT NULL),
    ADD CONSTRAINT ck_users_lock_until     CHECK (account_locked_until IS NULL OR account_locked),
    ADD CONSTRAINT ck_users_password_expiry CHECK (password_expiry_date IS NULL OR last_password_change IS NULL
                                                   OR password_expiry_date >= last_password_change::DATE);

-- Brute-force protection: lock after N failures (system_configurations 'security.max_failed_logins',
-- default 5) for M minutes ('security.lockout_minutes', default 30). Unlocking resets the counter.
CREATE OR REPLACE FUNCTION fn_users_security()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_max     INTEGER;
    v_minutes INTEGER;
BEGIN
    IF OLD.account_locked AND NOT NEW.account_locked THEN
        NEW.failed_login_count  := 0;
        NEW.account_locked_until := NULL;
        RETURN NEW;
    END IF;
    IF NEW.failed_login_count > OLD.failed_login_count THEN
        NEW.last_failed_login := CURRENT_TIMESTAMP;
        SELECT COALESCE(MAX(config_value::INTEGER) FILTER (WHERE config_key = 'security.max_failed_logins'), 5),
               COALESCE(MAX(config_value::INTEGER) FILTER (WHERE config_key = 'security.lockout_minutes'), 30)
          INTO v_max, v_minutes
          FROM system_configurations
         WHERE is_active AND config_key IN ('security.max_failed_logins', 'security.lockout_minutes');
        IF NEW.failed_login_count >= v_max AND NOT NEW.account_locked THEN
            NEW.account_locked := TRUE;
            NEW.account_locked_until := CURRENT_TIMESTAMP + make_interval(mins => v_minutes);
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_users_security BEFORE UPDATE OF failed_login_count, account_locked ON users
    FOR EACH ROW EXECUTE FUNCTION fn_users_security();

