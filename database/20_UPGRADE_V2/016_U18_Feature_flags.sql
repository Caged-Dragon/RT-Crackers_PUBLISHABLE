-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/016_U18_Feature_flags.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U18 Feature flags
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 18 - FEATURE FLAGS
-- =====================================================================
ALTER TABLE feature_flags RENAME COLUMN flag_id  TO feature_id;
ALTER TABLE feature_flags RENAME COLUMN flag_key TO feature_name;
ALTER TABLE feature_flags RENAME CONSTRAINT uq_feature_flags_key TO uq_feature_flags_feature_name;

INSERT INTO feature_flags (feature_name, description, is_enabled) VALUES
    ('notifications', 'Customer notifications', TRUE),
    ('analytics',     'Analytics collection',   TRUE)
ON CONFLICT (feature_name) DO NOTHING;

