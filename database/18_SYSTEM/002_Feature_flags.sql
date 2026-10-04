-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/002_Feature_flags.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- feature_flags | Purpose: runtime on/off switches with percentage rollout.
-- Keys : PK(flag_id) | CK/AK: flag_key
-- Rel  : none
-- BCNF : attributes depend only on the flag.
-- ---------------------------------------------------------------------
CREATE TABLE feature_flags (
    flag_id             SMALLINT      GENERATED ALWAYS AS IDENTITY,
    flag_key            VARCHAR(60)   NOT NULL,
    description         VARCHAR(255),
    is_enabled          BOOLEAN       NOT NULL DEFAULT FALSE,
    rollout_percentage  SMALLINT      NOT NULL DEFAULT 100,
    enabled_from        TIMESTAMP,
    enabled_until       TIMESTAMP,
    created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_feature_flags PRIMARY KEY (flag_id),
    CONSTRAINT uq_feature_flags_key UNIQUE (flag_key),
    CONSTRAINT ck_feature_flags_rollout CHECK (rollout_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_feature_flags_window  CHECK (enabled_from IS NULL OR enabled_until IS NULL OR enabled_until > enabled_from)
);
