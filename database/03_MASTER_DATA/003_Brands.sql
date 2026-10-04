-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/003_Brands.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- brands | Purpose: product brands/labels.
-- Keys : PK(brand_id) | CK/AK: brand_name, slug
-- Rel  : 1:N products
-- BCNF : attributes depend only on the brand.
-- ---------------------------------------------------------------------
CREATE TABLE brands (
    brand_id     INTEGER       GENERATED ALWAYS AS IDENTITY,
    brand_name   VARCHAR(100)  NOT NULL,
    slug         VARCHAR(120)  NOT NULL,
    logo_url     VARCHAR(500),
    description  TEXT,
    website_url  VARCHAR(255),
    is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_brands PRIMARY KEY (brand_id),
    CONSTRAINT uq_brands_brand_name UNIQUE (brand_name),
    CONSTRAINT uq_brands_slug       UNIQUE (slug)
);
