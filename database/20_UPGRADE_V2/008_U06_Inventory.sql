-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/008_U06_Inventory.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U6 Advanced inventory management
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 6 - ADVANCED INVENTORY MANAGEMENT
--   quantity_on_hand  = physical units (kept; existing triggers rely on it)
--   reserved_stock    = renamed from reserved_quantity
--   available_stock   = GENERATED: quantity_on_hand - reserved_stock (cannot drift)
--   sold/returned/damaged_stock = running totals maintained by the movement trigger
--   stock_status      = GENERATED: O out of stock, L low (<= reorder_level), X over maximum, I in stock
-- =====================================================================
ALTER TABLE inventory RENAME COLUMN reserved_quantity TO reserved_stock;

ALTER TABLE inventory
    ADD COLUMN returned_stock     INTEGER    NOT NULL DEFAULT 0,
    ADD COLUMN damaged_stock      INTEGER    NOT NULL DEFAULT 0,
    ADD COLUMN sold_stock         INTEGER    NOT NULL DEFAULT 0,
    ADD COLUMN reorder_level      INTEGER    NOT NULL DEFAULT 10,
    ADD COLUMN reorder_quantity   INTEGER    NOT NULL DEFAULT 50,
    ADD COLUMN minimum_stock      INTEGER    NOT NULL DEFAULT 0,
    ADD COLUMN maximum_stock      INTEGER    NOT NULL DEFAULT 1000,
    ADD COLUMN last_stock_update  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- start from the per-product levels already configured on products
UPDATE inventory i
   SET minimum_stock = p.min_stock_level,
       maximum_stock = p.max_stock_level,
       reorder_level = GREATEST(p.min_stock_level, 0),
       last_stock_update = i.updated_at
  FROM products p
 WHERE p.product_id = i.product_id;

-- rebuild the running totals from the ledger
UPDATE inventory i
   SET sold_stock     = GREATEST(m.sold - m.cancelled, 0),
       returned_stock = m.returned,
       damaged_stock  = m.damaged
  FROM (SELECT inventory_id,
               COALESCE(SUM(-quantity_change) FILTER (WHERE movement_type = 'S'), 0) AS sold,
               COALESCE(SUM( quantity_change) FILTER (WHERE movement_type = 'C'), 0) AS cancelled,
               COALESCE(SUM( quantity_change) FILTER (WHERE movement_type = 'R'), 0) AS returned,
               COALESCE(SUM(-quantity_change) FILTER (WHERE movement_type = 'D'), 0) AS damaged
          FROM inventory_movements GROUP BY inventory_id) m
 WHERE m.inventory_id = i.inventory_id;

ALTER TABLE inventory
    ADD COLUMN available_stock INTEGER GENERATED ALWAYS AS (quantity_on_hand - reserved_stock) STORED;
ALTER TABLE inventory
    ADD COLUMN stock_status CHAR(1) GENERATED ALWAYS AS (
        CASE WHEN quantity_on_hand - reserved_stock <= 0              THEN 'O'
             WHEN quantity_on_hand - reserved_stock <= reorder_level  THEN 'L'
             WHEN quantity_on_hand > maximum_stock                    THEN 'X'
             ELSE 'I' END) STORED;

ALTER TABLE inventory
    ADD CONSTRAINT ck_inventory_stock_nonneg CHECK (available_stock >= 0 AND reserved_stock >= 0 AND returned_stock >= 0
                                                    AND damaged_stock >= 0 AND sold_stock >= 0),
    ADD CONSTRAINT ck_inventory_reorder      CHECK (reorder_level >= 0 AND reorder_quantity >= 0),
    ADD CONSTRAINT ck_inventory_stock_limits CHECK (minimum_stock >= 0 AND maximum_stock >= minimum_stock),
    ADD CONSTRAINT ck_inventory_stock_status CHECK (stock_status IN ('O','L','I','X'));

CREATE INDEX idx_inventory_stock_status ON inventory (stock_status) WHERE stock_status IN ('O','L');

-- movement ledger now also maintains the running totals
CREATE OR REPLACE FUNCTION fn_apply_inventory_movement()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE inventory
       SET quantity_on_hand  = quantity_on_hand + NEW.quantity_change,
           sold_stock        = CASE NEW.movement_type
                                   WHEN 'S' THEN sold_stock - NEW.quantity_change
                                   WHEN 'C' THEN GREATEST(sold_stock - NEW.quantity_change, 0)
                                   ELSE sold_stock END,
           returned_stock    = returned_stock + CASE WHEN NEW.movement_type = 'R' THEN NEW.quantity_change ELSE 0 END,
           damaged_stock     = damaged_stock  + CASE WHEN NEW.movement_type = 'D' THEN -NEW.quantity_change ELSE 0 END,
           last_restocked_at = CASE WHEN NEW.movement_type = 'P' THEN CURRENT_TIMESTAMP ELSE last_restocked_at END
     WHERE inventory_id = NEW.inventory_id;
    RETURN NEW;
END;
$$;

-- last_stock_update follows any change to physical or reserved units
CREATE OR REPLACE FUNCTION fn_inventory_touch()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.quantity_on_hand IS DISTINCT FROM OLD.quantity_on_hand
       OR NEW.reserved_stock IS DISTINCT FROM OLD.reserved_stock THEN
        NEW.last_stock_update := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_inventory_touch BEFORE UPDATE ON inventory
    FOR EACH ROW EXECUTE FUNCTION fn_inventory_touch();

