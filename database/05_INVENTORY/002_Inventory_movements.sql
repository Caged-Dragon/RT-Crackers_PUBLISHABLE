-- =====================================================================
-- RT CRACKERS | 05_INVENTORY/002_Inventory_movements.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- inventory_movements | Purpose: append-only stock ledger; a trigger applies each row to inventory.
-- Keys : PK(movement_id)
-- Rel  : N:1 inventory, N:1 admins
-- BCNF : attributes describe one movement.
-- ---------------------------------------------------------------------
CREATE TABLE inventory_movements (
    movement_id      BIGINT         GENERATED ALWAYS AS IDENTITY,
    inventory_id     BIGINT         NOT NULL,
    movement_type    CHAR(1)        NOT NULL,   -- P purchase, S sale, R customer return, A adjustment, D damage/write-off, C cancel restock
    quantity_change  INTEGER        NOT NULL,
    unit_cost        NUMERIC(12,2),
    reference_type   CHAR(1),                   -- O order, R return, P purchase, M manual
    reference_id     BIGINT,
    notes            VARCHAR(255),
    performed_by     INTEGER,
    created_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventory_movements PRIMARY KEY (movement_id),
    CONSTRAINT fk_inventory_movements_inventory FOREIGN KEY (inventory_id)  REFERENCES inventory (inventory_id) ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_movements_admin     FOREIGN KEY (performed_by)  REFERENCES admins (admin_id)         ON DELETE SET NULL,
    CONSTRAINT ck_inventory_movements_type   CHECK (movement_type IN ('P','S','R','A','D','C')),
    CONSTRAINT ck_inventory_movements_qty    CHECK (quantity_change <> 0),
    CONSTRAINT ck_inventory_movements_sign   CHECK ((movement_type IN ('P','R','C') AND quantity_change > 0)
                                                 OR (movement_type IN ('S','D')     AND quantity_change < 0)
                                                 OR  movement_type = 'A'),
    CONSTRAINT ck_inventory_movements_reftype CHECK (reference_type IS NULL OR reference_type IN ('O','R','P','M')),
    CONSTRAINT ck_inventory_movements_refpair CHECK ((reference_type IS NULL) = (reference_id IS NULL)),
    CONSTRAINT ck_inventory_movements_cost    CHECK (unit_cost IS NULL OR unit_cost >= 0)
);

-- inventory_movements -> inventory
CREATE OR REPLACE FUNCTION fn_apply_inventory_movement()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE inventory
       SET quantity_on_hand  = quantity_on_hand + NEW.quantity_change,
           last_restocked_at = CASE WHEN NEW.movement_type = 'P' THEN CURRENT_TIMESTAMP ELSE last_restocked_at END
     WHERE inventory_id = NEW.inventory_id;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_inventory_movements_apply AFTER INSERT ON inventory_movements
    FOR EACH ROW EXECUTE FUNCTION fn_apply_inventory_movement();
