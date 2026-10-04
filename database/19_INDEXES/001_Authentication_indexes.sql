-- =====================================================================
-- RT CRACKERS | 19_INDEXES/001_Authentication_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_users_referred_by          ON users (referred_by);
CREATE INDEX idx_users_status               ON users (status);
CREATE INDEX idx_sessions_user_id           ON sessions (user_id, expires_at);
CREATE INDEX idx_refresh_tokens_user_id     ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_session_id  ON refresh_tokens (session_id);
CREATE INDEX idx_login_history_user_time    ON login_history (user_id, created_at DESC);
CREATE INDEX idx_login_history_ip           ON login_history (ip_address);
CREATE INDEX idx_password_reset_user        ON password_reset_tokens (user_id);
CREATE INDEX idx_admin_activity_admin_time  ON admin_activity_logs (admin_id, created_at DESC);
CREATE INDEX idx_admin_notifications_unread ON admin_notifications (admin_id) WHERE NOT is_read;

-- NOTE: users.email/phone already have unique indexes (uq_users_email, uq_users_phone).
