-- =====================================================================
-- RT CRACKERS | 13_REVIEWS/001_Reviews.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- reviews | Purpose: customer product reviews; verified_purchase is GENERATED from order_item_id.
-- Keys : PK(review_id) | CK/AK: (product_id, user_id), order_item_id
-- Rel  : N:1 products, users, order_items; 1:N review_images, review_reports
-- BCNF : verified_purchase is generated; reported_count is trigger-maintained from review_reports.
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    review_id          BIGINT        GENERATED ALWAYS AS IDENTITY,
    product_id         BIGINT        NOT NULL,
    user_id            BIGINT        NOT NULL,
    order_item_id      BIGINT,
    rating             SMALLINT      NOT NULL,
    title              VARCHAR(150),
    review_text        TEXT,
    verified_purchase  BOOLEAN       GENERATED ALWAYS AS (order_item_id IS NOT NULL) STORED,
    helpful_count      INTEGER       NOT NULL DEFAULT 0,
    reported_count     INTEGER       NOT NULL DEFAULT 0,
    status             CHAR(1)       NOT NULL DEFAULT 'P',      -- P pending, A approved, R rejected, H hidden
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_reviews PRIMARY KEY (review_id),
    CONSTRAINT uq_reviews_product_user UNIQUE (product_id, user_id),
    CONSTRAINT uq_reviews_order_item   UNIQUE (order_item_id),
    CONSTRAINT fk_reviews_product    FOREIGN KEY (product_id)    REFERENCES products (product_id)       ON DELETE CASCADE,
    CONSTRAINT fk_reviews_user       FOREIGN KEY (user_id)       REFERENCES users (user_id)             ON DELETE CASCADE,
    CONSTRAINT fk_reviews_order_item FOREIGN KEY (order_item_id) REFERENCES order_items (order_item_id) ON DELETE SET NULL,
    CONSTRAINT ck_reviews_rating   CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT ck_reviews_counts   CHECK (helpful_count >= 0 AND reported_count >= 0),
    CONSTRAINT ck_reviews_status   CHECK (status IN ('P','A','R','H'))
);

-- reviews -> products.rating_average / rating_count (approved reviews only)
CREATE OR REPLACE FUNCTION fn_sync_product_rating()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_product_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN v_product_id := OLD.product_id; ELSE v_product_id := NEW.product_id; END IF;
    UPDATE products p
       SET rating_count   = s.cnt,
           rating_average = s.avg_rating
      FROM (SELECT COUNT(*)::INTEGER AS cnt,
                   COALESCE(ROUND(AVG(rating), 2), 0) AS avg_rating
              FROM reviews WHERE product_id = v_product_id AND status = 'A') s
     WHERE p.product_id = v_product_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_reviews_sync_rating AFTER INSERT OR DELETE OR UPDATE OF rating, status ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_sync_product_rating();
