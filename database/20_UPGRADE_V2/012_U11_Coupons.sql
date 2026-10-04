-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/012_U11_Coupons.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U11 Advanced coupon management
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 11 - ADVANCED COUPON MANAGEMENT
-- Renamed to the spec names: min_order_amount -> minimum_order_amount,
-- max_discount_amount -> maximum_discount_amount, usage_limit_per_user -> per_user_limit,
-- valid_until -> valid_to. remaining_uses is NULL for unlimited coupons.
-- =====================================================================
ALTER TABLE coupons RENAME COLUMN min_order_amount     TO minimum_order_amount;
ALTER TABLE coupons RENAME COLUMN max_discount_amount  TO maximum_discount_amount;
ALTER TABLE coupons RENAME COLUMN usage_limit_per_user TO per_user_limit;
ALTER TABLE coupons RENAME COLUMN valid_until          TO valid_to;

ALTER TABLE coupons ADD COLUMN remaining_uses INTEGER;
UPDATE coupons c
   SET remaining_uses = GREATEST(c.usage_limit - (SELECT COUNT(*) FROM coupon_usage u WHERE u.coupon_id = c.coupon_id AND u.status = 'A'), 0)
 WHERE c.usage_limit IS NOT NULL;

ALTER TABLE coupons
    ADD CONSTRAINT ck_coupons_remaining_uses CHECK ((usage_limit IS NULL) = (remaining_uses IS NULL)
                                                    AND (remaining_uses IS NULL OR (remaining_uses >= 0 AND remaining_uses <= usage_limit)));

CREATE OR REPLACE FUNCTION fn_coupon_set_remaining()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.usage_limit IS NULL THEN
        NEW.remaining_uses := NULL;
    ELSE
        NEW.remaining_uses := NEW.usage_limit - (SELECT COUNT(*) FROM coupon_usage WHERE coupon_id = NEW.coupon_id AND status = 'A');
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_coupons_remaining BEFORE INSERT OR UPDATE OF usage_limit ON coupons
    FOR EACH ROW EXECUTE FUNCTION fn_coupon_set_remaining();

-- using a coupon more often than its limit raises a CHECK violation (remaining_uses >= 0)
CREATE OR REPLACE FUNCTION fn_coupon_usage_sync()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_coupon_id INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN v_coupon_id := OLD.coupon_id; ELSE v_coupon_id := NEW.coupon_id; END IF;
    UPDATE coupons
       SET remaining_uses = usage_limit - (SELECT COUNT(*) FROM coupon_usage WHERE coupon_id = v_coupon_id AND status = 'A')
     WHERE coupon_id = v_coupon_id AND usage_limit IS NOT NULL;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_coupon_usage_sync AFTER INSERT OR DELETE OR UPDATE OF status, coupon_id ON coupon_usage
    FOR EACH ROW EXECUTE FUNCTION fn_coupon_usage_sync();

