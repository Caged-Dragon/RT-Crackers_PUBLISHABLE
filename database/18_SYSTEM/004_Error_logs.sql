-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/004_Error_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- error_logs | Purpose: application/database errors for triage.
-- Keys : PK(error_log_id)
-- Rel  : N:1 users (optional), N:1 admins (resolver)
-- BCNF : attributes describe one error event.
-- ---------------------------------------------------------------------
CREATE TABLE error_logs (
    error_log_id    BIGINT         GENERATED ALWAYS AS IDENTITY,
    error_level     CHAR(1)        NOT NULL DEFAULT 'E',      -- W warning, E error, F fatal
    error_code      VARCHAR(40),
    error_message   TEXT           NOT NULL,
    stack_trace     TEXT,
    source          VARCHAR(100),
    request_url     VARCHAR(500),
    request_method  VARCHAR(10),
    user_id         BIGINT,
    ip_address      INET,
    context         JSONB,
    is_resolved     BOOLEAN        NOT NULL DEFAULT FALSE,
    resolved_by     INTEGER,
    resolved_at     TIMESTAMP,
    created_at      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_error_logs PRIMARY KEY (error_log_id),
    CONSTRAINT fk_error_logs_user     FOREIGN KEY (user_id)     REFERENCES users (user_id)   ON DELETE SET NULL,
    CONSTRAINT fk_error_logs_resolver FOREIGN KEY (resolved_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_error_logs_level    CHECK (error_level IN ('W','E','F')),
    CONSTRAINT ck_error_logs_resolved CHECK (is_resolved = (resolved_at IS NOT NULL))
);
