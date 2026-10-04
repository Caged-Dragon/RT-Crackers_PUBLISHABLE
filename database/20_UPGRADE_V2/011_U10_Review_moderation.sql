-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/011_U10_Review_moderation.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U10 Review moderation system
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 10 - REVIEW MODERATION SYSTEM
-- verified_purchase, helpful_count, reported_count and the rating / counter checks already existed.
-- status is renamed moderation_status (single source of truth, P pending, A approved, R rejected, H hidden).
-- =====================================================================
ALTER TABLE reviews RENAME COLUMN status TO moderation_status;
ALTER TABLE reviews RENAME CONSTRAINT ck_reviews_status TO ck_reviews_moderation_status;
ALTER TABLE reviews
    ADD COLUMN moderated_by  INTEGER,
    ADD COLUMN moderated_at  TIMESTAMP;

UPDATE reviews SET moderated_at = updated_at WHERE moderation_status <> 'P';

ALTER TABLE reviews
    ADD CONSTRAINT fk_reviews_moderated_by FOREIGN KEY (moderated_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    ADD CONSTRAINT ck_reviews_moderation_stamp CHECK ((moderation_status = 'P') = (moderated_at IS NULL));
CREATE INDEX idx_reviews_moderated_by ON reviews (moderated_by) WHERE moderated_by IS NOT NULL;

-- the rating cache reads the renamed column
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
              FROM reviews WHERE product_id = v_product_id AND moderation_status = 'A' AND NOT is_deleted) s
     WHERE p.product_id = v_product_id;
    RETURN NULL;
END;
$$;
-- also re-run the cache when a review is soft deleted / restored
DROP TRIGGER trg_reviews_sync_rating ON reviews;
CREATE TRIGGER trg_reviews_sync_rating AFTER INSERT OR DELETE OR UPDATE OF rating, moderation_status, is_deleted ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_sync_product_rating();

-- stamp moderator and time automatically so the pending/moderated check always holds
CREATE OR REPLACE FUNCTION fn_review_moderation_stamp()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.moderation_status = 'P' THEN
        NEW.moderated_at := NULL;
        NEW.moderated_by := NULL;
    ELSIF TG_OP = 'INSERT' OR NEW.moderation_status IS DISTINCT FROM OLD.moderation_status THEN
        NEW.moderated_at := COALESCE(NEW.moderated_at, CURRENT_TIMESTAMP);
        NEW.moderated_by := COALESCE(NEW.moderated_by, NULLIF(current_setting('app.current_admin_id', TRUE), '')::INTEGER);
    ELSIF NEW.moderated_at IS NULL THEN
        NEW.moderated_at := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_reviews_moderation_stamp BEFORE INSERT OR UPDATE ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_review_moderation_stamp();

