-- =====================================================================
-- RT CRACKERS | 17_ANALYTICS/005_User_activity_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- user_activity_logs | Purpose: generic customer activity trail (login, add to cart, checkout...).
-- Keys : PK(activity_id)
-- Rel  : N:1 users
-- BCNF : attributes describe one activity.
-- ---------------------------------------------------------------------
CREATE TABLE user_activity_logs (
    activity_id    BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id        BIGINT        NOT NULL,
    activity_type  VARCHAR(50)   NOT NULL,
    entity_type    VARCHAR(40),
    entity_id      VARCHAR(64),
    description    VARCHAR(255),
    metadata       JSONB,
    ip_address     INET,
    user_agent     VARCHAR(500),
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user_activity_logs PRIMARY KEY (activity_id),
    CONSTRAINT fk_user_activity_logs_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
