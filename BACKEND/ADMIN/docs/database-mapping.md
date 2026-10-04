# Database mapping

The supplied RTCrackers database is treated as the source of truth. Existing business tables are reused rather than recreated:

| Admin module | Existing tables |
|---|---|
| Auth | users, admins, sessions, refresh_tokens, password_reset_tokens, login_history |
| Admin users | users, admins, admin_roles, admin_permissions |
| Roles | roles, admin_roles, role_permissions |
| Permissions | permissions, role_permissions, admin_permissions |
| Products | products, product_images, product_variants, product_attributes |
| Categories | categories, subcategories |
| Inventory | inventory, inventory_movements, inventory stock triggers |
| Orders | orders, order_items, order_status_history, invoices, refunds |
| Customers | users plus customer order relationships |
| Coupons | coupons, coupon_usage |
| Banners | banners, festival_banners |
| Newsletters | newsletters, newsletter_subscribers |
| Shipping | shipping_methods, zone_shipping_rates |
| Delivery | delivery_zones, pincodes, shipments |
| Settings | settings, system_configurations |
| Analytics | existing order/product/customer analytics tables plus live aggregates |
| Reports | existing sales/order/inventory data plus live aggregates |
| Audit | admin_activity_logs, audit_logs, login_history, product_audit_logs, inventory_movements, order_status_history |

New tables are limited to CMS storage: `cms_pages`, `cms_home_sections`, `cms_menus`, `cms_menu_items`, `cms_footer_links`, `cms_faqs`, and `cms_policies`.
