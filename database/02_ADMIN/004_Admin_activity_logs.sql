-- =====================================================================
-- RT CRACKERS | 02_ADMIN/004_Admin_activity_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- admin_activity_logs | Purpose: append-only trail of admin actions.
-- Keys : PK(log_id)
-- Rel  : N:1 admins
-- BCNF : attributes describe one action.
-- ---------------------------------------------------------------------
CREATE TABLE admin_activity_logs (
    log_id       BIGINT        GENERATED ALWAYS AS IDENTITY,
    admin_id     INTEGER       NOT NULL,
    action       VARCHAR(100)  NOT NULL,
    module_name  VARCHAR(40),
    entity_type  VARCHAR(40),
    entity_id    VARCHAR(64),
    details      JSONB,
    ip_address   INET,
    user_agent   VARCHAR(500),
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_admin_activity_logs PRIMARY KEY (log_id),
    CONSTRAINT fk_admin_activity_logs_admin FOREIGN KEY (admin_id) REFERENCES admins (admin_id) ON DELETE RESTRICT
);
