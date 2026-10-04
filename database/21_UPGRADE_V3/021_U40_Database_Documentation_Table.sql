-- RT CRACKERS | 21_UPGRADE_V3/021_U40_Database_Documentation_Table.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 40 - DATABASE DOCUMENTATION TABLE
-- database_metadata: one row per table - what it is for, who owns it, which module it belongs to.
--   * seeded for every table that exists after this upgrade
--   * description defaults to the table's COMMENT when it has one, otherwise to the business purpose
--   * the owner column holds a team name, not a person: change it to match your organisation
--   * fn_refresh_database_metadata() adds a placeholder row for any table created later;
--     v_undocumented_tables lists tables that still have none, v_stale_metadata lists rows whose table was dropped
-- =====================================================================
CREATE TABLE database_metadata (
    metadata_id       INTEGER       GENERATED ALWAYS AS IDENTITY,
    table_name        VARCHAR(63)   NOT NULL,
    business_purpose  VARCHAR(255)  NOT NULL,
    owner             VARCHAR(80)   NOT NULL,
    module            VARCHAR(40)   NOT NULL,
    description       TEXT          NOT NULL,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_database_metadata PRIMARY KEY (metadata_id),
    CONSTRAINT uq_database_metadata_table UNIQUE (table_name),
    CONSTRAINT ck_database_metadata_purpose CHECK (BTRIM(business_purpose) <> ''),
    CONSTRAINT ck_database_metadata_module CHECK (module ~ '^[A-Z_]+$')
);
CREATE INDEX idx_database_metadata_module ON database_metadata (module);
COMMENT ON TABLE database_metadata IS 'Self-documenting database: purpose, owner and module of every table.';

