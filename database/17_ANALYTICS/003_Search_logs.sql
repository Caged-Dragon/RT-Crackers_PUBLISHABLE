-- =====================================================================
-- RT CRACKERS | 17_ANALYTICS/003_Search_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- search_logs | Purpose: what shoppers search for and what they click.
-- Keys : PK(search_log_id)
-- Rel  : N:1 users (optional), N:1 products (clicked)
-- BCNF : attributes describe one search.
-- ---------------------------------------------------------------------
CREATE TABLE search_logs (
    search_log_id       BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id             BIGINT,
    anonymous_id        VARCHAR(64),
    search_query        VARCHAR(255)  NOT NULL,
    results_count       INTEGER       NOT NULL DEFAULT 0,
    clicked_product_id  BIGINT,
    ip_address          INET,
    created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_search_logs PRIMARY KEY (search_log_id),
    CONSTRAINT fk_search_logs_user    FOREIGN KEY (user_id)            REFERENCES users (user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_search_logs_product FOREIGN KEY (clicked_product_id) REFERENCES products (product_id) ON DELETE SET NULL,
    CONSTRAINT ck_search_logs_results CHECK (results_count >= 0)
);
