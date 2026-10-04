-- =====================================================================
-- RT CRACKERS | 19_INDEXES/003_Order_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_pincodes_zone_id           ON pincodes (zone_id);
CREATE INDEX idx_addresses_user_id          ON addresses (user_id);
CREATE INDEX idx_addresses_postal_code      ON addresses (postal_code);
CREATE INDEX idx_coupons_active_valid       ON coupons (valid_until) WHERE is_active;
CREATE INDEX idx_cart_items_product         ON cart_items (product_id);
CREATE INDEX idx_wishlist_items_product     ON wishlist_items (product_id);
CREATE INDEX idx_orders_user_created        ON orders (user_id, created_at DESC);
CREATE INDEX idx_orders_status              ON orders (order_status, created_at DESC);
CREATE INDEX idx_orders_payment_status      ON orders (payment_status) WHERE payment_status = 'P';
CREATE INDEX idx_orders_coupon_id           ON orders (coupon_id);
CREATE INDEX idx_orders_shipping_address    ON orders (shipping_address_id);
CREATE INDEX idx_orders_billing_address     ON orders (billing_address_id);
CREATE INDEX idx_order_items_order_id       ON order_items (order_id);
CREATE INDEX idx_order_items_product_id     ON order_items (product_id);
CREATE INDEX idx_order_status_history_order ON order_status_history (order_id, created_at);
CREATE INDEX idx_return_requests_item       ON return_requests (order_item_id);
CREATE INDEX idx_replacement_requests_item  ON replacement_requests (order_item_id);
CREATE INDEX idx_refunds_order_id           ON refunds (order_id);
CREATE INDEX idx_cod_transactions_pending   ON cod_transactions (status) WHERE status = 'P';
CREATE INDEX idx_shipments_order_id         ON shipments (order_id);

-- NOTE: orders.order_number, invoices.invoice_number and coupons.coupon_code are already covered by
-- unique indexes (uq_orders_order_number, uq_invoices_invoice_number, uq_coupons_coupon_code).
