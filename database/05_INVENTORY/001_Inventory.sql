-- =====================================================================
-- RT CRACKERS | 05_INVENTORY/001_Inventory.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- inventory | Purpose: current stock per product (or per variant) in the single store.
-- Keys : PK(inventory_id) | CK/AK: (product_id, variant_id|0) via unique index
-- Rel  : N:1 products, product_variants; 1:N inventory_movements
-- BCNF : quantities depend on the stocked item (candidate key); products.stock_quantity is the summed cache.
-- ---------------------------------------------------------------------
CREATE TABLE inventory (
    inventory_id       BIGINT     GENERATED ALWAYS AS IDENTITY,
    product_id         BIGINT     NOT NULL,
    variant_id         BIGINT,
    quantity_on_hand   INTEGER    NOT NULL DEFAULT 0,
    reserved_quantity  INTEGER    NOT NULL DEFAULT 0,
    rack_location      VARCHAR(40),
    last_restocked_at  TIMESTAMP,
    created_at         TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventory PRIMARY KEY (inventory_id),
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_variant FOREIGN KEY (product_id, variant_id) REFERENCES product_variants (product_id, variant_id) ON DELETE RESTRICT,
    CONSTRAINT ck_inventory_on_hand  CHECK (quantity_on_hand >= 0),
    CONSTRAINT ck_inventory_reserved CHECK (reserved_quantity >= 0 AND reserved_quantity <= quantity_on_hand)
);
CREATE UNIQUE INDEX uq_inventory_item ON inventory (product_id, COALESCE(variant_id, 0));

-- inventory -> products.stock_quantity
CREATE OR REPLACE FUNCTION fn_sync_product_stock()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_product_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN v_product_id := OLD.product_id; ELSE v_product_id := NEW.product_id; END IF;
    UPDATE products
       SET stock_quantity = (SELECT COALESCE(SUM(quantity_on_hand), 0) FROM inventory WHERE product_id = v_product_id)
     WHERE product_id = v_product_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_inventory_sync_stock AFTER INSERT OR DELETE OR UPDATE OF quantity_on_hand ON inventory
    FOR EACH ROW EXECUTE FUNCTION fn_sync_product_stock();
