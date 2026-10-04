-- =====================================================================
-- RT CRACKERS | 19_INDEXES/002_Product_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_subcategories_category_id  ON subcategories (category_id);
CREATE INDEX idx_products_category_id       ON products (category_id, subcategory_id);
CREATE INDEX idx_products_brand_id          ON products (brand_id);
CREATE INDEX idx_products_active_featured   ON products (is_featured) WHERE status = 'A';
CREATE INDEX idx_products_active_trending   ON products (is_trending) WHERE status = 'A';
CREATE INDEX idx_products_search            ON products USING GIN (TO_TSVECTOR('english', product_name || ' ' || COALESCE(short_description, '')));
CREATE INDEX idx_product_variants_product   ON product_variants (product_id);
CREATE INDEX idx_attribute_values_attribute ON attribute_values (attribute_id);
CREATE INDEX idx_reviews_product_status     ON reviews (product_id, status);
CREATE INDEX idx_reviews_user_id            ON reviews (user_id);
CREATE INDEX idx_review_reports_review      ON review_reports (review_id);

-- NOTE: products.sku/barcode/slug already have unique indexes (uq_products_sku, uq_products_barcode, uq_products_slug).
-- A second CREATE INDEX on the same columns would only duplicate them.
