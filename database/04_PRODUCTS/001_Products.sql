-- =====================================================================
-- RT CRACKERS | 04_PRODUCTS/001_Products.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- products | Purpose: sellable product master.
-- Keys : PK(product_id) | CK/AK: sku, barcode, slug
-- Rel  : N:1 categories, subcategories (composite FK keeps them consistent), brands;
--        1:N images, variants, attribute_values, inventory, reviews, order_items...
-- BCNF : discount_percentage and (via triggers) stock_quantity / rating_* / sales_count / view_count are
--        derived, so they are GENERATED or trigger-maintained and cannot drift. category_id is retained next
--        to the nullable subcategory_id; the composite FK (category_id, subcategory_id) pins them together.
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id           BIGINT         GENERATED ALWAYS AS IDENTITY,
    category_id          INTEGER        NOT NULL,
    subcategory_id       INTEGER,
    brand_id             INTEGER,
    sku                  VARCHAR(40)    NOT NULL,
    barcode              VARCHAR(32),
    slug                 VARCHAR(200)   NOT NULL,
    product_name         VARCHAR(200)   NOT NULL,
    short_description    VARCHAR(500),
    description          TEXT,
    mrp                  NUMERIC(12,2)  NOT NULL,
    selling_price        NUMERIC(12,2)  NOT NULL,
    cost_price           NUMERIC(12,2)  NOT NULL,
    discount_percentage  NUMERIC(5,2)   GENERATED ALWAYS AS (ROUND((mrp - selling_price) * 100 / NULLIF(mrp, 0), 2)) STORED,
    weight               NUMERIC(10,3)  NOT NULL DEFAULT 0,      -- kg
    length               NUMERIC(8,2)   NOT NULL DEFAULT 0,      -- cm
    width                NUMERIC(8,2)   NOT NULL DEFAULT 0,
    height               NUMERIC(8,2)   NOT NULL DEFAULT 0,
    gst_percentage       NUMERIC(5,2)   NOT NULL DEFAULT 18.00,
    country_of_origin    VARCHAR(60)    NOT NULL DEFAULT 'India',
    manufacturer         VARCHAR(150),
    warranty_period      SMALLINT       NOT NULL DEFAULT 0,      -- months
    safety_instructions  TEXT,
    stock_quantity       INTEGER        NOT NULL DEFAULT 0,      -- maintained from inventory
    min_stock_level      INTEGER        NOT NULL DEFAULT 0,
    max_stock_level      INTEGER        NOT NULL DEFAULT 1000,
    is_featured          BOOLEAN        NOT NULL DEFAULT FALSE,
    is_trending          BOOLEAN        NOT NULL DEFAULT FALSE,
    is_new_arrival       BOOLEAN        NOT NULL DEFAULT FALSE,
    status               CHAR(1)        NOT NULL DEFAULT 'D',    -- D draft, A active, I inactive, X archived
    meta_title           VARCHAR(160),
    meta_description     VARCHAR(320),
    meta_keywords        VARCHAR(255),
    view_count           INTEGER        NOT NULL DEFAULT 0,
    sales_count          INTEGER        NOT NULL DEFAULT 0,
    rating_average       NUMERIC(3,2)   NOT NULL DEFAULT 0,
    rating_count         INTEGER        NOT NULL DEFAULT 0,
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_products PRIMARY KEY (product_id),
    CONSTRAINT uq_products_sku     UNIQUE (sku),
    CONSTRAINT uq_products_barcode UNIQUE (barcode),
    CONSTRAINT uq_products_slug    UNIQUE (slug),
    CONSTRAINT fk_products_category    FOREIGN KEY (category_id) REFERENCES categories (category_id) ON DELETE RESTRICT,
    CONSTRAINT fk_products_subcategory FOREIGN KEY (category_id, subcategory_id) REFERENCES subcategories (category_id, subcategory_id) ON DELETE RESTRICT,
    CONSTRAINT fk_products_brand       FOREIGN KEY (brand_id) REFERENCES brands (brand_id) ON DELETE SET NULL,
    CONSTRAINT ck_products_mrp            CHECK (mrp > 0),
    CONSTRAINT ck_products_selling_price  CHECK (selling_price > 0),
    CONSTRAINT ck_products_cost_price     CHECK (cost_price > 0),
    CONSTRAINT ck_products_price_le_mrp   CHECK (selling_price <= mrp),
    CONSTRAINT ck_products_stock_qty      CHECK (stock_quantity >= 0),
    CONSTRAINT ck_products_discount_pct   CHECK (discount_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_products_dimensions     CHECK (weight >= 0 AND length >= 0 AND width >= 0 AND height >= 0),
    CONSTRAINT ck_products_gst            CHECK (gst_percentage BETWEEN 0 AND 40),
    CONSTRAINT ck_products_warranty       CHECK (warranty_period >= 0),
    CONSTRAINT ck_products_stock_levels   CHECK (min_stock_level >= 0 AND max_stock_level >= min_stock_level),
    CONSTRAINT ck_products_status         CHECK (status IN ('D','A','I','X')),
    CONSTRAINT ck_products_counters       CHECK (view_count >= 0 AND sales_count >= 0 AND rating_count >= 0),
    CONSTRAINT ck_products_rating_avg     CHECK (rating_average BETWEEN 0 AND 5)
);
