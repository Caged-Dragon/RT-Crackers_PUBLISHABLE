-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/021_Verification.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | Verification (aborts and rolls back on any miss)
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- 21. VERIFICATION  (U14, U15, U16 plus structure checks). Any miss aborts and rolls back the upgrade.
-- =====================================================================
DO $$
DECLARE
    v_missing TEXT;
    v_tables  INTEGER;
    v_fks     INTEGER;
    v_cons    INTEGER;
    v_cols    INTEGER;
BEGIN
    SELECT string_agg(req.name, ', ') INTO v_missing
    FROM (VALUES
        -- U14 product validation
        ('ck_products_mrp'), ('ck_products_selling_price'), ('ck_products_cost_price'), ('ck_products_price_le_mrp'),
        ('ck_products_discount_pct'), ('ck_products_stock_qty'), ('ck_products_dimensions'), ('ck_products_gst'),
        -- U16 candidate keys
        ('uq_users_email'), ('uq_users_phone'), ('uq_products_sku'), ('uq_products_barcode'), ('uq_products_slug'),
        ('uq_orders_order_number'), ('uq_invoices_invoice_number'), ('uq_coupons_coupon_code'),
        -- U15 user validation
        ('ck_users_phone_length'), ('ck_users_email_not_empty'), ('ck_users_first_name_not_empty'), ('ck_users_last_name_not_empty'),
        -- U10 / U11 / U12 / U17
        ('ck_reviews_rating'), ('ck_reviews_counts'), ('ck_coupons_discount_pct'), ('ck_coupons_remaining_uses'),
        ('uq_system_configurations_config_key')
    ) AS req(name)
    WHERE NOT EXISTS (SELECT 1 FROM pg_constraint c WHERE c.conname = req.name);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Upgrade verification failed, missing constraints: %', v_missing;
    END IF;

    IF to_regclass('public.uq_cart_items_line') IS NULL THEN
        RAISE EXCEPTION 'Upgrade verification failed: cart duplicate protection (uq_cart_items_line) is missing';
    END IF;

    SELECT COUNT(*) INTO v_tables FROM pg_tables WHERE schemaname = 'public';
    SELECT COUNT(*) INTO v_fks    FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace WHERE n.nspname = 'public' AND c.contype = 'f';
    SELECT COUNT(*) INTO v_cons   FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace WHERE n.nspname = 'public' AND c.contype IN ('p','f','u','c');
    SELECT COUNT(*) INTO v_cols   FROM information_schema.columns WHERE table_schema = 'public'
                                     AND table_name IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public');
    RAISE NOTICE 'RT Crackers upgrade v2 OK: % tables, % columns, % foreign keys, % constraints (PK/FK/UNIQUE/CHECK)',
                 v_tables, v_cols, v_fks, v_cons;
END;
$$;

