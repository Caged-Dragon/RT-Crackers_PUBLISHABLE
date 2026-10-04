-- =====================================================================
-- RT CRACKERS | 19_INDEXES/005_Analytics_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_page_views_created         ON page_views (created_at);
CREATE INDEX idx_product_views_product_time ON product_views (product_id, created_at);
CREATE INDEX idx_search_logs_query          ON search_logs (search_query);
CREATE INDEX idx_user_activity_user_time    ON user_activity_logs (user_id, created_at DESC);
