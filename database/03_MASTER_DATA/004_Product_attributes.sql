-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/004_Product_attributes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_attributes | Purpose: attribute definitions (Shots, Duration, Noise level, Colour effect...).
-- Keys : PK(attribute_id) | CK/AK: attribute_code, attribute_name
-- Rel  : 1:N attribute_values
-- BCNF : attributes depend only on the attribute definition.
-- ---------------------------------------------------------------------
CREATE TABLE product_attributes (
    attribute_id    INTEGER      GENERATED ALWAYS AS IDENTITY,
    attribute_code  VARCHAR(40)  NOT NULL,
    attribute_name  VARCHAR(80)  NOT NULL,
    data_type       CHAR(1)      NOT NULL DEFAULT 'T',     -- T text, N number, B boolean
    unit            VARCHAR(20),
    is_filterable   BOOLEAN      NOT NULL DEFAULT FALSE,
    display_order   SMALLINT     NOT NULL DEFAULT 0,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_attributes PRIMARY KEY (attribute_id),
    CONSTRAINT uq_product_attributes_code UNIQUE (attribute_code),
    CONSTRAINT uq_product_attributes_name UNIQUE (attribute_name),
    CONSTRAINT ck_product_attributes_type CHECK (data_type IN ('T','N','B'))
);
