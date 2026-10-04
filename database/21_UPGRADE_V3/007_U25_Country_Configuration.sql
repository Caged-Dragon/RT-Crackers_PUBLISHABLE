-- RT CRACKERS | 21_UPGRADE_V3/007_U25_Country_Configuration.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 25 - COUNTRY CONFIGURATION
-- Currency, tax, phone and postal rules per country (India seeded).
-- Existing India-only checks on users / addresses are unchanged; this table is what a
-- multi-country application reads, and what you extend when you open a new country.
-- =====================================================================
CREATE TABLE country_configurations (
    country_config_id   SMALLINT      GENERATED ALWAYS AS IDENTITY,
    country_id          SMALLINT      NOT NULL,
    currency_code       CHAR(3)       NOT NULL,
    currency_symbol     VARCHAR(5)    NOT NULL,
    currency_decimals   SMALLINT      NOT NULL DEFAULT 2,
    tax_name            VARCHAR(20)   NOT NULL DEFAULT 'GST',
    tax_rate            NUMERIC(5,2)  NOT NULL,                 -- default tax percentage
    phone_length        SMALLINT      NOT NULL,                 -- national number length, without country code
    phone_format        VARCHAR(120)  NOT NULL,                 -- regular expression
    postal_code_length  SMALLINT      NOT NULL,
    postal_format       VARCHAR(120)  NOT NULL,                 -- regular expression
    postal_example      VARCHAR(20),
    timezone            VARCHAR(40)   NOT NULL DEFAULT 'UTC',
    is_default          BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_country_configurations PRIMARY KEY (country_config_id),
    CONSTRAINT uq_country_configurations_country UNIQUE (country_id),
    CONSTRAINT fk_country_configurations_country FOREIGN KEY (country_id) REFERENCES countries (country_id) ON DELETE CASCADE,
    CONSTRAINT ck_country_configurations_currency CHECK (currency_code = UPPER(currency_code)),
    CONSTRAINT ck_country_configurations_decimals CHECK (currency_decimals BETWEEN 0 AND 4),
    CONSTRAINT ck_country_configurations_tax      CHECK (tax_rate BETWEEN 0 AND 100),
    CONSTRAINT ck_country_configurations_phone    CHECK (phone_length BETWEEN 4 AND 15),
    CONSTRAINT ck_country_configurations_postal   CHECK (postal_code_length BETWEEN 3 AND 10)
);
CREATE UNIQUE INDEX uq_country_configurations_default ON country_configurations (is_default) WHERE is_default;

INSERT INTO country_configurations (country_id, currency_code, currency_symbol, tax_name, tax_rate, phone_length, phone_format,
                                    postal_code_length, postal_format, postal_example, timezone, is_default)
SELECT country_id, 'INR', '₹', 'GST', 18.00, 10, '^[6-9][0-9]{9}$', 6, '^[1-9][0-9]{5}$', '641001', 'Asia/Kolkata', TRUE
  FROM countries WHERE country_code = 'IN';
