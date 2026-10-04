-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/017_U19_Error_logs.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U19 Error logging
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 19 - ERROR LOGGING
-- =====================================================================
ALTER TABLE error_logs RENAME COLUMN error_log_id TO error_id;
ALTER TABLE error_logs RENAME COLUMN source       TO module_name;
ALTER TABLE error_logs RENAME COLUMN error_level  TO severity;          -- W warning, E error, F fatal
ALTER TABLE error_logs RENAME COLUMN user_id      TO reported_by;
ALTER TABLE error_logs RENAME CONSTRAINT fk_error_logs_user  TO fk_error_logs_reported_by;
ALTER TABLE error_logs RENAME CONSTRAINT ck_error_logs_level TO ck_error_logs_severity;

UPDATE error_logs SET module_name = 'application' WHERE module_name IS NULL;
ALTER TABLE error_logs ALTER COLUMN module_name SET DEFAULT 'application';
ALTER TABLE error_logs ALTER COLUMN module_name SET NOT NULL;
CREATE INDEX idx_error_logs_module ON error_logs (module_name, created_at DESC);

