-- RT CRACKERS | 21_UPGRADE_V3/017_U37_System_Health_Monitoring.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 37 - SYSTEM HEALTH MONITORING
-- fn_record_system_health() stores one reading. The database knows its own size and the number of
-- open login sessions; CPU and memory come from the platform, so your scheduler passes them in:
--   SELECT fn_record_system_health(37.5, 61.2);
-- Warning / critical thresholds are business rules (health.* in business_rules).
-- =====================================================================
CREATE TABLE system_health_checks (
    health_check_id      BIGINT        GENERATED ALWAYS AS IDENTITY,
    checked_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cpu_usage            NUMERIC(5,2),
    memory_usage         NUMERIC(5,2),
    database_size_bytes  BIGINT        NOT NULL,
    active_sessions      INTEGER       NOT NULL,
    db_connections       INTEGER,
    health_status        CHAR(1)       NOT NULL DEFAULT 'H',      -- H healthy, W warning, C critical
    source               VARCHAR(40)   NOT NULL DEFAULT 'database',
    notes                VARCHAR(255),
    CONSTRAINT pk_system_health_checks PRIMARY KEY (health_check_id),
    CONSTRAINT ck_system_health_checks_cpu      CHECK (cpu_usage    IS NULL OR cpu_usage    BETWEEN 0 AND 100),
    CONSTRAINT ck_system_health_checks_memory   CHECK (memory_usage IS NULL OR memory_usage BETWEEN 0 AND 100),
    CONSTRAINT ck_system_health_checks_size     CHECK (database_size_bytes >= 0),
    CONSTRAINT ck_system_health_checks_sessions CHECK (active_sessions >= 0 AND (db_connections IS NULL OR db_connections >= 0)),
    CONSTRAINT ck_system_health_checks_status   CHECK (health_status IN ('H','W','C'))
);
CREATE INDEX idx_system_health_checks_time ON system_health_checks (checked_at DESC);

CREATE OR REPLACE FUNCTION fn_record_system_health(p_cpu NUMERIC DEFAULT NULL, p_memory NUMERIC DEFAULT NULL, p_source TEXT DEFAULT 'database')
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_status  CHAR(1) := 'H';
    v_id      BIGINT;
BEGIN
    IF p_cpu    >= COALESCE(fn_rule_number('health.cpu_critical_percent'),    101)
    OR p_memory >= COALESCE(fn_rule_number('health.memory_critical_percent'), 101) THEN
        v_status := 'C';
    ELSIF p_cpu    >= COALESCE(fn_rule_number('health.cpu_warning_percent'),    101)
       OR p_memory >= COALESCE(fn_rule_number('health.memory_warning_percent'), 101) THEN
        v_status := 'W';
    END IF;
    INSERT INTO system_health_checks (cpu_usage, memory_usage, database_size_bytes, active_sessions, db_connections, health_status, source)
    VALUES (p_cpu, p_memory, pg_database_size(current_database()),
            (SELECT COUNT(*) FROM sessions WHERE ended_at IS NULL AND expires_at > CURRENT_TIMESTAMP),
            (SELECT COUNT(*) FROM pg_stat_activity WHERE datname = current_database()),
            v_status, LEFT(p_source, 40))
    RETURNING health_check_id INTO v_id;
    RETURN v_id;
END;
$$;
