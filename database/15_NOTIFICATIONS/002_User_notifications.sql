-- =====================================================================
-- RT CRACKERS | 15_NOTIFICATIONS/002_User_notifications.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- user_notifications | Purpose: delivery + read state of a notification for one user per channel.
-- Keys : PK(user_notification_id) | CK/AK: (notification_id, user_id, channel)
-- Rel  : N:1 notifications, N:1 users
-- BCNF : status/read state depend on the (notification, user, channel) candidate key.
-- ---------------------------------------------------------------------
CREATE TABLE user_notifications (
    user_notification_id  BIGINT     GENERATED ALWAYS AS IDENTITY,
    notification_id       BIGINT     NOT NULL,
    user_id               BIGINT     NOT NULL,
    channel               CHAR(1)    NOT NULL DEFAULT 'A',     -- A in-app, E e-mail, S SMS, W WhatsApp
    delivery_status       CHAR(1)    NOT NULL DEFAULT 'Q',     -- Q queued, S sent, F failed
    is_read               BOOLEAN    NOT NULL DEFAULT FALSE,
    read_at               TIMESTAMP,
    created_at            TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user_notifications PRIMARY KEY (user_notification_id),
    CONSTRAINT uq_user_notifications_target UNIQUE (notification_id, user_id, channel),
    CONSTRAINT fk_user_notifications_notification FOREIGN KEY (notification_id) REFERENCES notifications (notification_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_notifications_user         FOREIGN KEY (user_id)         REFERENCES users (user_id)                 ON DELETE CASCADE,
    CONSTRAINT ck_user_notifications_channel CHECK (channel IN ('A','E','S','W')),
    CONSTRAINT ck_user_notifications_status  CHECK (delivery_status IN ('Q','S','F')),
    CONSTRAINT ck_user_notifications_read    CHECK (is_read = (read_at IS NOT NULL))
);
