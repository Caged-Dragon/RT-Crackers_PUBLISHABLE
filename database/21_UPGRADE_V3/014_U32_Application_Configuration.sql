-- RT CRACKERS | 21_UPGRADE_V3/014_U32_Application_Configuration.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 32 - APPLICATION CONFIGURATION
-- system_configurations gets a value type (validated by trigger) and a public flag.
-- Company details are added as group 'company'. Fill in the blanks: the values below are empty
-- on purpose (a wrong GST number or e-mail is worse than none). v_company_profile_gaps lists them.
-- =====================================================================
ALTER TABLE system_configurations
    ADD COLUMN value_type  CHAR(1)  NOT NULL DEFAULT 'S',     -- S string, N number, B boolean, J json, E e-mail, U url, P phone, G GSTIN
    ADD COLUMN is_public   BOOLEAN  NOT NULL DEFAULT FALSE;   -- may be shown on the storefront
UPDATE system_configurations SET value_type = 'N' WHERE config_group = 'security';
ALTER TABLE system_configurations ADD CONSTRAINT ck_system_configurations_value_type CHECK (value_type IN ('S','N','B','J','E','U','P','G'));

CREATE OR REPLACE FUNCTION fn_validate_config_value()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_bad BOOLEAN;
BEGIN
    IF NEW.config_value = '' OR NEW.is_encrypted THEN RETURN NEW; END IF;
    v_bad := CASE NEW.value_type
           WHEN 'N' THEN NEW.config_value !~ '^-?[0-9]+(\.[0-9]+)?$'
           WHEN 'B' THEN NEW.config_value NOT IN ('true','false')
           WHEN 'E' THEN NEW.config_value !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
           WHEN 'U' THEN NEW.config_value !~* '^(https?://|/)\S+$'
           WHEN 'P' THEN NEW.config_value !~ '^\+?[0-9][0-9 ()-]{6,18}$'
           WHEN 'G' THEN NEW.config_value !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'
           WHEN 'J' THEN FALSE
           ELSE FALSE END;
    IF v_bad THEN
        RAISE EXCEPTION 'Configuration "%" must be a valid value of type %', NEW.config_key, NEW.value_type
            USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.value_type = 'J' THEN PERFORM NEW.config_value::JSONB; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_system_configurations_validate BEFORE INSERT OR UPDATE OF config_value, value_type ON system_configurations
    FOR EACH ROW EXECUTE FUNCTION fn_validate_config_value();

INSERT INTO system_configurations (config_group, config_key, config_value, value_type, is_public, description) VALUES
    ('company', 'company.store_name',    'RT Crackers', 'S', TRUE,  'Store name'),
    ('company', 'company.support_email', '',            'E', TRUE,  'Customer support e-mail address'),
    ('company', 'company.support_phone', '',            'P', TRUE,  'Customer support phone number'),
    ('company', 'company.gst_number',    '',            'G', TRUE,  'GSTIN printed on invoices'),
    ('company', 'company.address',       '',            'S', TRUE,  'Registered company address'),
    ('company', 'company.logo_url',      '',            'U', TRUE,  'Company logo URL'),
    ('company', 'company.terms_url',     '',            'U', TRUE,  'Terms and conditions page URL'),
    ('company', 'company.privacy_url',   '',            'U', TRUE,  'Privacy policy page URL');

CREATE VIEW v_company_profile WITH (security_invoker = true) AS
SELECT MAX(config_value) FILTER (WHERE config_key = 'company.store_name')    AS store_name,
       MAX(config_value) FILTER (WHERE config_key = 'company.support_email') AS support_email,
       MAX(config_value) FILTER (WHERE config_key = 'company.support_phone') AS support_phone,
       MAX(config_value) FILTER (WHERE config_key = 'company.gst_number')    AS gst_number,
       MAX(config_value) FILTER (WHERE config_key = 'company.address')       AS company_address,
       MAX(config_value) FILTER (WHERE config_key = 'company.logo_url')      AS company_logo_url,
       MAX(config_value) FILTER (WHERE config_key = 'company.terms_url')     AS terms_url,
       MAX(config_value) FILTER (WHERE config_key = 'company.privacy_url')   AS privacy_url
  FROM system_configurations
 WHERE config_group = 'company' AND is_active;

CREATE VIEW v_company_profile_gaps WITH (security_invoker = true) AS
SELECT config_key, description FROM system_configurations
 WHERE config_group = 'company' AND is_active AND BTRIM(config_value) = '';
