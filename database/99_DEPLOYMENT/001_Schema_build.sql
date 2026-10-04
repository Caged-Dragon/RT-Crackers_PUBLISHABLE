-- =====================================================================
-- RT CRACKERS | 99_DEPLOYMENT/001_Schema_build.sql
-- Source: rt_crackers_schema.sql (split by module) | master build script (psql)
-- =====================================================================


-- Run from the database root folder:   psql "$DATABASE_URL" -f 99_DEPLOYMENT/001_Schema_build.sql
-- (\i is a psql command; for the Supabase SQL editor use build/rt_crackers_full.sql instead.)
-- File order below is DEPENDENCY order (not folder order): e.g. shipping lookups and
-- payment_methods must exist before orders; audit_logs after the tables it watches.

\set ON_ERROR_STOP on

BEGIN;

\i 00_SETUP/002_Sequences.sql
\i 00_SETUP/003_Helper_functions.sql
\i 01_AUTHENTICATION/001_Roles.sql
\i 01_AUTHENTICATION/002_Permissions.sql
\i 01_AUTHENTICATION/003_Role_permissions.sql
\i 01_AUTHENTICATION/004_Users.sql
\i 01_AUTHENTICATION/005_User_profiles.sql
\i 01_AUTHENTICATION/006_User_roles.sql
\i 01_AUTHENTICATION/007_Sessions.sql
\i 01_AUTHENTICATION/008_Refresh_tokens.sql
\i 01_AUTHENTICATION/009_Login_history.sql
\i 01_AUTHENTICATION/010_Password_reset_tokens.sql
\i 02_ADMIN/001_Admins.sql
\i 02_ADMIN/002_Admin_roles.sql
\i 02_ADMIN/003_Admin_permissions.sql
\i 02_ADMIN/004_Admin_activity_logs.sql
\i 02_ADMIN/005_Admin_notifications.sql
\i 12_SHIPPING/001_Delivery_zones.sql
\i 12_SHIPPING/002_Pincodes.sql
\i 12_SHIPPING/003_Shipping_methods.sql
\i 12_SHIPPING/009_Zone_shipping_rates.sql
\i 06_CUSTOMERS/001_Addresses.sql
\i 03_MASTER_DATA/001_Categories.sql
\i 03_MASTER_DATA/002_Subcategories.sql
\i 03_MASTER_DATA/003_Brands.sql
\i 04_PRODUCTS/001_Products.sql
\i 04_PRODUCTS/002_Product_images.sql
\i 04_PRODUCTS/003_Product_variants.sql
\i 03_MASTER_DATA/004_Product_attributes.sql
\i 03_MASTER_DATA/005_Attribute_values.sql
\i 05_INVENTORY/001_Inventory.sql
\i 05_INVENTORY/002_Inventory_movements.sql
\i 14_MARKETING/001_Coupons.sql
\i 14_MARKETING/003_Banners.sql
\i 14_MARKETING/004_Newsletters.sql
\i 14_MARKETING/005_Newsletter_subscribers.sql
\i 07_CART/001_Carts.sql
\i 07_CART/002_Cart_items.sql
\i 08_WISHLIST/001_Wishlists.sql
\i 08_WISHLIST/002_Wishlist_items.sql
\i 09_COMPARISON/001_Comparisons.sql
\i 09_COMPARISON/002_Comparison_items.sql
\i 06_CUSTOMERS/002_Saved_addresses.sql
\i 06_CUSTOMERS/004_Recently_viewed_products.sql
\i 11_PAYMENTS/001_Payment_methods.sql
\i 10_ORDERS/001_Orders.sql
\i 10_ORDERS/002_Order_items.sql
\i 10_ORDERS/003_Order_status_history.sql
\i 10_ORDERS/006_Invoices.sql
\i 10_ORDERS/007_Return_requests.sql
\i 10_ORDERS/008_Replacement_requests.sql
\i 11_PAYMENTS/002_Cod_transactions.sql
\i 11_PAYMENTS/004_Refunds.sql
\i 11_PAYMENTS/003_Cash_collection_logs.sql
\i 12_SHIPPING/004_Shipments.sql
\i 13_REVIEWS/001_Reviews.sql
\i 13_REVIEWS/002_Review_images.sql
\i 13_REVIEWS/003_Review_reports.sql
\i 14_MARKETING/002_Coupon_usage.sql
\i 14_MARKETING/006_Referral_rewards.sql
\i 15_NOTIFICATIONS/003_Email_templates.sql
\i 15_NOTIFICATIONS/001_Notifications.sql
\i 15_NOTIFICATIONS/002_User_notifications.sql
\i 16_FESTIVALS/001_Festivals.sql
\i 16_FESTIVALS/002_Festival_products.sql
\i 16_FESTIVALS/003_Festival_banners.sql
\i 16_FESTIVALS/004_Festival_discounts.sql
\i 17_ANALYTICS/001_Page_views.sql
\i 17_ANALYTICS/002_Product_views.sql
\i 17_ANALYTICS/003_Search_logs.sql
\i 17_ANALYTICS/004_Sales_reports.sql
\i 17_ANALYTICS/005_User_activity_logs.sql
\i 18_SYSTEM/001_Settings.sql
\i 18_SYSTEM/003_System_configurations.sql
\i 18_SYSTEM/002_Feature_flags.sql
\i 18_SYSTEM/005_Audit_logs.sql
\i 18_SYSTEM/004_Error_logs.sql
\i 19_INDEXES/001_Authentication_indexes.sql
\i 19_INDEXES/002_Product_indexes.sql
\i 19_INDEXES/003_Order_indexes.sql
\i 19_INDEXES/004_Inventory_indexes.sql
\i 19_INDEXES/005_Analytics_indexes.sql
\i 19_INDEXES/006_System_indexes.sql

-- updated_at triggers: must run after every table exists
-- updated_at maintenance on every table that has the column
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT c.table_name
        FROM information_schema.columns c
        JOIN information_schema.tables t
          ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
        WHERE c.table_schema = 'public' AND c.column_name = 'updated_at'
    LOOP
        EXECUTE format('CREATE TRIGGER trg_%1$s_updated_at BEFORE UPDATE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()', r.table_name);
    END LOOP;
END;
$$;

-- RLS: must run after every table exists
-- =====================================================================
-- 20. SUPABASE: ROW LEVEL SECURITY (deny by default)
-- Every table in public is exposed through the Supabase API, so RLS is
-- enabled with no policies: only the service-role key (your backend)
-- can read/write until you add explicit policies.
-- =====================================================================

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.tablename);
    END LOOP;
END;
$$;

COMMIT;
