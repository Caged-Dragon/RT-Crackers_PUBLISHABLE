-- =====================================================================
-- RT CRACKERS | 17_ANALYTICS/002_Product_views.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_views | Purpose: product detail page views (feeds products.view_count by trigger).
-- Keys : PK(product_view_id)
-- Rel  : N:1 products, N:1 users (optional), N:1 sessions (optional)
-- BCNF : attributes describe one view.
-- ---------------------------------------------------------------------
CREATE TABLE product_views (
    product_view_id  BIGINT     GENERATED ALWAYS AS IDENTITY,
    product_id       BIGINT     NOT NULL,
    user_id          BIGINT,
    session_id       UUID,
    anonymous_id     VARCHAR(64),
    duration_seconds INTEGER,
    created_at       TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_views PRIMARY KEY (product_view_id),
    CONSTRAINT fk_product_views_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT fk_product_views_user    FOREIGN KEY (user_id)    REFERENCES users (user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_product_views_session FOREIGN KEY (session_id) REFERENCES sessions (session_id) ON DELETE SET NULL,
    CONSTRAINT ck_product_views_duration CHECK (duration_seconds IS NULL OR duration_seconds >= 0)
);

-- product_views -> products.view_count
CREATE OR REPLACE FUNCTION fn_increment_view_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE products SET view_count = view_count + 1 WHERE product_id = NEW.product_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_product_views_count AFTER INSERT ON product_views
    FOR EACH ROW EXECUTE FUNCTION fn_increment_view_count();
