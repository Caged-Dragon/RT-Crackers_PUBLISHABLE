-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/015_U17_System_configurations.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U17 System configuration module
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 17 - SYSTEM CONFIGURATION MODULE
-- =====================================================================
ALTER TABLE system_configurations ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE system_configurations DROP CONSTRAINT uq_system_configurations_group_key;
ALTER TABLE system_configurations ADD CONSTRAINT uq_system_configurations_config_key UNIQUE (config_key);
ALTER TABLE system_configurations ADD CONSTRAINT ck_system_configurations_key CHECK (BTRIM(config_key) <> '');

INSERT INTO system_configurations (config_group, config_key, config_value, description) VALUES
    ('security', 'security.max_failed_logins',     '5',  'Failed logins before an account is locked'),
    ('security', 'security.lockout_minutes',       '30', 'Minutes an account stays locked after too many failures'),
    ('security', 'security.password_expiry_days',  '90', 'Days before a password must be changed')
ON CONFLICT (config_key) DO NOTHING;

