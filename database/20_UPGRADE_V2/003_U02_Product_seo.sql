-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/003_U02_Product_seo.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U2 Product SEO architecture
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 2 - PRODUCT SEO ARCHITECTURE
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_seo | Purpose: search-engine and social-share metadata, one row per product.
-- Keys : PK(seo_id) | CK/AK: product_id
-- Rel  : 1:1 products
-- BCNF : every attribute depends on the product's SEO row; the three meta_* columns formerly on
--        products moved here so SEO data lives in one place.
-- ---------------------------------------------------------------------
CREATE TABLE product_seo (
    seo_id               BIGINT        GENERATED ALWAYS AS IDENTITY,
    product_id           BIGINT        NOT NULL,
    meta_title           VARCHAR(160),
    meta_description     VARCHAR(320),
    meta_keywords        VARCHAR(255),
    canonical_url        VARCHAR(500),
    schema_markup        JSONB,
    robots_index         BOOLEAN       NOT NULL DEFAULT TRUE,     -- TRUE = index, FALSE = noindex
    og_title             VARCHAR(160),
    og_description       VARCHAR(320),
    og_image             VARCHAR(500),
    twitter_title        VARCHAR(160),
    twitter_description  VARCHAR(320),
    twitter_image        VARCHAR(500),
    created_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_seo PRIMARY KEY (seo_id),
    CONSTRAINT uq_product_seo_product_id UNIQUE (product_id),
    CONSTRAINT fk_product_seo_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT ck_product_seo_canonical CHECK (canonical_url IS NULL OR canonical_url ~* '^https?://'),
    CONSTRAINT ck_product_seo_schema    CHECK (schema_markup IS NULL OR jsonb_typeof(schema_markup) IN ('object','array')),
    CONSTRAINT ck_product_seo_og_image  CHECK (og_image IS NULL OR og_image ~* '^(https?://|/)'),
    CONSTRAINT ck_product_seo_tw_image  CHECK (twitter_image IS NULL OR twitter_image ~* '^(https?://|/)')
);

INSERT INTO product_seo (product_id, meta_title, meta_description, meta_keywords)
SELECT product_id, meta_title, meta_description, meta_keywords
FROM products
WHERE meta_title IS NOT NULL OR meta_description IS NOT NULL OR meta_keywords IS NOT NULL;

ALTER TABLE products
    DROP COLUMN meta_title,
    DROP COLUMN meta_description,
    DROP COLUMN meta_keywords;

