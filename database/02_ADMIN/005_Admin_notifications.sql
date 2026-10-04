-- =====================================================================
-- RT CRACKERS | 02_ADMIN/005_Admin_notifications.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- admin_notifications | Purpose: in-dashboard alerts for staff (low stock, new COD order...).
-- Keys : PK(admin_notification_id)
-- Rel  : N:1 admins
-- BCNF : attributes describe one alert.
-- ---------------------------------------------------------------------
CREATE TABLE admin_notifications (
    admin_notification_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    admin_id               INTEGER       NOT NULL,
    title                  VARCHAR(150)  NOT NULL,
    message                TEXT          NOT NULL,
    severity               CHAR(1)       NOT NULL DEFAULT 'I',  -- I info, W warning, C critical
    reference_type         VARCHAR(40),
    reference_id           VARCHAR(64),
    is_read                BOOLEAN       NOT NULL DEFAULT FALSE,
    read_at                TIMESTAMP,
    created_at             TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_admin_notifications PRIMARY KEY (admin_notification_id),
    CONSTRAINT fk_admin_notifications_admin FOREIGN KEY (admin_id) REFERENCES admins (admin_id) ON DELETE CASCADE,
    CONSTRAINT ck_admin_notifications_severity CHECK (severity IN ('I','W','C')),
    CONSTRAINT ck_admin_notifications_read     CHECK (is_read = (read_at IS NOT NULL))
);
