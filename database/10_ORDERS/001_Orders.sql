-- =====================================================================
-- RT CRACKERS | 10_ORDERS/001_Orders.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- orders | Purpose: order header. total_amount is GENERATED from its components.
-- Keys : PK(order_id) | CK/AK: order_number, tracking_number, (order_id,user_id,coupon_id)
-- Rel  : N:1 users, addresses (billing, shipping), coupons, payment_methods, shipping_methods;
--        1:N order_items, order_status_history, shipments; 1:1 invoices, cod_transactions
-- BCNF : total_amount is generated (no separate dependency); addresses are referenced, never copied.
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id                BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_number            VARCHAR(20)    NOT NULL DEFAULT ('RTC' || TO_CHAR(CURRENT_DATE, 'YYMMDD') || LPAD(NEXTVAL('seq_order_number')::TEXT, 6, '0')),
    user_id                 BIGINT         NOT NULL,
    billing_address_id      BIGINT         NOT NULL,
    shipping_address_id     BIGINT         NOT NULL,
    coupon_id               INTEGER,
    payment_method_id       SMALLINT       NOT NULL,
    shipping_method_id      SMALLINT       NOT NULL,
    subtotal                NUMERIC(12,2)  NOT NULL DEFAULT 0,
    discount_amount         NUMERIC(12,2)  NOT NULL DEFAULT 0,
    tax_amount              NUMERIC(12,2)  NOT NULL DEFAULT 0,
    shipping_amount         NUMERIC(12,2)  NOT NULL DEFAULT 0,
    total_amount            NUMERIC(12,2)  GENERATED ALWAYS AS (subtotal - discount_amount + tax_amount + shipping_amount) STORED,
    payment_status          CHAR(1)        NOT NULL DEFAULT 'P',   -- P pending, C collected, F failed, R refunded, Q partially refunded
    order_status            CHAR(1)        NOT NULL DEFAULT 'P',   -- P placed, C confirmed, K packed, S shipped, O out for delivery, D delivered, X cancelled, R returned
    tracking_number         VARCHAR(40),
    expected_delivery_date  DATE,
    delivery_date           DATE,
    cancellation_reason     VARCHAR(255),
    notes                   TEXT,
    created_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT uq_orders_order_number    UNIQUE (order_number),
    CONSTRAINT uq_orders_tracking_number UNIQUE (tracking_number),
    CONSTRAINT uq_orders_order_user_coupon UNIQUE (order_id, user_id, coupon_id),
    CONSTRAINT fk_orders_user             FOREIGN KEY (user_id)             REFERENCES users (user_id)                       ON DELETE RESTRICT,
    CONSTRAINT fk_orders_billing_address  FOREIGN KEY (billing_address_id)  REFERENCES addresses (address_id)                 ON DELETE RESTRICT,
    CONSTRAINT fk_orders_shipping_address FOREIGN KEY (shipping_address_id) REFERENCES addresses (address_id)                 ON DELETE RESTRICT,
    CONSTRAINT fk_orders_coupon           FOREIGN KEY (coupon_id)           REFERENCES coupons (coupon_id)                   ON DELETE SET NULL,
    CONSTRAINT fk_orders_payment_method   FOREIGN KEY (payment_method_id)   REFERENCES payment_methods (payment_method_id)   ON DELETE RESTRICT,
    CONSTRAINT fk_orders_shipping_method  FOREIGN KEY (shipping_method_id)  REFERENCES shipping_methods (shipping_method_id) ON DELETE RESTRICT,
    CONSTRAINT ck_orders_amounts          CHECK (subtotal >= 0 AND discount_amount >= 0 AND tax_amount >= 0 AND shipping_amount >= 0),
    CONSTRAINT ck_orders_discount_le_sub  CHECK (discount_amount <= subtotal),
    CONSTRAINT ck_orders_total_amount     CHECK (total_amount >= 0),
    CONSTRAINT ck_orders_payment_status   CHECK (payment_status IN ('P','C','F','R','Q')),
    CONSTRAINT ck_orders_order_status     CHECK (order_status IN ('P','C','K','S','O','D','X','R')),
    CONSTRAINT ck_orders_cancel_reason    CHECK (order_status <> 'X' OR cancellation_reason IS NOT NULL),
    CONSTRAINT ck_orders_delivered_date   CHECK (order_status <> 'D' OR delivery_date IS NOT NULL)
);

-- orders -> order_status_history (set app.current_admin_id per session to record who changed it)
CREATE OR REPLACE FUNCTION fn_log_order_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO order_status_history (order_id, old_status, new_status)
        VALUES (NEW.order_id, NULL, NEW.order_status);
    ELSIF NEW.order_status IS DISTINCT FROM OLD.order_status THEN
        INSERT INTO order_status_history (order_id, old_status, new_status, changed_by)
        VALUES (NEW.order_id, OLD.order_status, NEW.order_status,
                NULLIF(current_setting('app.current_admin_id', TRUE), '')::INTEGER);
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_orders_log_status AFTER INSERT OR UPDATE OF order_status ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_log_order_status();

-- orders delivered -> products.sales_count
CREATE OR REPLACE FUNCTION fn_update_sales_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE products p
       SET sales_count = p.sales_count + s.qty
      FROM (SELECT product_id, SUM(quantity)::INTEGER AS qty
              FROM order_items WHERE order_id = NEW.order_id GROUP BY product_id) s
     WHERE p.product_id = s.product_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_orders_sales_count AFTER UPDATE OF order_status ON orders
    FOR EACH ROW WHEN (NEW.order_status = 'D' AND OLD.order_status <> 'D')
    EXECUTE FUNCTION fn_update_sales_count();
