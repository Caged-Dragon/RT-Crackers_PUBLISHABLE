-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/019_Supporting_indexes_and_comments.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | Supporting indexes + table comments
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- SUPPORTING INDEXES for the new foreign keys / filters
-- =====================================================================
CREATE INDEX idx_products_not_deleted  ON products (category_id) WHERE NOT is_deleted;
CREATE INDEX idx_orders_not_deleted    ON orders (user_id, created_at DESC) WHERE NOT is_deleted;
CREATE INDEX idx_users_security_lock   ON users (account_locked_until) WHERE account_locked;
CREATE INDEX idx_reviews_not_deleted   ON reviews (product_id) WHERE NOT is_deleted AND moderation_status = 'A';

-- =====================================================================
-- TABLE COMMENTS (relationship map for the new tables)
-- =====================================================================
COMMENT ON TABLE countries              IS 'Geography root. 1:N states';
COMMENT ON TABLE states                 IS 'N:1 countries, 1:N districts';
COMMENT ON TABLE districts              IS 'N:1 states, 1:N cities';
COMMENT ON TABLE cities                 IS 'N:1 districts, 1:N postal_codes';
COMMENT ON TABLE postal_codes           IS 'N:1 cities, N:1 delivery_zones, 1:N addresses. Replaces pincodes';
COMMENT ON TABLE product_seo            IS '1:1 products. SEO / social metadata';
COMMENT ON TABLE product_audit_logs     IS 'N:1 products, N:1 users. One row per changed product field';
COMMENT ON TABLE order_tracking_events  IS 'N:1 orders, N:1 shipments (same order). Shipment milestones';
COMMENT ON TABLE dashboard_metrics      IS 'Pre-computed KPIs per period';
COMMENT ON TABLE revenue_analytics      IS 'Revenue per period, optionally per category';
COMMENT ON TABLE customer_analytics     IS '1:1 users. Segment and lifetime value';
COMMENT ON TABLE product_analytics      IS 'Daily per-product funnel';
COMMENT ON TABLE conversion_analytics   IS 'Daily store-wide funnel';
COMMENT ON TABLE cart_abandonment_logs  IS '1:1 carts. Abandonment, reminders, recovery';

