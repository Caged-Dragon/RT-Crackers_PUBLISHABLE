-- =====================================================================
-- RT CRACKERS | 19_INDEXES/006_System_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_user_notifications_user    ON user_notifications (user_id, is_read);
CREATE INDEX idx_festival_products_product  ON festival_products (product_id);
CREATE INDEX idx_audit_logs_record          ON audit_logs (table_name, record_id);
CREATE INDEX idx_error_logs_open            ON error_logs (created_at DESC) WHERE NOT is_resolved;
