-- =====================================================================
-- RT CRACKERS | 15_NOTIFICATIONS/001_Notifications.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- notifications | Purpose: a notification message (broadcast or targeted).
-- Keys : PK(notification_id)
-- Rel  : N:1 email_templates, N:1 admins; 1:N user_notifications
-- BCNF : attributes depend only on the message; per-recipient state is in user_notifications.
-- ---------------------------------------------------------------------
CREATE TABLE notifications (
    notification_id    BIGINT        GENERATED ALWAYS AS IDENTITY,
    template_id        INTEGER,
    title              VARCHAR(150)  NOT NULL,
    message            TEXT          NOT NULL,
    notification_type  CHAR(1)       NOT NULL DEFAULT 'S',     -- O order, P promotion, S system, F festival
    reference_type     VARCHAR(40),
    reference_id       VARCHAR(64),
    expires_at         TIMESTAMP,
    created_by         INTEGER,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_notifications PRIMARY KEY (notification_id),
    CONSTRAINT fk_notifications_template   FOREIGN KEY (template_id) REFERENCES email_templates (template_id) ON DELETE SET NULL,
    CONSTRAINT fk_notifications_created_by FOREIGN KEY (created_by)  REFERENCES admins (admin_id)             ON DELETE SET NULL,
    CONSTRAINT ck_notifications_type CHECK (notification_type IN ('O','P','S','F'))
);
