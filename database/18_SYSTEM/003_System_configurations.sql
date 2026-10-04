-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/003_System_configurations.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- system_configurations | Purpose: technical configuration (token TTLs, login lockout, SMTP host...).
-- Keys : PK(config_id) | CK/AK: (config_group, config_key)
-- Rel  : none
-- BCNF : value/encryption flag depend on the (group, key) candidate key.
-- ---------------------------------------------------------------------
CREATE TABLE system_configurations (
    config_id      INTEGER       GENERATED ALWAYS AS IDENTITY,
    config_group   VARCHAR(40)   NOT NULL,
    config_key     VARCHAR(80)   NOT NULL,
    config_value   TEXT          NOT NULL,
    is_encrypted   BOOLEAN       NOT NULL DEFAULT FALSE,
    description    VARCHAR(255),
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_system_configurations PRIMARY KEY (config_id),
    CONSTRAINT uq_system_configurations_group_key UNIQUE (config_group, config_key)
);
