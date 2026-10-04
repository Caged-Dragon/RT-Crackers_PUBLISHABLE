-- RT CRACKERS | 21_UPGRADE_V3/001_Schema_versions.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- ---------------------------------------------------------------------
-- Schema version register
-- ---------------------------------------------------------------------
CREATE TABLE schema_versions (
    schema_version_id  SMALLINT      GENERATED ALWAYS AS IDENTITY,
    version_number     VARCHAR(10)   NOT NULL,
    description        VARCHAR(255)  NOT NULL,
    applied_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    applied_by         VARCHAR(80)   NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_schema_versions PRIMARY KEY (schema_version_id),
    CONSTRAINT uq_schema_versions_number UNIQUE (version_number)
);
COMMENT ON TABLE schema_versions IS 'Which upgrade scripts have been applied to this database.';