INSERT INTO database_metadata (table_name, module, owner, business_purpose, description)
SELECT v.table_name, v.module, v.owner, v.purpose, COALESCE(obj_description(to_regclass('public.' || v.table_name), 'pg_class'), v.purpose)
FROM (VALUES
    ('users', 'AUTHENTICATION', 'Security & Access', 'Customer accounts: login identity, contact details and status'),
    ('user_profiles', 'AUTHENTICATION', 'Security & Access', 'Extra personal details for each customer account'),
    ('roles', 'AUTHENTICATION', 'Security & Access', 'Named access roles (customer, staff, admin)'),
    ('permissions', 'AUTHENTICATION', 'Security & Access', 'Individual permissions that roles can be granted'),
    ('role_permissions', 'AUTHENTICATION', 'Security & Access', 'Which permissions each role holds'),
    ('user_roles', 'AUTHENTICATION', 'Security & Access', 'Which roles each user has'),
    ('sessions', 'AUTHENTICATION', 'Security & Access', 'Active and past login sessions'),
    ('refresh_tokens', 'AUTHENTICATION', 'Security & Access', 'Long-lived tokens used to renew login sessions'),
    ('login_history', 'AUTHENTICATION', 'Security & Access', 'Every sign-in attempt with outcome and device'),
    ('password_reset_tokens', 'AUTHENTICATION', 'Security & Access', 'One-time tokens for password recovery'),
    ('user_status_master', 'AUTHENTICATION', 'Security & Access', 'Lookup of account statuses (active, blocked, ...)'),
    ('genders', 'AUTHENTICATION', 'Security & Access', 'Lookup of gender values for user profiles'),
    ('admins', 'ADMIN', 'Security & Access', 'Back-office staff accounts'),
    ('admin_roles', 'ADMIN', 'Security & Access', 'Roles available to back-office staff'),
    ('admin_permissions', 'ADMIN', 'Security & Access', 'Permissions granted to back-office roles'),
    ('admin_activity_logs', 'ADMIN', 'Security & Access', 'What each admin did in the back office'),
    ('admin_notifications', 'ADMIN', 'Security & Access', 'Alerts shown to back-office staff'),
    ('countries', 'GEOGRAPHY', 'Data Management', 'Countries the store can serve'),
    ('states', 'GEOGRAPHY', 'Data Management', 'States / provinces within a country'),
    ('districts', 'GEOGRAPHY', 'Data Management', 'Districts within a state'),
    ('cities', 'GEOGRAPHY', 'Data Management', 'Cities and towns within a district'),
    ('postal_codes', 'GEOGRAPHY', 'Data Management', 'Postal (PIN) codes with their city and delivery coverage'),
    ('address_types', 'GEOGRAPHY', 'Data Management', 'Lookup of address labels (home, office, warehouse, other)'),
    ('country_configurations', 'GEOGRAPHY', 'Data Management', 'Per-country currency, tax rate, phone and postal rules'),
    ('addresses', 'CUSTOMERS', 'Customer Experience', 'Customer delivery and billing addresses'),
    ('saved_addresses', 'CUSTOMERS', 'Customer Experience', 'Addresses a customer has bookmarked for reuse'),
    ('recently_viewed_products', 'CUSTOMERS', 'Customer Experience', 'Products a customer looked at recently'),
    ('categories', 'MASTER_DATA', 'Catalogue Team', 'Top-level product categories'),
    ('subcategories', 'MASTER_DATA', 'Catalogue Team', 'Second-level product categories'),
    ('brands', 'MASTER_DATA', 'Catalogue Team', 'Product brands'),
    ('product_attributes', 'MASTER_DATA', 'Catalogue Team', 'Attribute definitions such as colour, size, shots'),
    ('attribute_values', 'MASTER_DATA', 'Catalogue Team', 'Allowed values for each product attribute'),
    ('product_types', 'MASTER_DATA', 'Catalogue Team', 'Lookup of product types used for filtering'),
    ('collections', 'MASTER_DATA', 'Catalogue Team', 'Curated product collections'),
    ('seasons', 'MASTER_DATA', 'Catalogue Team', 'Seasonal groupings such as Diwali or New Year'),
    ('reference_data', 'MASTER_DATA', 'Catalogue Team', 'Central lookup values (languages, currencies, device types, ...)'),
    ('products', 'PRODUCTS', 'Catalogue Team', 'The product catalogue: price, stock, SKU and descriptive data'),
    ('product_images', 'PRODUCTS', 'Catalogue Team', 'Images attached to products'),
    ('product_variants', 'PRODUCTS', 'Catalogue Team', 'Sellable variants of a product (pack size, colour)'),
    ('product_seo', 'PRODUCTS', 'Catalogue Team', 'Search-engine titles, descriptions and slugs for products'),
    ('product_audit_logs', 'PRODUCTS', 'Catalogue Team', 'History of changes made to products'),
    ('product_collections', 'PRODUCTS', 'Catalogue Team', 'Links products to collections'),
    ('product_seasons', 'PRODUCTS', 'Catalogue Team', 'Links products to seasons'),
    ('inventory', 'INVENTORY', 'Warehouse & Inventory', 'Current stock level per product or variant'),
    ('inventory_movements', 'INVENTORY', 'Warehouse & Inventory', 'Every stock-in, stock-out and adjustment'),
    ('carts', 'CART', 'Customer Experience', 'Shopping carts, one per customer or guest session'),
    ('cart_items', 'CART', 'Customer Experience', 'Lines inside a shopping cart'),
    ('cart_abandonment_logs', 'CART', 'Customer Experience', 'Carts left without checkout, for follow-up'),
    ('wishlists', 'WISHLIST', 'Customer Experience', 'Customer wishlists'),
    ('wishlist_items', 'WISHLIST', 'Customer Experience', 'Products saved in a wishlist'),
    ('comparisons', 'COMPARISON', 'Customer Experience', 'Product comparison sessions'),
    ('comparison_items', 'COMPARISON', 'Customer Experience', 'Products placed in a comparison'),
    ('orders', 'ORDERS', 'Order Management', 'Customer orders with totals, addresses and current status'),
    ('order_items', 'ORDERS', 'Order Management', 'Product lines of each order'),
    ('order_status_history', 'ORDERS', 'Order Management', 'Every status change an order went through'),
    ('order_tracking_events', 'ORDERS', 'Order Management', 'Tracking milestones shown to the customer'),
    ('invoices', 'ORDERS', 'Order Management', 'Tax invoices issued for orders'),
    ('return_requests', 'ORDERS', 'Order Management', 'Customer requests to return items'),
    ('replacement_requests', 'ORDERS', 'Order Management', 'Customer requests to replace items'),
    ('order_status_master', 'ORDERS', 'Order Management', 'Lookup of order statuses'),
    ('payment_methods', 'PAYMENTS', 'Finance', 'Accepted payment methods'),
    ('cod_transactions', 'PAYMENTS', 'Finance', 'Cash-on-delivery payment records'),
    ('cash_collection_logs', 'PAYMENTS', 'Finance', 'Cash handed over by delivery agents'),
    ('refunds', 'PAYMENTS', 'Finance', 'Refunds issued to customers'),
    ('payment_status_master', 'PAYMENTS', 'Finance', 'Lookup of payment statuses'),
    ('delivery_zones', 'SHIPPING', 'Logistics', 'Delivery zones and their coverage'),
    ('shipping_methods', 'SHIPPING', 'Logistics', 'Available shipping options'),
    ('shipments', 'SHIPPING', 'Logistics', 'Shipments created for orders'),
    ('zone_shipping_rates', 'SHIPPING', 'Logistics', 'Shipping charges by zone and method'),
    ('shipment_status_master', 'SHIPPING', 'Logistics', 'Lookup of shipment statuses'),
    ('reviews', 'REVIEWS', 'Customer Experience', 'Customer product reviews and ratings'),
    ('review_images', 'REVIEWS', 'Customer Experience', 'Photos attached to reviews'),
    ('review_reports', 'REVIEWS', 'Customer Experience', 'Customer reports of inappropriate reviews'),
    ('review_status_master', 'REVIEWS', 'Customer Experience', 'Lookup of review moderation statuses'),
    ('coupons', 'MARKETING', 'Marketing', 'Discount coupons and their rules'),
    ('coupon_usage', 'MARKETING', 'Marketing', 'Every redemption of a coupon'),
    ('banners', 'MARKETING', 'Marketing', 'Homepage and promotional banners'),
    ('newsletters', 'MARKETING', 'Marketing', 'Newsletters prepared for sending'),
    ('newsletter_subscribers', 'MARKETING', 'Marketing', 'People subscribed to the newsletter'),
    ('referral_rewards', 'MARKETING', 'Marketing', 'Rewards earned through referral codes'),
    ('notifications', 'NOTIFICATIONS', 'Customer Experience', 'Notification messages defined by the business'),
    ('user_notifications', 'NOTIFICATIONS', 'Customer Experience', 'Notifications delivered to each user'),
    ('email_templates', 'NOTIFICATIONS', 'Customer Experience', 'Reusable e-mail templates'),
    ('festivals', 'FESTIVALS', 'Marketing', 'Festival campaigns and their dates'),
    ('festival_products', 'FESTIVALS', 'Marketing', 'Products featured in a festival'),
    ('festival_banners', 'FESTIVALS', 'Marketing', 'Banners shown during a festival'),
    ('festival_discounts', 'FESTIVALS', 'Marketing', 'Discounts that apply during a festival'),
    ('page_views', 'ANALYTICS', 'Analytics', 'Website page view events'),
    ('product_views', 'ANALYTICS', 'Analytics', 'Product page view events'),
    ('search_logs', 'ANALYTICS', 'Analytics', 'What customers searched for and what they found'),
    ('sales_reports', 'ANALYTICS', 'Analytics', 'Pre-aggregated sales figures'),
    ('user_activity_logs', 'ANALYTICS', 'Analytics', 'Customer activity trail for analysis'),
    ('dashboard_metrics', 'ANALYTICS', 'Analytics', 'Metrics shown on the admin dashboard'),
    ('revenue_analytics', 'ANALYTICS', 'Analytics', 'Revenue broken down by period and dimension'),
    ('product_analytics', 'ANALYTICS', 'Analytics', 'Per-product performance figures'),
    ('customer_analytics', 'ANALYTICS', 'Analytics', 'Per-customer behaviour figures'),
    ('conversion_analytics', 'ANALYTICS', 'Analytics', 'Funnel and conversion figures'),
    ('settings', 'SYSTEM', 'Platform Engineering', 'General store settings'),
    ('feature_flags', 'SYSTEM', 'Platform Engineering', 'Switches that turn features on or off'),
    ('system_configurations', 'SYSTEM', 'Platform Engineering', 'Typed application configuration (store name, support contact, GST number, URLs)'),
    ('error_logs', 'SYSTEM', 'Platform Engineering', 'Application and database errors'),
    ('audit_logs', 'SYSTEM', 'Platform Engineering', 'Row-level change history with user, session and device'),
    ('business_rules', 'SYSTEM', 'Platform Engineering', 'Business limits and periods kept as data (cart size, return days, ...)'),
    ('system_health_checks', 'SYSTEM', 'Platform Engineering', 'Periodic CPU, memory, size and session readings'),
    ('business_code_definitions', 'GOVERNANCE', 'Data Management', 'Format of every business code (PRD, ORD, INV, RET, CPN, ...)'),
    ('business_code_counters', 'GOVERNANCE', 'Data Management', 'Last number issued for each business code and year'),
    ('schema_versions', 'GOVERNANCE', 'Data Management', 'Which upgrade scripts have been applied'),
    ('data_retention_policies', 'GOVERNANCE', 'Data Management', 'How long each kind of data is kept and when it is archived'),
    ('archive_runs', 'GOVERNANCE', 'Data Management', 'Log of each archive job and how many rows it moved'),
    ('archived_orders', 'GOVERNANCE', 'Data Management', 'Old orders moved out of the active table'),
    ('archived_logs', 'GOVERNANCE', 'Data Management', 'Old log rows moved out of the active tables'),
    ('archived_notifications', 'GOVERNANCE', 'Data Management', 'Old notifications moved out of the active table'),
    ('search_keywords', 'GOVERNANCE', 'Data Management', 'Keywords that drive search suggestions and ranking'),
    ('search_synonyms', 'GOVERNANCE', 'Data Management', 'Words treated as equivalent in search'),
    ('search_redirects', 'GOVERNANCE', 'Data Management', 'Search terms that jump straight to a page'),
    ('data_quality_rules', 'GOVERNANCE', 'Data Management', 'Validation rules used to detect invalid data'),
    ('data_quality_results', 'GOVERNANCE', 'Data Management', 'Outcome of each data quality run'),
    ('data_classification', 'GOVERNANCE', 'Data Management', 'Sensitivity levels: PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED'),
    ('data_classification_assignments', 'GOVERNANCE', 'Data Management', 'Sensitivity level assigned to each table or column'),
    ('entity_versions', 'GOVERNANCE', 'Data Management', 'Version history of master data rows'),
    ('documents', 'GOVERNANCE', 'Data Management', 'Manuals, certificates and other files'),
    ('document_types', 'GOVERNANCE', 'Data Management', 'Lookup of document kinds'),
    ('document_links', 'GOVERNANCE', 'Data Management', 'Links documents to products or other records'),
    ('database_metadata', 'GOVERNANCE', 'Data Management', 'This catalogue: what each table is for, who owns it, which module it belongs to')
) AS v(table_name, module, owner, purpose);

CREATE OR REPLACE FUNCTION fn_refresh_database_metadata()
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_added INTEGER;
BEGIN
    INSERT INTO database_metadata (table_name, business_purpose, owner, module, description)
    SELECT t.tablename, 'To be documented', 'Unassigned', 'UNASSIGNED',
           COALESCE(obj_description(format('public.%I', t.tablename)::regclass, 'pg_class'), 'To be documented')
      FROM pg_tables t
     WHERE t.schemaname = 'public' AND NOT EXISTS (SELECT 1 FROM database_metadata m WHERE m.table_name = t.tablename);
    GET DIAGNOSTICS v_added = ROW_COUNT;
    RETURN v_added;
END;
$$;

CREATE VIEW v_undocumented_tables WITH (security_invoker = true) AS
SELECT t.tablename AS table_name
  FROM pg_tables t
 WHERE t.schemaname = 'public'
   AND NOT EXISTS (SELECT 1 FROM database_metadata m WHERE m.table_name = t.tablename AND m.module <> 'UNASSIGNED');

CREATE VIEW v_stale_metadata WITH (security_invoker = true) AS
SELECT m.table_name, m.module
  FROM database_metadata m
 WHERE to_regclass(format('public.%I', m.table_name)) IS NULL;
