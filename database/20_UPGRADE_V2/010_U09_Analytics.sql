-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/010_U09_Analytics.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U9 Analytics expansion
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 9 - ANALYTICS EXPANSION
-- page_views, product_views, search_logs, user_activity_logs already exist.
-- =====================================================================

-- ---------------------------------------------------------------------
-- dashboard_metrics | Purpose: pre-computed KPI values for the admin dashboard.
-- Keys : PK(metric_id) | CK/AK: (period_type, period_date, metric_key)
-- BCNF : metric_value depends on the whole (period, date, key).
-- ---------------------------------------------------------------------
CREATE TABLE dashboard_metrics (
    metric_id     BIGINT         GENERATED ALWAYS AS IDENTITY,
    metric_key    VARCHAR(60)    NOT NULL,
    period_type   CHAR(1)        NOT NULL,           -- D daily, W weekly, M monthly, Y yearly
    period_date   DATE           NOT NULL,
    metric_value  NUMERIC(18,4)  NOT NULL,
    unit          VARCHAR(20),
    calculated_at TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_dashboard_metrics PRIMARY KEY (metric_id),
    CONSTRAINT uq_dashboard_metrics_key_period UNIQUE (period_type, period_date, metric_key),
    CONSTRAINT ck_dashboard_metrics_period CHECK (period_type IN ('D','W','M','Y')),
    CONSTRAINT ck_dashboard_metrics_key    CHECK (BTRIM(metric_key) <> '')
);

-- ---------------------------------------------------------------------
-- revenue_analytics | Purpose: revenue per period, overall (category_id NULL) or per category.
-- Keys : PK(revenue_id) | CK/AK: (period_type, period_date, category_id|0) via unique index
-- Rel  : N:1 categories (optional)
-- BCNF : net_revenue and average_order_value are GENERATED from the stored amounts.
-- ---------------------------------------------------------------------
CREATE TABLE revenue_analytics (
    revenue_id           BIGINT         GENERATED ALWAYS AS IDENTITY,
    period_type          CHAR(1)        NOT NULL,     -- D, W, M
    period_date          DATE           NOT NULL,
    category_id          INTEGER,
    orders_count         INTEGER        NOT NULL DEFAULT 0,
    units_sold           INTEGER        NOT NULL DEFAULT 0,
    gross_revenue        NUMERIC(14,2)  NOT NULL DEFAULT 0,
    discount_total       NUMERIC(14,2)  NOT NULL DEFAULT 0,
    tax_total            NUMERIC(14,2)  NOT NULL DEFAULT 0,
    shipping_total       NUMERIC(14,2)  NOT NULL DEFAULT 0,
    refund_total         NUMERIC(14,2)  NOT NULL DEFAULT 0,
    cod_collected        NUMERIC(14,2)  NOT NULL DEFAULT 0,
    net_revenue          NUMERIC(14,2)  GENERATED ALWAYS AS (gross_revenue - discount_total + tax_total + shipping_total - refund_total) STORED,
    average_order_value  NUMERIC(14,2)  GENERATED ALWAYS AS (ROUND((gross_revenue - discount_total + tax_total + shipping_total - refund_total) / NULLIF(orders_count, 0), 2)) STORED,
    calculated_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_revenue_analytics PRIMARY KEY (revenue_id),
    CONSTRAINT fk_revenue_analytics_category FOREIGN KEY (category_id) REFERENCES categories (category_id) ON DELETE CASCADE,
    CONSTRAINT ck_revenue_analytics_period  CHECK (period_type IN ('D','W','M')),
    CONSTRAINT ck_revenue_analytics_counts  CHECK (orders_count >= 0 AND units_sold >= 0),
    CONSTRAINT ck_revenue_analytics_amounts CHECK (gross_revenue >= 0 AND discount_total >= 0 AND tax_total >= 0
                                                   AND shipping_total >= 0 AND refund_total >= 0 AND cod_collected >= 0)
);
CREATE UNIQUE INDEX uq_revenue_analytics_scope ON revenue_analytics (period_type, period_date, COALESCE(category_id, 0));
CREATE INDEX idx_revenue_analytics_category ON revenue_analytics (category_id) WHERE category_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- customer_analytics | Purpose: one summary row per customer (segment, lifetime value, recency).
-- Keys : PK(user_id) which is also FK
-- Rel  : 1:1 users
-- BCNF : sole determinant is user_id; average_order_value is GENERATED.
-- ---------------------------------------------------------------------
CREATE TABLE customer_analytics (
    user_id              BIGINT         NOT NULL,
    total_orders         INTEGER        NOT NULL DEFAULT 0,
    delivered_orders     INTEGER        NOT NULL DEFAULT 0,
    cancelled_orders     INTEGER        NOT NULL DEFAULT 0,
    returned_orders      INTEGER        NOT NULL DEFAULT 0,
    lifetime_value       NUMERIC(14,2)  NOT NULL DEFAULT 0,
    average_order_value  NUMERIC(14,2)  GENERATED ALWAYS AS (CASE WHEN delivered_orders > 0 THEN ROUND(lifetime_value / delivered_orders, 2) ELSE 0 END) STORED,
    first_order_at       TIMESTAMP,
    last_order_at        TIMESTAMP,
    last_active_at       TIMESTAMP,
    customer_segment     CHAR(1)        NOT NULL DEFAULT 'N',   -- N new, R regular, L loyal, V vip, D dormant
    calculated_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_customer_analytics PRIMARY KEY (user_id),
    CONSTRAINT fk_customer_analytics_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_customer_analytics_segment CHECK (customer_segment IN ('N','R','L','V','D')),
    CONSTRAINT ck_customer_analytics_counts  CHECK (total_orders >= 0 AND delivered_orders >= 0 AND cancelled_orders >= 0
                                                    AND returned_orders >= 0
                                                    AND delivered_orders <= total_orders AND cancelled_orders <= total_orders
                                                    AND returned_orders <= total_orders),
    CONSTRAINT ck_customer_analytics_value   CHECK (lifetime_value >= 0),
    CONSTRAINT ck_customer_analytics_dates   CHECK (first_order_at IS NULL OR last_order_at IS NULL OR last_order_at >= first_order_at)
);
CREATE INDEX idx_customer_analytics_segment ON customer_analytics (customer_segment);

