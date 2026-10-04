-- =====================================================================
-- RT CRACKERS | 22_ADMIN_SECURITY/004_Admin_audit_protection.sql
-- =====================================================================

REVOKE UPDATE, DELETE
ON TABLE public.admin_activity_logs
FROM anon, authenticated, PUBLIC;

CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_created_at
    ON public.admin_activity_logs (created_at DESC);

COMMENT ON TABLE public.admin_activity_logs IS
'Append-oriented administrator activity trail. Browser/API roles must not UPDATE or DELETE rows.';
