-- =====================================================================
-- RT CRACKERS | 99_DEPLOYMENT/002_Master_seed_data.sql
-- Source: rt_crackers_schema.sql (split by module) | minimal reference rows
-- =====================================================================

BEGIN;

INSERT INTO roles (role_code, role_name, role_scope, description, is_system) VALUES
    ('CUSTOMER',       'Customer',        'U', 'Registered shopper',                 TRUE),
    ('SUPER_ADMIN',    'Super Admin',     'A', 'Full access to every module',        TRUE),
    ('STORE_MANAGER',  'Store Manager',   'A', 'Catalogue, orders and inventory',    TRUE),
    ('DELIVERY_AGENT', 'Delivery Agent',  'A', 'Delivers orders and collects cash',  TRUE),
    ('SUPPORT_AGENT',  'Support Agent',   'A', 'Handles returns and reviews',        TRUE);

INSERT INTO permissions (permission_code, module_name, description) VALUES
    ('PRODUCT.MANAGE',   'product',   'Create and edit products'),
    ('INVENTORY.MANAGE', 'inventory', 'Adjust stock'),
    ('ORDER.MANAGE',     'order',     'View and update orders'),
    ('COD.COLLECT',      'payment',   'Record COD collection'),
    ('COD.RECONCILE',    'payment',   'Verify cash hand-over'),
    ('REFUND.APPROVE',   'payment',   'Approve refunds'),
    ('REVIEW.MODERATE',  'review',    'Moderate reviews'),
    ('MARKETING.MANAGE', 'marketing', 'Coupons, banners, festivals'),
    ('SETTINGS.MANAGE',  'system',    'Edit settings and feature flags');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM roles r CROSS JOIN permissions p WHERE r.role_code = 'SUPER_ADMIN';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM roles r JOIN permissions p
  ON p.permission_code IN ('PRODUCT.MANAGE','INVENTORY.MANAGE','ORDER.MANAGE','COD.RECONCILE','MARKETING.MANAGE')
WHERE r.role_code = 'STORE_MANAGER';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM roles r JOIN permissions p ON p.permission_code = 'COD.COLLECT'
WHERE r.role_code = 'DELIVERY_AGENT';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM roles r JOIN permissions p ON p.permission_code IN ('REVIEW.MODERATE','REFUND.APPROVE')
WHERE r.role_code = 'SUPPORT_AGENT';

INSERT INTO payment_methods (method_code, method_name, description, min_order_amount, max_order_amount)
VALUES ('COD', 'Cash On Delivery', 'Pay in cash when the order is delivered', 0, 50000);

INSERT INTO shipping_methods (method_code, method_name, description, min_delivery_days, max_delivery_days) VALUES
    ('STD', 'Standard Delivery', 'Regular road delivery', 3, 7),
    ('EXP', 'Express Delivery',  'Priority dispatch',     1, 3);

INSERT INTO settings (setting_key, setting_value, value_type, description, is_public) VALUES
    ('store_name',            'RT Crackers', 'S', 'Public store name',                    TRUE),
    ('store_currency',        'INR',         'S', 'Store currency',                       TRUE),
    ('cod_enabled',           'true',        'B', 'Master switch for Cash On Delivery',   TRUE),
    ('min_order_amount',      '500',         'N', 'Minimum order value',                  TRUE),
    ('allow_guest_checkout',  'false',       'B', 'Guests cannot place COD orders',       FALSE);

INSERT INTO feature_flags (flag_key, description, is_enabled) VALUES
    ('wishlist',           'Wishlist feature',            TRUE),
    ('product_comparison', 'Product comparison feature',  TRUE),
    ('referral_program',   'Referral rewards',            FALSE),
    ('festival_mode',      'Festival landing pages',      FALSE);

COMMIT;
