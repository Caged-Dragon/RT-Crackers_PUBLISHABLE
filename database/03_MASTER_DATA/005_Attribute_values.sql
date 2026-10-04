-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/005_Attribute_values.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- attribute_values | Purpose: value of an attribute for a product (or one of its variants).
-- Keys : PK(attribute_value_id) | CK/AK: (product_id, variant_id|0, attribute_id) via unique index
-- Rel  : N:1 products, product_variants (composite FK), product_attributes
-- BCNF : value_text depends on (product, variant, attribute) which is a candidate key.
-- ---------------------------------------------------------------------
CREATE TABLE attribute_values (
    attribute_value_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    product_id          BIGINT        NOT NULL,
    variant_id          BIGINT,
    attribute_id        INTEGER       NOT NULL,
    value_text          VARCHAR(255)  NOT NULL,
    created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_attribute_values PRIMARY KEY (attribute_value_id),
    CONSTRAINT fk_attribute_values_product   FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT fk_attribute_values_variant   FOREIGN KEY (product_id, variant_id) REFERENCES product_variants (product_id, variant_id) ON DELETE CASCADE,
    CONSTRAINT fk_attribute_values_attribute FOREIGN KEY (attribute_id) REFERENCES product_attributes (attribute_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX uq_attribute_values_target ON attribute_values (product_id, COALESCE(variant_id, 0), attribute_id);
