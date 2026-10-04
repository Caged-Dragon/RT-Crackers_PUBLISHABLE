-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/013_U12_Cart_protection.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U12 Cart protection (already enforced, notes only)
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 12 - CART PROTECTION
-- Already enforced: uq_cart_items_line UNIQUE (cart_id, product_id, COALESCE(variant_id, 0)).
-- That stops duplicate lines but still lets a customer hold two pack sizes (variants) of one product.
-- A plain UNIQUE (cart_id, product_id) would forbid that. If you really want it, uncomment:
--
--   DROP INDEX uq_cart_items_line;
--   ALTER TABLE cart_items ADD CONSTRAINT uq_cart_items_cart_product UNIQUE (cart_id, product_id);
-- =====================================================================

