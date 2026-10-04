-- RT CRACKERS | 21_UPGRADE_V3/010_U27_Data_Retention_Policy.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 27 - DATA RETENTION POLICY
-- archive_after_days : rows older than this leave the active table (archive framework, U28)
-- retention_period   : days after which archived rows may be destroyed
-- Order data keeps 7 years (tax records). Adjust to the advice you get for your business.
-- =====================================================================
CREATE TABLE data_retention_policies (
    policy_id             SMALLINT      GENERATED ALWAYS AS IDENTITY,
    entity_name           VARCHAR(63)   NOT NULL,
    retention_period      INTEGER       NOT NULL,             -- days
    archive_after_days    INTEGER       NOT NULL,             -- days
    legal_basis           VARCHAR(255),
    is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_data_retention_policies PRIMARY KEY (policy_id),
    CONSTRAINT uq_data_retention_policies_entity UNIQUE (entity_name),
    CONSTRAINT ck_data_retention_policies_days   CHECK (archive_after_days > 0 AND retention_period >= archive_after_days)
);
INSERT INTO data_retention_policies (entity_name, retention_period, archive_after_days, legal_basis) VALUES
    ('orders',             2555, 730, 'Tax and accounting records (7 years)'),
    ('audit_logs',         2555, 180, 'Security forensics and accountability'),
    ('login_history',       730, 180, 'Security monitoring'),
    ('error_logs',          365,  90, 'Operational troubleshooting'),
    ('search_logs',         365,  90, 'Search tuning'),
    ('user_activity_logs',  365,  90, 'Product analytics'),
    ('page_views',          365,  90, 'Product analytics'),
    ('user_notifications',  365,  90, 'Customer communication history');
