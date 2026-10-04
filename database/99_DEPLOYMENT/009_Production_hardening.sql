-- RT CRACKERS production hardening. Run only after the existing base + V2 + V3 + admin-security builds.
-- Safe/idempotent objects only; this does not replace the existing schema.
\set ON_ERROR_STOP on
BEGIN;

-- Inventory ledger idempotency: one sale/cancel/return movement per order line and inventory row.
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_movement_order_item
ON inventory_movements (inventory_id, movement_type, reference_type, reference_id)
WHERE reference_type IN ('O','R') AND reference_id IS NOT NULL AND movement_type IN ('S','C','R');

-- Explicitly keep COD as the only active payment method. The existing payment_methods
-- CHECK already prevents inserting a different method code.
UPDATE payment_methods SET is_active = (method_code = 'COD');

-- Defense in depth: even direct SQL callers cannot create an order against a non-COD method.
CREATE OR REPLACE FUNCTION fn_enforce_cod_only_order()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_code CHAR(3);
BEGIN
  SELECT method_code INTO v_code FROM payment_methods WHERE payment_method_id = NEW.payment_method_id;
  IF v_code IS DISTINCT FROM 'COD' THEN
    RAISE EXCEPTION 'Only Cash On Delivery orders are permitted';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_orders_cod_only ON orders;
CREATE TRIGGER trg_orders_cod_only
BEFORE INSERT OR UPDATE OF payment_method_id ON orders
FOR EACH ROW EXECUTE FUNCTION fn_enforce_cod_only_order();

COMMIT;