-- ---------------------------------------------------------------------
-- product_analytics | Purpose: daily funnel numbers per product.
-- Keys : COMPOSITE PK(product_id, stat_date)
-- Rel  : N:1 products
-- BCNF : conversion_rate is GENERATED from orders_count and views_count.
-- ---------------------------------------------------------------------
CREATE TABLE product_analytics (
    product_id       BIGINT         NOT NULL,
    stat_date        DATE           NOT NULL,
    views_count      INTEGER        NOT NULL DEFAULT 0,
    unique_viewers   INTEGER        NOT NULL DEFAULT 0,
    cart_adds        INTEGER        NOT NULL DEFAULT 0,
    wishlist_adds    INTEGER        NOT NULL DEFAULT 0,
    orders_count     INTEGER        NOT NULL DEFAULT 0,
    units_sold       INTEGER        NOT NULL DEFAULT 0,
    returns_count    INTEGER        NOT NULL DEFAULT 0,
    revenue          NUMERIC(14,2)  NOT NULL DEFAULT 0,
    conversion_rate  NUMERIC(7,2)   GENERATED ALWAYS AS (ROUND(orders_count * 100.0 / NULLIF(views_count, 0), 2)) STORED,
    created_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_analytics PRIMARY KEY (product_id, stat_date),
    CONSTRAINT fk_product_analytics_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT ck_product_analytics_counts  CHECK (views_count >= 0 AND unique_viewers >= 0 AND cart_adds >= 0 AND wishlist_adds >= 0
                                                   AND orders_count >= 0 AND units_sold >= 0 AND returns_count >= 0 AND revenue >= 0),
    CONSTRAINT ck_product_analytics_unique  CHECK (unique_viewers <= views_count)
);
CREATE INDEX idx_product_analytics_date ON product_analytics (stat_date);

