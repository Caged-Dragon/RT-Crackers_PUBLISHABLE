-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/014_U13_Wishlist_protection.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U13 Wishlist protection
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 13 - WISHLIST PROTECTION
-- wishlist_items has no user_id (adding one would break BCNF), so UNIQUE (user_id, product_id) is
-- enforced by a trigger: a product can appear only once across all of a user's wishlists.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_wishlist_item_unique_per_user()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_user_id BIGINT;
BEGIN
    SELECT user_id INTO v_user_id FROM wishlists WHERE wishlist_id = NEW.wishlist_id;
    PERFORM pg_advisory_xact_lock(hashtextextended('wishlist_items:' || v_user_id::TEXT, 0));
    IF EXISTS (SELECT 1
                 FROM wishlist_items wi
                 JOIN wishlists w ON w.wishlist_id = wi.wishlist_id
                WHERE w.user_id = v_user_id
                  AND wi.product_id = NEW.product_id
                  AND wi.wishlist_id <> NEW.wishlist_id
                  AND NOT (TG_OP = 'UPDATE' AND wi.wishlist_id = OLD.wishlist_id AND wi.product_id = OLD.product_id))
    THEN
        RAISE EXCEPTION 'Product % is already in another wishlist of user %', NEW.product_id, v_user_id
            USING ERRCODE = 'unique_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_wishlist_items_unique_per_user BEFORE INSERT OR UPDATE OF wishlist_id, product_id ON wishlist_items
    FOR EACH ROW EXECUTE FUNCTION fn_wishlist_item_unique_per_user();

