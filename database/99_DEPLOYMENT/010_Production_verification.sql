-- Post-deployment verification for the existing schema.
\set ON_ERROR_STOP on
SELECT current_database() AS database_name;
SELECT count(*) AS user_count FROM users;
SELECT count(*) AS product_count FROM products;
SELECT count(*) AS inventory_rows FROM inventory;
SELECT count(*) AS payment_methods FROM payment_methods WHERE method_code = 'COD' AND is_active;
SELECT count(*) AS non_cod_payment_methods FROM payment_methods WHERE method_code <> 'COD' OR is_active IS DISTINCT FROM (method_code = 'COD');
SELECT count(*) AS negative_inventory_rows FROM inventory WHERE quantity_on_hand < 0 OR reserved_quantity < 0 OR reserved_quantity > quantity_on_hand;
SELECT count(*) AS orphan_inventory_movements FROM inventory_movements m LEFT JOIN inventory i ON i.inventory_id=m.inventory_id WHERE i.inventory_id IS NULL;
SELECT count(*) AS pending_cod_without_order FROM cod_transactions c LEFT JOIN orders o ON o.order_id=c.order_id WHERE o.order_id IS NULL;
