-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/002_Subcategories.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- subcategories | Purpose: second-level grouping inside a category.
-- Keys : PK(subcategory_id) | CK/AK: slug, (category_id, subcategory_name), (category_id, subcategory_id)
-- Rel  : N:1 categories; 1:N products
-- BCNF : attributes depend on subcategory_id; (category_id, subcategory_id) unique pair supports products' composite FK.
-- ---------------------------------------------------------------------
CREATE TABLE subcategories (
    subcategory_id    INTEGER       GENERATED ALWAYS AS IDENTITY,
    category_id       INTEGER       NOT NULL,
    subcategory_name  VARCHAR(100)  NOT NULL,
    slug              VARCHAR(120)  NOT NULL,
    description       TEXT,
    image_url         VARCHAR(500),
    display_order     SMALLINT      NOT NULL DEFAULT 0,
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_subcategories PRIMARY KEY (subcategory_id),
    CONSTRAINT uq_subcategories_slug              UNIQUE (slug),
    CONSTRAINT uq_subcategories_category_name     UNIQUE (category_id, subcategory_name),
    CONSTRAINT uq_subcategories_category_sub      UNIQUE (category_id, subcategory_id),
    CONSTRAINT fk_subcategories_category FOREIGN KEY (category_id) REFERENCES categories (category_id) ON DELETE RESTRICT
);
