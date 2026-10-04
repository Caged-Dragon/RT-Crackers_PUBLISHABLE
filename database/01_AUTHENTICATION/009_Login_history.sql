-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/009_Login_history.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- login_history | Purpose: append-only audit of every login attempt.
-- Keys : PK(login_id)
-- Rel  : N:1 users (null for unknown e-mail), N:1 sessions
-- BCNF : attributes describe the single attempt.
-- ---------------------------------------------------------------------
CREATE TABLE login_history (
    login_id         BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id          BIGINT,
    attempted_email  VARCHAR(255)  NOT NULL,
    login_status     CHAR(1)       NOT NULL,                   -- S success, F failed, L blocked by lock
    failure_reason   VARCHAR(100),
    ip_address       INET,
    user_agent       VARCHAR(500),
    session_id       UUID,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_login_history PRIMARY KEY (login_id),
    CONSTRAINT fk_login_history_user    FOREIGN KEY (user_id)    REFERENCES users (user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_login_history_session FOREIGN KEY (session_id) REFERENCES sessions (session_id) ON DELETE SET NULL,
    CONSTRAINT ck_login_history_status  CHECK (login_status IN ('S','F','L'))
);
