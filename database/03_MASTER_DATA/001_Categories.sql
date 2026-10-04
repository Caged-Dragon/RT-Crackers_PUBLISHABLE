-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/001_Categories.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- categories | Purpose: top-level catalogue groups (Sparklers, Rockets, Gift Boxes...).
-- Keys : PK(category_id) | CK/AK: category_name, slug
-- Rel  : 1:N subcategories, products, festival_discounts
-- BCNF : attributes depend only on the category.
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    category_id    INTEGER       GENERATED ALWAYS AS IDENTITY,
    category_name  VARCHAR(100)  NOT NULL,
    slug           VARCHAR(120)  NOT NULL,
    description    TEXT,
    image_url      VARCHAR(500),
    display_order  SMALLINT      NOT NULL DEFAULT 0,
    is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_categories PRIMARY KEY (category_id),
    CONSTRAINT uq_categories_category_name UNIQUE (category_name),
    CONSTRAINT uq_categories_slug          UNIQUE (slug)
);
