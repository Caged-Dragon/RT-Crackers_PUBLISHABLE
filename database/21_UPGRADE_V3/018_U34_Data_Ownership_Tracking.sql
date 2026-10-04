-- RT CRACKERS | 21_UPGRADE_V3/018_U34_Data_Ownership_Tracking.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 34 - DATA OWNERSHIP TRACKING
-- created_by / updated_by on the major tables, stamped by trigger from the session setting the
-- application already sets for auditing:  SET LOCAL app.current_user_id = '<users.user_id>';
--   * new columns point at users (same convention as deleted_by from U4)
--   * tables that already had admin-based created_by / updated_by (coupons, banners, newsletters,
--     notifications, settings) keep pointing at admins and are stamped from app.current_admin_id
-- created_by never changes after insert. updated_by changes only when the session identifies a user.
-- Foreign keys on these columns are intentionally not indexed (low selectivity, never filtered on).
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_stamp_owner_user()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_uid BIGINT := NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.created_by := COALESCE(NEW.created_by, v_uid);
        NEW.updated_by := COALESCE(NEW.updated_by, v_uid);
    ELSE
        NEW.created_by := OLD.created_by;
        IF v_uid IS NOT NULL THEN NEW.updated_by := v_uid; END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_stamp_owner_admin()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_aid INTEGER := NULLIF(current_setting('app.current_admin_id', TRUE), '')::INTEGER;
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.created_by := COALESCE(NEW.created_by, v_aid);
        NEW.updated_by := COALESCE(NEW.updated_by, v_aid);
    ELSE
        NEW.created_by := OLD.created_by;
        IF v_aid IS NOT NULL THEN NEW.updated_by := v_aid; END IF;
    END IF;
    RETURN NEW;
END;
$$;

DO $$
DECLARE
    t    TEXT;
    c    TEXT;
BEGIN
    -- users-based ownership
    FOREACH t IN ARRAY ARRAY[
        'users','products','product_variants','product_images','product_seo','categories','subcategories','brands','inventory',
        'orders','invoices','return_requests','replacement_requests','refunds','shipments','reviews','addresses','festivals',
        'delivery_zones','shipping_methods','payment_methods','feature_flags','system_configurations','roles','permissions',
        'business_rules','country_configurations','data_retention_policies','data_quality_rules','reference_data','product_types',
        'collections','seasons','search_synonyms','search_redirects','documents','document_types','data_classification',
        'data_classification_assignments'] LOOP
        FOREACH c IN ARRAY ARRAY['created_by','updated_by'] LOOP
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = c) THEN
                EXECUTE format('ALTER TABLE %I ADD COLUMN %I BIGINT', t, c);
                EXECUTE format('ALTER TABLE %I ADD CONSTRAINT fk_%s_%s FOREIGN KEY (%I) REFERENCES users (user_id) ON DELETE SET NULL', t, t, c, c);
            END IF;
        END LOOP;
        EXECUTE format('CREATE TRIGGER trg_%1$s_owner BEFORE INSERT OR UPDATE ON %1$I FOR EACH ROW EXECUTE FUNCTION fn_stamp_owner_user()', t);
    END LOOP;

    -- admin-based ownership (these tables already had admin-typed columns)
    FOREACH t IN ARRAY ARRAY['coupons','banners','newsletters','notifications','settings'] LOOP
        FOREACH c IN ARRAY ARRAY['created_by','updated_by'] LOOP
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = c) THEN
                EXECUTE format('ALTER TABLE %I ADD COLUMN %I INTEGER', t, c);
                EXECUTE format('ALTER TABLE %I ADD CONSTRAINT fk_%s_%s FOREIGN KEY (%I) REFERENCES admins (admin_id) ON DELETE SET NULL', t, t, c, c);
            END IF;
        END LOOP;
        EXECUTE format('CREATE TRIGGER trg_%1$s_owner BEFORE INSERT OR UPDATE ON %1$I FOR EACH ROW EXECUTE FUNCTION fn_stamp_owner_admin()', t);
    END LOOP;
END;
$$;
