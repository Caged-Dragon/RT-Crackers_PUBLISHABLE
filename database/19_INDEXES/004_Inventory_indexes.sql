-- =====================================================================
-- RT CRACKERS | 19_INDEXES/004_Inventory_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_inventory_low_stock        ON inventory (quantity_on_hand);
CREATE INDEX idx_inventory_movements_inv    ON inventory_movements (inventory_id, created_at DESC);
