-- =====================================================================
-- RT CRACKERS | 11_PAYMENTS/001_Payment_methods.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- payment_methods | Purpose: allowed payment modes. Only Cash On Delivery is permitted (CHECK).
-- Keys : PK(payment_method_id) | CK/AK: method_code
-- Rel  : 1:N orders
-- BCNF : attributes depend only on the method.
-- ---------------------------------------------------------------------
CREATE TABLE payment_methods (
    payment_method_id  SMALLINT       GENERATED ALWAYS AS IDENTITY,
    method_code        CHAR(3)        NOT NULL,
    method_name        VARCHAR(60)    NOT NULL,
    description        VARCHAR(255),
    min_order_amount   NUMERIC(12,2)  NOT NULL DEFAULT 0,
    max_order_amount   NUMERIC(12,2),
    is_active          BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_payment_methods PRIMARY KEY (payment_method_id),
    CONSTRAINT uq_payment_methods_code UNIQUE (method_code),
    CONSTRAINT ck_payment_methods_cod_only CHECK (method_code = 'COD'),
    CONSTRAINT ck_payment_methods_limits   CHECK (min_order_amount >= 0 AND (max_order_amount IS NULL OR max_order_amount >= min_order_amount))
);
