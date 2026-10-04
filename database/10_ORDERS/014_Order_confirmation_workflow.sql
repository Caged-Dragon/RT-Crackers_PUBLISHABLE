-- =====================================================================
-- RT CRACKERS | 10_ORDERS/014_Order_confirmation_workflow.sql
-- Purpose:
--   Align order tracking with the approved RT Crackers workflow:
--
--   P = Order Submitted
--   C = Order Confirmed (ADMIN ONLY)
--   K = Processing / Packed (internal processing state)
--   S = Shipped
--   O = Out for Delivery (internal delivery state)
--   D = Delivered
--
--   X = Cancelled and R = Returned remain exception states.
--   Cancellation is NOT part of the normal customer tracking timeline.
--
-- IMPORTANT:
--   This migration does not delete or rewrite historical order data.
--   It adds database-level protection for the normal status transitions
--   and requires an admin session identity for confirmation.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Keep the existing status codes.
--    They are already present in the production schema and are retained
--    to avoid destructive data changes.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 2. Admin-only confirmation and controlled normal progression.
--
-- app.current_admin_id must be set by the authenticated admin backend
-- transaction before an admin changes an order status.
--
-- Customer-facing/API code must NEVER set this setting.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_order_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_admin_id INTEGER;
BEGIN
    -- No status change: nothing to validate.
    IF NEW.order_status IS NOT DISTINCT FROM OLD.order_status THEN
        RETURN NEW;
    END IF;

    -- Confirmation is an administrative action.
    IF NEW.order_status = 'C' THEN
        v_admin_id := NULLIF(
            current_setting('app.current_admin_id', TRUE),
            ''
        )::INTEGER;

        IF v_admin_id IS NULL THEN
            RAISE EXCEPTION
                'Order confirmation requires an authenticated admin';
        END IF;

        -- Confirmation is only valid from the submitted state.
        IF OLD.order_status <> 'P' THEN
            RAISE EXCEPTION
                'Invalid order confirmation transition: % -> %',
                OLD.order_status, NEW.order_status;
        END IF;
    END IF;

    -- Normal order progression.
    IF OLD.order_status = 'P' AND NEW.order_status NOT IN ('C', 'X') THEN
        RAISE EXCEPTION
            'Submitted orders may only be confirmed by an admin or cancelled through the future cancellation workflow';
    END IF;

    IF OLD.order_status = 'C' AND NEW.order_status NOT IN ('K', 'X') THEN
        RAISE EXCEPTION
            'Confirmed orders may only move to processing or a future cancellation workflow';
    END IF;

    IF OLD.order_status = 'K' AND NEW.order_status NOT IN ('S', 'X') THEN
        RAISE EXCEPTION
            'Processing orders may only move to shipped or a future cancellation workflow';
    END IF;

    IF OLD.order_status = 'S' AND NEW.order_status NOT IN ('O', 'D', 'X') THEN
        RAISE EXCEPTION
            'Shipped orders may only move to delivery, delivered, or a future cancellation workflow';
    END IF;

    IF OLD.order_status = 'O' AND NEW.order_status NOT IN ('D', 'X') THEN
        RAISE EXCEPTION
            'Out-for-delivery orders may only move to delivered or a future cancellation workflow';
    END IF;

    -- Delivered and returned orders are terminal for this workflow.
    IF OLD.order_status IN ('D', 'R') THEN
        RAISE EXCEPTION
            'A delivered or returned order cannot be moved to another status';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_order_status_transition ON orders;

CREATE TRIGGER trg_validate_order_status_transition
BEFORE UPDATE OF order_status ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_validate_order_status_transition();


-- ---------------------------------------------------------------------
-- 3. Ensure status history has the same controlled status vocabulary.
-- ---------------------------------------------------------------------
ALTER TABLE order_status_history
    DROP CONSTRAINT IF EXISTS ck_order_status_history_old;

ALTER TABLE order_status_history
    DROP CONSTRAINT IF EXISTS ck_order_status_history_new;

ALTER TABLE order_status_history
    ADD CONSTRAINT ck_order_status_history_old
    CHECK (
        old_status IS NULL
        OR old_status IN ('P','C','K','S','O','D','X','R')
    );

ALTER TABLE order_status_history
    ADD CONSTRAINT ck_order_status_history_new
    CHECK (
        new_status IN ('P','C','K','S','O','D','X','R')
    );


-- ---------------------------------------------------------------------
-- 4. Customer-facing tracking view.
--
-- The internal K/O milestones remain available to the admin system,
-- but this view exposes the five normal customer tracking milestones:
--
--   P Submitted
--   C Confirmed
--   K/S/O Processing / Shipped
--   D Delivered
--
-- Cancellation is intentionally excluded from the normal timeline.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW customer_order_tracking AS
SELECT
    o.order_id,
    o.order_number,
    o.user_id,
    CASE
        WHEN o.order_status = 'P' THEN 'submitted'
        WHEN o.order_status = 'C' THEN 'confirmed'
        WHEN o.order_status = 'K' THEN 'processing'
        WHEN o.order_status IN ('S','O') THEN 'shipped'
        WHEN o.order_status = 'D' THEN 'delivered'
        WHEN o.order_status = 'X' THEN 'cancelled'
        WHEN o.order_status = 'R' THEN 'returned'
    END AS tracking_stage,
    o.order_status,
    o.created_at,
    o.updated_at,
    o.expected_delivery_date,
    o.delivery_date
FROM orders o;


-- ---------------------------------------------------------------------
-- 5. Helpful comments/documentation.
-- ---------------------------------------------------------------------
COMMENT ON COLUMN orders.order_status IS
'P=Submitted, C=Confirmed by admin, K=Processing, S=Shipped, O=Out for delivery, D=Delivered, X=Cancelled exception, R=Returned exception';

COMMENT ON COLUMN orders.cancellation_reason IS
'Used only when cancellation workflow is explicitly enabled. Cancellation is not part of the normal customer tracking timeline.';

COMMENT ON VIEW customer_order_tracking IS
'Customer-facing order tracking projection. Normal flow: Submitted -> Confirmed -> Processing -> Shipped -> Delivered. Cancellation and return are exception states.';

COMMIT;
