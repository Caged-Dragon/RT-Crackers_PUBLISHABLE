-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/001_Settings.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- settings | Purpose: business settings editable by staff (store name, COD cap...).
-- Keys : PK(setting_id) | CK/AK: setting_key
-- Rel  : N:1 admins (updated_by)
-- BCNF : value/type depend on the setting key.
-- ---------------------------------------------------------------------
CREATE TABLE settings (
    setting_id     INTEGER       GENERATED ALWAYS AS IDENTITY,
    setting_key    VARCHAR(80)   NOT NULL,
    setting_value  TEXT          NOT NULL,
    value_type     CHAR(1)       NOT NULL DEFAULT 'S',        -- S string, N number, B boolean, J json
    description    VARCHAR(255),
    is_public      BOOLEAN       NOT NULL DEFAULT FALSE,
    updated_by     INTEGER,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_settings PRIMARY KEY (setting_id),
    CONSTRAINT uq_settings_key UNIQUE (setting_key),
    CONSTRAINT fk_settings_updated_by FOREIGN KEY (updated_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_settings_value_type CHECK (value_type IN ('S','N','B','J'))
);
