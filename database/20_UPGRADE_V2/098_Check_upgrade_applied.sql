-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/098_Check_upgrade_applied.sql
-- NOT part of the upgrade run. Read-only: run after deploying. Expect 20 rows, all PASS.
-- To list only failures, change the last line to:  ) AS t(check_name, ok) WHERE NOT ok;
-- =====================================================================

SELECT check_name, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS result
FROM (VALUES
 ('U1  geography tables + postal_codes FK on addresses',
    to_regclass('public.countries') IS NOT NULL AND to_regclass('public.cities') IS NOT NULL
    AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='addresses' AND column_name='postal_code_id')),
 ('U1  pincodes is now a compatibility view',
    EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname='pincodes')),
 ('U1  staging table removed', to_regclass('public.upg_v2_pin_city') IS NULL),
 ('U2  product_seo exists', to_regclass('public.product_seo') IS NOT NULL),
 ('U3  product_audit_logs + trigger',
    to_regclass('public.product_audit_logs') IS NOT NULL
    AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_products_field_audit')),
 ('U4  soft delete on users/products/orders/reviews',
    (SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND column_name='is_deleted'
       AND table_name IN ('users','products','orders','categories','subcategories','brands','coupons','reviews')) = 8),
 ('U5  users security columns',
    EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='mfa_secret')
    AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_users_security')),
 ('U6  inventory buckets + generated available_stock',
    EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='inventory' AND column_name='available_stock' AND is_generated='ALWAYS')),
 ('U7  order_tracking_events', to_regclass('public.order_tracking_events') IS NOT NULL),
 ('U8  addresses address_label', EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='addresses' AND column_name='address_label')),
 ('U9  analytics tables (6 new)',
    (SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename IN
       ('dashboard_metrics','revenue_analytics','customer_analytics','product_analytics','conversion_analytics','cart_abandonment_logs')) = 6),
 ('U10 reviews.moderation_status', EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='reviews' AND column_name='moderation_status')),
 ('U11 coupons.remaining_uses', EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='coupons' AND column_name='remaining_uses')),
 ('U13 wishlist unique trigger', EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_wishlist_items_unique_per_user')),
 ('U17 system_configurations.config_key unique', EXISTS (SELECT 1 FROM pg_constraint WHERE conname='uq_system_configurations_config_key')),
 ('U18 feature_flags.feature_name', EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='feature_flags' AND column_name='feature_name')),
 ('U19 error_logs.module_name', EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='error_logs' AND column_name='module_name')),
 ('U20 audit_logs.action_type + LOGIN trigger',
    EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='audit_logs' AND column_name='action_type')
    AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_login_history_effects')),
 ('RLS on every public table', NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='public' AND NOT rowsecurity)),
 ('No user triggers left disabled', NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
                                                WHERE n.nspname='public' AND NOT t.tgisinternal AND t.tgenabled='D'))
) AS t(check_name, ok);
