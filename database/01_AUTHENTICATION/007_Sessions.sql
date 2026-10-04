-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/007_Sessions.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- sessions | Purpose: server-side login sessions (one per device login).
-- Keys : PK(session_id UUID)
-- Rel  : N:1 users; 1:N refresh_tokens, login_history
-- BCNF : all columns describe the session itself.
-- ---------------------------------------------------------------------
CREATE TABLE sessions (
    session_id        UUID         NOT NULL DEFAULT gen_random_uuid(),
    user_id           BIGINT       NOT NULL,
    ip_address        INET,
    user_agent        VARCHAR(500),
    device_type       CHAR(1)      NOT NULL DEFAULT 'W',     -- W web, M mobile, T tablet, O other
    last_activity_at  TIMESTAMP,
    expires_at        TIMESTAMP    NOT NULL,
    ended_at          TIMESTAMP,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_sessions PRIMARY KEY (session_id),
    CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_sessions_device_type CHECK (device_type IN ('W','M','T','O')),
    CONSTRAINT ck_sessions_expiry      CHECK (expires_at > created_at)
);
