-- =====================================================================
-- RT CRACKERS | 15_NOTIFICATIONS/003_Email_templates.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- email_templates | Purpose: reusable e-mail bodies keyed by code (ORDER_PLACED, COD_OTP...).
-- Keys : PK(template_id) | CK/AK: template_code
-- Rel  : 1:N notifications
-- BCNF : attributes depend only on the template.
-- ---------------------------------------------------------------------
CREATE TABLE email_templates (
    template_id     INTEGER       GENERATED ALWAYS AS IDENTITY,
    template_code   VARCHAR(50)   NOT NULL,
    subject         VARCHAR(200)  NOT NULL,
    body_html       TEXT          NOT NULL,
    body_text       TEXT,
    placeholders    VARCHAR(500),
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_email_templates PRIMARY KEY (template_id),
    CONSTRAINT uq_email_templates_code UNIQUE (template_code),
    CONSTRAINT ck_email_templates_code_upper CHECK (template_code = UPPER(template_code))
);
