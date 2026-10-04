-- =====================================================================
-- RT CRACKERS | 10_ORDERS/003_Order_status_history.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- order_status_history | Purpose: append-only status timeline (written by trigger on orders).
-- Keys : PK(history_id)
-- Rel  : N:1 orders, N:1 admins
-- BCNF : attributes describe one transition.
-- ---------------------------------------------------------------------
CREATE TABLE order_status_history (
    history_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    order_id    BIGINT        NOT NULL,
    old_status  CHAR(1),
    new_status  CHAR(1)       NOT NULL,
    changed_by  INTEGER,
    remarks     VARCHAR(255),
    created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_order_status_history PRIMARY KEY (history_id),
    CONSTRAINT fk_order_status_history_order FOREIGN KEY (order_id)   REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_status_history_admin FOREIGN KEY (changed_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_order_status_history_old CHECK (old_status IS NULL OR old_status IN ('P','C','K','S','O','D','X','R')),
    CONSTRAINT ck_order_status_history_new CHECK (new_status IN ('P','C','K','S','O','D','X','R'))
);
