-- =====================================================================
-- RT CRACKERS | 13_REVIEWS/002_Review_images.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- review_images | Purpose: photos attached to a review.
-- Keys : PK(review_image_id) | CK/AK: (review_id, image_url)
-- Rel  : N:1 reviews
-- BCNF : attributes depend on the image row.
-- ---------------------------------------------------------------------
CREATE TABLE review_images (
    review_image_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    review_id        BIGINT        NOT NULL,
    image_url        VARCHAR(500)  NOT NULL,
    display_order    SMALLINT      NOT NULL DEFAULT 0,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_review_images PRIMARY KEY (review_image_id),
    CONSTRAINT uq_review_images_review_url UNIQUE (review_id, image_url),
    CONSTRAINT fk_review_images_review FOREIGN KEY (review_id) REFERENCES reviews (review_id) ON DELETE CASCADE
);
