-- RT CRACKERS | 21_UPGRADE_V3/015_U33_Security_Audit_Enhancement.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 33 - SECURITY AUDIT ENHANCEMENT
-- audit_logs gets session, device, browser, operating system, country and city.
-- Filled automatically from the same session settings the audit trigger already reads:
--   SET LOCAL app.session_id = '<uuid>';  app.device_type = 'W|M|T|O';  app.browser;  app.os;
--   app.country;  app.city      (plus the existing app.current_user_id / app.client_ip / app.user_agent)
-- When app.browser / app.os / app.device_type are missing they are worked out from app.user_agent.
-- country / city need a geo-IP lookup in your application: the database cannot guess them.
-- session_id has no foreign key on purpose: audit rows must survive session clean-up.
-- =====================================================================
ALTER TABLE audit_logs
    ADD COLUMN session_id        UUID,
    ADD COLUMN device_type       CHAR(1),
    ADD COLUMN browser           VARCHAR(60),
    ADD COLUMN operating_system  VARCHAR(60),
    ADD COLUMN country           VARCHAR(80),
    ADD COLUMN city              VARCHAR(100),
    ADD CONSTRAINT ck_audit_logs_device_type CHECK (device_type IS NULL OR device_type IN ('W','M','T','O'));
CREATE INDEX idx_audit_logs_session ON audit_logs (session_id) WHERE session_id IS NOT NULL;

CREATE OR REPLACE FUNCTION fn_ua_browser(p_ua TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN p_ua IS NULL OR BTRIM(p_ua) = '' THEN NULL
                WHEN p_ua ~* 'Edg(e|A|iOS)?/'                    THEN 'Edge'
                WHEN p_ua ~* 'OPR/|Opera'                        THEN 'Opera'
                WHEN p_ua ~* 'SamsungBrowser'                    THEN 'Samsung Internet'
                WHEN p_ua ~* 'Firefox/|FxiOS'                    THEN 'Firefox'
                WHEN p_ua ~* 'Chrome/|CriOS'                     THEN 'Chrome'
                WHEN p_ua ~* 'Safari/'                           THEN 'Safari'
                WHEN p_ua ~* 'curl|wget|postman|python|okhttp|axios|node-fetch|insomnia' THEN 'API client'
                ELSE 'Other' END
$$;

CREATE OR REPLACE FUNCTION fn_ua_os(p_ua TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN p_ua IS NULL OR BTRIM(p_ua) = '' THEN NULL
                WHEN p_ua ~* 'Windows'                          THEN 'Windows'
                WHEN p_ua ~* 'Android'                          THEN 'Android'
                WHEN p_ua ~* 'iPhone|iPad|iPod'                 THEN 'iOS'
                WHEN p_ua ~* 'Mac OS X|Macintosh'               THEN 'macOS'
                WHEN p_ua ~* 'CrOS'                             THEN 'ChromeOS'
                WHEN p_ua ~* 'Linux|X11'                        THEN 'Linux'
                ELSE 'Other' END
$$;

CREATE OR REPLACE FUNCTION fn_ua_device_type(p_ua TEXT)
RETURNS CHAR(1) LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE WHEN p_ua IS NULL OR BTRIM(p_ua) = '' THEN NULL
                WHEN p_ua ~* 'iPad|Tablet'                      THEN 'T'
                WHEN p_ua ~* 'Android' AND p_ua !~* 'Mobile'    THEN 'T'
                WHEN p_ua ~* 'Mobi|iPhone|Android'              THEN 'M'
                WHEN p_ua ~* 'bot|crawler|spider|curl|wget|postman|python|okhttp' THEN 'O'
                ELSE 'W' END
$$;

-- same behaviour as v2 (arg 0 = primary key column, further args = JSON keys to strip) plus the new context columns
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk      TEXT   := TG_ARGV[0];
    v_redact  TEXT[] := CASE WHEN TG_NARGS > 1 THEN TG_ARGV[1:TG_NARGS - 1] ELSE ARRAY[]::TEXT[] END;
    v_old     JSONB;
    v_new     JSONB;
    v_ua      TEXT   := LEFT(NULLIF(current_setting('app.user_agent', TRUE), ''), 500);
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN v_old := to_jsonb(OLD) - v_redact; END IF;
    IF TG_OP IN ('INSERT','UPDATE') THEN v_new := to_jsonb(NEW) - v_redact; END IF;
    INSERT INTO audit_logs (table_name, record_id, action_type, old_value, new_value, changed_by, ip_address, user_agent,
                            session_id, device_type, browser, operating_system, country, city)
    VALUES (TG_TABLE_NAME, COALESCE(v_new ->> v_pk, v_old ->> v_pk), TG_OP, v_old, v_new,
            NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT,
            NULLIF(current_setting('app.client_ip', TRUE), '')::INET,
            v_ua,
            NULLIF(current_setting('app.session_id', TRUE), '')::UUID,
            COALESCE(NULLIF(current_setting('app.device_type', TRUE), ''), fn_ua_device_type(v_ua)),
            COALESCE(NULLIF(current_setting('app.browser', TRUE), ''),     fn_ua_browser(v_ua)),
            COALESCE(NULLIF(current_setting('app.os', TRUE), ''),          fn_ua_os(v_ua)),
            NULLIF(current_setting('app.country', TRUE), ''),
            NULLIF(current_setting('app.city', TRUE), ''));
    RETURN NULL;
END;
$$;

-- LOGIN entries now carry the session and the device details
CREATE OR REPLACE FUNCTION fn_login_history_effects()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_device CHAR(1);
BEGIN
    IF NEW.user_id IS NULL THEN RETURN NULL; END IF;
    IF NEW.login_status = 'S' THEN
        UPDATE users SET last_login_ip = NEW.ip_address, last_device = LEFT(NEW.user_agent, 255)
         WHERE user_id = NEW.user_id;
        SELECT s.device_type INTO v_device FROM sessions s WHERE s.session_id = NEW.session_id;
        INSERT INTO audit_logs (table_name, record_id, action_type, new_value, changed_by, ip_address, user_agent,
                                session_id, device_type, browser, operating_system, country, city)
        VALUES ('users', NEW.user_id::TEXT, 'LOGIN', jsonb_build_object('session_id', NEW.session_id),
                NEW.user_id, NEW.ip_address, NEW.user_agent,
                NEW.session_id,
                COALESCE(v_device, fn_ua_device_type(NEW.user_agent)),
                fn_ua_browser(NEW.user_agent), fn_ua_os(NEW.user_agent),
                NULLIF(current_setting('app.country', TRUE), ''), NULLIF(current_setting('app.city', TRUE), ''));
    ELSIF NEW.login_status = 'F' THEN
        UPDATE users SET last_failed_login = NEW.created_at WHERE user_id = NEW.user_id;
    END IF;
    RETURN NULL;
END;
$$;

-- LOGOUT entries too
CREATE OR REPLACE FUNCTION fn_session_logout_audit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_logs (table_name, record_id, action_type, new_value, changed_by, ip_address, user_agent,
                            session_id, device_type, browser, operating_system, country, city)
    VALUES ('users', NEW.user_id::TEXT, 'LOGOUT', jsonb_build_object('session_id', NEW.session_id),
            NEW.user_id, NEW.ip_address, NEW.user_agent,
            NEW.session_id, NEW.device_type, fn_ua_browser(NEW.user_agent), fn_ua_os(NEW.user_agent),
            NULLIF(current_setting('app.country', TRUE), ''), NULLIF(current_setting('app.city', TRUE), ''));
    RETURN NULL;
END;
$$;
