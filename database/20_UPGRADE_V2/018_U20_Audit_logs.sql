-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/018_U20_Audit_logs.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U20 Audit logging
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 20 - AUDIT LOGGING
-- =====================================================================
ALTER TABLE audit_logs RENAME COLUMN audit_log_id TO audit_id;
ALTER TABLE audit_logs RENAME COLUMN action       TO action_type;
ALTER TABLE audit_logs RENAME COLUMN old_data     TO old_value;
ALTER TABLE audit_logs RENAME COLUMN new_data     TO new_value;
ALTER TABLE audit_logs RENAME COLUMN created_at   TO changed_at;

ALTER TABLE audit_logs DROP CONSTRAINT ck_audit_logs_action;
ALTER TABLE audit_logs ALTER COLUMN action_type TYPE VARCHAR(10)
    USING CASE action_type WHEN 'I' THEN 'INSERT' WHEN 'U' THEN 'UPDATE' WHEN 'D' THEN 'DELETE' END;
ALTER TABLE audit_logs
    ADD COLUMN ip_address  INET,
    ADD COLUMN user_agent  VARCHAR(500),
    ADD CONSTRAINT ck_audit_logs_action_type CHECK (action_type IN ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT'));
CREATE INDEX idx_audit_logs_time   ON audit_logs (changed_at DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs (action_type, changed_at DESC) WHERE action_type IN ('LOGIN','LOGOUT');

-- Row audit: arg 0 = primary-key column; further args = JSON keys to strip (secrets).
-- Session settings read when present: app.current_user_id, app.client_ip, app.user_agent.
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk     TEXT   := TG_ARGV[0];
    v_redact TEXT[] := CASE WHEN TG_NARGS > 1 THEN TG_ARGV[1:TG_NARGS - 1] ELSE ARRAY[]::TEXT[] END;
    v_old    JSONB;
    v_new    JSONB;
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN v_old := to_jsonb(OLD) - v_redact; END IF;
    IF TG_OP IN ('INSERT','UPDATE') THEN v_new := to_jsonb(NEW) - v_redact; END IF;
    INSERT INTO audit_logs (table_name, record_id, action_type, old_value, new_value, changed_by, ip_address, user_agent)
    VALUES (TG_TABLE_NAME, COALESCE(v_new ->> v_pk, v_old ->> v_pk), TG_OP, v_old, v_new,
            NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT,
            NULLIF(current_setting('app.client_ip', TRUE), '')::INET,
            LEFT(NULLIF(current_setting('app.user_agent', TRUE), ''), 500));
    RETURN NULL;
END;
$$;

-- more tables under audit (users: secrets stripped, login bookkeeping columns excluded)
CREATE TRIGGER trg_users_audit AFTER INSERT OR DELETE OR UPDATE OF email, phone, first_name, middle_name, last_name,
        status, email_verified, phone_verified, account_locked, account_locked_until, password_hash, mfa_enabled,
        mfa_secret, security_answer_hash, referred_by, is_deleted ON users
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log('user_id', 'password_hash', 'security_answer_hash', 'mfa_secret');
CREATE TRIGGER trg_categories_audit            AFTER INSERT OR UPDATE OR DELETE ON categories            FOR EACH ROW EXECUTE FUNCTION fn_audit_log('category_id');
CREATE TRIGGER trg_subcategories_audit         AFTER INSERT OR UPDATE OR DELETE ON subcategories         FOR EACH ROW EXECUTE FUNCTION fn_audit_log('subcategory_id');
CREATE TRIGGER trg_brands_audit                AFTER INSERT OR UPDATE OR DELETE ON brands                FOR EACH ROW EXECUTE FUNCTION fn_audit_log('brand_id');
CREATE TRIGGER trg_reviews_audit               AFTER INSERT OR UPDATE OR DELETE ON reviews               FOR EACH ROW EXECUTE FUNCTION fn_audit_log('review_id');
CREATE TRIGGER trg_system_configurations_audit AFTER INSERT OR UPDATE OR DELETE ON system_configurations FOR EACH ROW EXECUTE FUNCTION fn_audit_log('config_id');
CREATE TRIGGER trg_feature_flags_audit         AFTER INSERT OR UPDATE OR DELETE ON feature_flags         FOR EACH ROW EXECUTE FUNCTION fn_audit_log('feature_id');

-- LOGIN: a successful login_history row writes a LOGIN audit entry and refreshes users.last_login_ip /
-- last_device; a failed one refreshes users.last_failed_login. (Counting failures stays with the app.)
CREATE OR REPLACE FUNCTION fn_login_history_effects()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.user_id IS NULL THEN RETURN NULL; END IF;
    IF NEW.login_status = 'S' THEN
        UPDATE users SET last_login_ip = NEW.ip_address, last_device = LEFT(NEW.user_agent, 255)
         WHERE user_id = NEW.user_id;
        INSERT INTO audit_logs (table_name, record_id, action_type, new_value, changed_by, ip_address, user_agent)
        VALUES ('users', NEW.user_id::TEXT, 'LOGIN', jsonb_build_object('session_id', NEW.session_id),
                NEW.user_id, NEW.ip_address, NEW.user_agent);
    ELSIF NEW.login_status = 'F' THEN
        UPDATE users SET last_failed_login = NEW.created_at WHERE user_id = NEW.user_id;
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_login_history_effects AFTER INSERT ON login_history
    FOR EACH ROW EXECUTE FUNCTION fn_login_history_effects();

-- LOGOUT: a session getting its ended_at stamped.
CREATE OR REPLACE FUNCTION fn_session_logout_audit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_logs (table_name, record_id, action_type, new_value, changed_by, ip_address, user_agent)
    VALUES ('users', NEW.user_id::TEXT, 'LOGOUT', jsonb_build_object('session_id', NEW.session_id),
            NEW.user_id, NEW.ip_address, NEW.user_agent);
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_sessions_logout_audit AFTER UPDATE OF ended_at ON sessions
    FOR EACH ROW WHEN (OLD.ended_at IS NULL AND NEW.ended_at IS NOT NULL)
    EXECUTE FUNCTION fn_session_logout_audit();

