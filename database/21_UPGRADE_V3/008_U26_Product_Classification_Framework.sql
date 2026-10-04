-- RT CRACKERS | 21_UPGRADE_V3/008_U26_Product_Classification_Framework.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 26 - PRODUCT CLASSIFICATION FRAMEWORK
-- Already existing: category, subcategory, brand, festival (festival_products).
-- New: product type (one per product), collections and seasons (many per product).
-- v_product_classification joins everything for filtering.
-- =====================================================================
CREATE TABLE product_types (
    product_type_id  SMALLINT      GENERATED ALWAYS AS IDENTITY,
    type_code        VARCHAR(30)   NOT NULL,
    type_name        VARCHAR(80)   NOT NULL,
    slug             VARCHAR(100)  NOT NULL,
    description      VARCHAR(255),
    display_order    SMALLINT      NOT NULL DEFAULT 0,
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_types PRIMARY KEY (product_type_id),
    CONSTRAINT uq_product_types_code UNIQUE (type_code),
    CONSTRAINT uq_product_types_name UNIQUE (type_name),
    CONSTRAINT uq_product_types_slug UNIQUE (slug),
    CONSTRAINT ck_product_types_code CHECK (type_code = UPPER(type_code))
);
INSERT INTO product_types (type_code, type_name, slug, display_order) VALUES
    ('SPARKLER',       'Sparklers',                'sparklers',        1),
    ('FLOWER_POT',     'Flower Pots',              'flower-pots',      2),
    ('GROUND_CHAKKAR', 'Ground Chakkars',          'ground-chakkars',  3),
    ('FOUNTAIN',       'Fountains',                'fountains',        4),
    ('ROCKET',         'Rockets',                  'rockets',          5),
    ('SKY_SHOT',       'Sky Shots & Aerials',      'sky-shots',        6),
    ('MULTI_SHOT',     'Multi-shot Cakes',         'multi-shot-cakes', 7),
    ('CRACKER',        'Crackers & Bombs',         'crackers-bombs',   8),
    ('KIDS_SPECIAL',   'Kids Specials',            'kids-specials',    9),
    ('GIFT_BOX',       'Gift Boxes',               'gift-boxes',      10),
    ('COMBO_PACK',     'Combo Packs',              'combo-packs',     11),
    ('NOVELTY',        'Novelty & Fun',            'novelty',         12);

CREATE TABLE collections (
    collection_id    INTEGER       GENERATED ALWAYS AS IDENTITY,
    collection_name  VARCHAR(100)  NOT NULL,
    slug             VARCHAR(120)  NOT NULL,
    description      TEXT,
    image_url        VARCHAR(500),
    start_date       DATE,
    end_date         DATE,
    display_order    SMALLINT      NOT NULL DEFAULT 0,
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_collections PRIMARY KEY (collection_id),
    CONSTRAINT uq_collections_name UNIQUE (collection_name),
    CONSTRAINT uq_collections_slug UNIQUE (slug),
    CONSTRAINT ck_collections_window CHECK (start_date IS NULL OR end_date IS NULL OR end_date >= start_date)
);
INSERT INTO collections (collection_name, slug, display_order) VALUES
    ('Family Packs',        'family-packs',        1),
    ('Kids Safe Picks',     'kids-safe-picks',     2),
    ('Premium Gift Boxes',  'premium-gift-boxes',  3),
    ('Best Sellers',        'best-sellers',        4),
    ('New Launches',        'new-launches',        5);

CREATE TABLE seasons (
    season_id    SMALLINT      GENERATED ALWAYS AS IDENTITY,
    season_name  VARCHAR(80)   NOT NULL,
    slug         VARCHAR(100)  NOT NULL,
    start_month  SMALLINT      NOT NULL,
    end_month    SMALLINT      NOT NULL,                       -- may be smaller than start_month (wraps over new year)
    description  VARCHAR(255),
    is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_seasons PRIMARY KEY (season_id),
    CONSTRAINT uq_seasons_name UNIQUE (season_name),
    CONSTRAINT uq_seasons_slug UNIQUE (slug),
    CONSTRAINT ck_seasons_months CHECK (start_month BETWEEN 1 AND 12 AND end_month BETWEEN 1 AND 12)
);
INSERT INTO seasons (season_name, slug, start_month, end_month, description) VALUES
    ('Diwali Season',          'diwali',          10, 11, 'Deepavali shopping season'),
    ('Pongal & Harvest',       'pongal-harvest',   1,  1, 'Pongal / Sankranti'),
    ('Christmas & New Year',   'christmas-new-year',12, 1, 'Year-end celebrations'),
    ('Wedding & Events',       'wedding-events',   4,  6, 'Wedding and temple festival season'),
    ('All Year',               'all-year',         1, 12, 'Not seasonal');

ALTER TABLE products ADD COLUMN product_type_id SMALLINT;
ALTER TABLE products ADD CONSTRAINT fk_products_product_type FOREIGN KEY (product_type_id) REFERENCES product_types (product_type_id) ON DELETE SET NULL;
CREATE INDEX idx_products_product_type ON products (product_type_id) WHERE product_type_id IS NOT NULL;

CREATE TABLE product_collections (
    product_id     BIGINT     NOT NULL,
    collection_id  INTEGER    NOT NULL,
    display_order  SMALLINT   NOT NULL DEFAULT 0,
    created_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_collections PRIMARY KEY (product_id, collection_id),
    CONSTRAINT fk_product_collections_product    FOREIGN KEY (product_id)    REFERENCES products (product_id)       ON DELETE CASCADE,
    CONSTRAINT fk_product_collections_collection FOREIGN KEY (collection_id) REFERENCES collections (collection_id) ON DELETE CASCADE
);
CREATE INDEX idx_product_collections_collection ON product_collections (collection_id);

CREATE TABLE product_seasons (
    product_id  BIGINT     NOT NULL,
    season_id   SMALLINT   NOT NULL,
    created_at  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_seasons PRIMARY KEY (product_id, season_id),
    CONSTRAINT fk_product_seasons_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT fk_product_seasons_season  FOREIGN KEY (season_id)  REFERENCES seasons (season_id)   ON DELETE CASCADE
);
CREATE INDEX idx_product_seasons_season ON product_seasons (season_id);

CREATE VIEW v_product_classification WITH (security_invoker = true) AS
SELECT p.product_id, p.sku, p.product_name, p.status,
       c.category_id,  c.category_name,
       sc.subcategory_id, sc.subcategory_name,
       b.brand_id, b.brand_name,
       pt.product_type_id, pt.type_code AS product_type_code, pt.type_name AS product_type,
       ARRAY(SELECT col.collection_name FROM product_collections pc JOIN collections col ON col.collection_id = pc.collection_id
              WHERE pc.product_id = p.product_id ORDER BY col.collection_name) AS collections,
       ARRAY(SELECT s.season_name FROM product_seasons ps JOIN seasons s ON s.season_id = ps.season_id
              WHERE ps.product_id = p.product_id ORDER BY s.season_name) AS seasons,
       ARRAY(SELECT f.festival_name FROM festival_products fp JOIN festivals f ON f.festival_id = fp.festival_id
              WHERE fp.product_id = p.product_id ORDER BY f.festival_name) AS festivals
  FROM products p
  JOIN categories c           ON c.category_id = p.category_id
  LEFT JOIN subcategories sc  ON sc.subcategory_id = p.subcategory_id
  LEFT JOIN brands b          ON b.brand_id = p.brand_id
  LEFT JOIN product_types pt  ON pt.product_type_id = p.product_type_id
 WHERE NOT p.is_deleted;