-- ---------------------------------------------------------------------
-- conversion_analytics | Purpose: daily sales funnel for the whole store.
-- Keys : PK(conversion_id) | CK/AK: stat_date
-- BCNF : the three rates are GENERATED from the stored counts.
-- ---------------------------------------------------------------------
CREATE TABLE conversion_analytics (
    conversion_id            BIGINT        GENERATED ALWAYS AS IDENTITY,
    stat_date                DATE          NOT NULL,
    sessions_count           INTEGER       NOT NULL DEFAULT 0,
    product_views            INTEGER       NOT NULL DEFAULT 0,
    add_to_cart_count        INTEGER       NOT NULL DEFAULT 0,
    checkout_started_count   INTEGER       NOT NULL DEFAULT 0,
    orders_placed_count      INTEGER       NOT NULL DEFAULT 0,
    orders_delivered_count   INTEGER       NOT NULL DEFAULT 0,
    visit_to_cart_rate       NUMERIC(7,2)  GENERATED ALWAYS AS (ROUND(add_to_cart_count * 100.0 / NULLIF(sessions_count, 0), 2)) STORED,
    cart_to_order_rate       NUMERIC(7,2)  GENERATED ALWAYS AS (ROUND(orders_placed_count * 100.0 / NULLIF(add_to_cart_count, 0), 2)) STORED,
    overall_conversion_rate  NUMERIC(7,2)  GENERATED ALWAYS AS (ROUND(orders_placed_count * 100.0 / NULLIF(sessions_count, 0), 2)) STORED,
    created_at               TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_conversion_analytics PRIMARY KEY (conversion_id),
    CONSTRAINT uq_conversion_analytics_date UNIQUE (stat_date),
    CONSTRAINT ck_conversion_analytics_counts CHECK (sessions_count >= 0 AND product_views >= 0 AND add_to_cart_count >= 0
                                                     AND checkout_started_count >= 0 AND orders_placed_count >= 0
                                                     AND orders_delivered_count >= 0 AND orders_delivered_count <= orders_placed_count)
);

-- ---------------------------------------------------------------------
-- cart_abandonment_logs | Purpose: carts left without ordering, reminders sent, and recovery.
-- Keys : PK(abandonment_id) | CK/AK: cart_id
-- Rel  : 1:1 carts; N:1 orders (the order that recovered it)
-- BCNF : the customer is reached through carts.user_id, so user_id is not repeated here.
-- ---------------------------------------------------------------------
CREATE TABLE cart_abandonment_logs (
    abandonment_id      BIGINT         GENERATED ALWAYS AS IDENTITY,
    cart_id             BIGINT         NOT NULL,
    abandoned_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    items_count         INTEGER        NOT NULL DEFAULT 0,
    cart_value          NUMERIC(12,2)  NOT NULL DEFAULT 0,        -- snapshot at the time of abandonment
    reminder_count      SMALLINT       NOT NULL DEFAULT 0,
    last_reminder_at    TIMESTAMP,
    is_recovered        BOOLEAN        NOT NULL DEFAULT FALSE,
    recovered_order_id  BIGINT,
    recovered_at        TIMESTAMP,
    created_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cart_abandonment_logs PRIMARY KEY (abandonment_id),
    CONSTRAINT uq_cart_abandonment_logs_cart UNIQUE (cart_id),
    CONSTRAINT fk_cart_abandonment_logs_cart  FOREIGN KEY (cart_id)            REFERENCES carts (cart_id)   ON DELETE CASCADE,
    CONSTRAINT fk_cart_abandonment_logs_order FOREIGN KEY (recovered_order_id) REFERENCES orders (order_id) ON DELETE SET NULL,
    CONSTRAINT ck_cart_abandonment_logs_counts   CHECK (items_count >= 0 AND cart_value >= 0 AND reminder_count >= 0),
    CONSTRAINT ck_cart_abandonment_logs_reminder CHECK ((reminder_count = 0) = (last_reminder_at IS NULL)),
    CONSTRAINT ck_cart_abandonment_logs_recovery CHECK (is_recovered = (recovered_at IS NOT NULL)
                                                        AND (recovered_order_id IS NULL OR is_recovered))
);
CREATE INDEX idx_cart_abandonment_logs_open  ON cart_abandonment_logs (abandoned_at) WHERE NOT is_recovered;
CREATE INDEX idx_cart_abandonment_logs_order ON cart_abandonment_logs (recovered_order_id) WHERE recovered_order_id IS NOT NULL;

