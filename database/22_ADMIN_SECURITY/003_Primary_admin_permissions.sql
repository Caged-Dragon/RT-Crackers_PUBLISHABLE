-- =====================================================================
-- RT CRACKERS | 22_ADMIN_SECURITY/003_Primary_admin_permissions.sql
-- Primary Admin-only administrator management + audit monitoring.
-- =====================================================================

INSERT INTO public.permissions (permission_code, module_name, description)
SELECT 'ADMIN.MANAGE', 'ADMIN',
       'Create, activate, deactivate and manage administrator accounts'
WHERE NOT EXISTS (
    SELECT 1 FROM public.permissions WHERE permission_code = 'ADMIN.MANAGE'
);

INSERT INTO public.permissions (permission_code, module_name, description)
SELECT 'ADMIN.AUDIT.MONITOR', 'ADMIN',
       'Monitor administrator activity logs'
WHERE NOT EXISTS (
    SELECT 1 FROM public.permissions WHERE permission_code = 'ADMIN.AUDIT.MONITOR'
);

-- Remove ADMIN.MANAGE from all non-primary admins.
DELETE FROM public.admin_permissions ap
USING public.permissions p, public.admins a
WHERE ap.permission_id = p.permission_id
  AND a.admin_id = ap.admin_id
  AND p.permission_code = 'ADMIN.MANAGE'
  AND a.is_primary_admin = FALSE;

-- Do not allow a general admin role to inherit ADMIN.MANAGE.
DO $$
BEGIN
    IF to_regclass('public.role_permissions') IS NOT NULL THEN
        DELETE FROM public.role_permissions rp
        USING public.permissions p
        WHERE rp.permission_id = p.permission_id
          AND p.permission_code = 'ADMIN.MANAGE';
    END IF;
END $$;

-- Primary Admin receives both special permissions directly.
INSERT INTO public.admin_permissions
    (admin_id, permission_id, is_granted, granted_by)
SELECT a.admin_id, p.permission_id, TRUE, a.admin_id
FROM public.admins a
CROSS JOIN public.permissions p
WHERE a.is_primary_admin = TRUE
  AND p.permission_code IN ('ADMIN.MANAGE', 'ADMIN.AUDIT.MONITOR')
  AND NOT EXISTS (
      SELECT 1
      FROM public.admin_permissions ap
      WHERE ap.admin_id = a.admin_id
        AND ap.permission_id = p.permission_id
  );

UPDATE public.admin_permissions ap
SET is_granted = TRUE,
    granted_by = (SELECT admin_id FROM public.admins WHERE is_primary_admin = TRUE),
    updated_at = CURRENT_TIMESTAMP
FROM public.permissions p
WHERE ap.permission_id = p.permission_id
  AND p.permission_code IN ('ADMIN.MANAGE', 'ADMIN.AUDIT.MONITOR')
  AND ap.admin_id = (SELECT admin_id FROM public.admins WHERE is_primary_admin = TRUE);
