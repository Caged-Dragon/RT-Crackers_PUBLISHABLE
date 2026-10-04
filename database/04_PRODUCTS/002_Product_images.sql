-- =====================================================================
-- RT CRACKERS | 04_PRODUCTS/002_Product_images.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_images | Purpose: gallery images per product.
-- Keys : PK(product_image_id) | CK/AK: (product_id, image_url)
-- Rel  : N:1 products
-- BCNF : attributes depend on the image row.
-- ---------------------------------------------------------------------
CREATE TABLE product_images (
    product_image_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    product_id        BIGINT        NOT NULL,
    image_url         VARCHAR(500)  NOT NULL,
    alt_text          VARCHAR(200),
    is_primary        BOOLEAN       NOT NULL DEFAULT FALSE,
    display_order     SMALLINT      NOT NULL DEFAULT 0,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_images PRIMARY KEY (product_image_id),
    CONSTRAINT uq_product_images_product_url UNIQUE (product_id, image_url),
    CONSTRAINT fk_product_images_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX uq_product_images_one_primary ON product_images (product_id) WHERE is_primary;
