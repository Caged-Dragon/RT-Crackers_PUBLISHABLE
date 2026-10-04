-- =====================================================================
-- RT CRACKERS | 22_ADMIN_SECURITY/005_Verification.sql
-- Read-only verification for the Primary Admin/security module.
-- =====================================================================

DO $$
DECLARE
    v_primary_count INTEGER;
    v_primary_id INTEGER;
    v_manage INTEGER;
    v_monitor INTEGER;
    v_non_primary_manage INTEGER;
BEGIN
    SELECT count(*), min(admin_id)
    INTO v_primary_count, v_primary_id
    FROM public.admins
    WHERE is_primary_admin = TRUE;

    IF v_primary_count <> 1 THEN
        RAISE EXCEPTION 'Verification failed: expected exactly 1 Primary Admin, found %.', v_primary_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.admins a
        JOIN public.users u ON u.user_id = a.user_id
        WHERE a.admin_id = v_primary_id
          AND a.status = 'A'
          AND u.auth_user_id = 'f96528ac-4322-4082-b707-d62bebdfcffe'::uuid
          AND lower(u.email) = lower('caged.dragon.official@gmail.com')
    ) THEN
        RAISE EXCEPTION 'Verification failed: Primary Admin is not linked to the designated Auth account.';
    END IF;

    SELECT count(*) INTO v_manage
    FROM public.admin_permissions ap
    JOIN public.permissions p ON p.permission_id = ap.permission_id
    WHERE ap.admin_id = v_primary_id
      AND p.permission_code = 'ADMIN.MANAGE'
      AND ap.is_granted = TRUE;

    SELECT count(*) INTO v_monitor
    FROM public.admin_permissions ap
    JOIN public.permissions p ON p.permission_id = ap.permission_id
    WHERE ap.admin_id = v_primary_id
      AND p.permission_code = 'ADMIN.AUDIT.MONITOR'
      AND ap.is_granted = TRUE;

    SELECT count(*) INTO v_non_primary_manage
    FROM public.admin_permissions ap
    JOIN public.permissions p ON p.permission_id = ap.permission_id
    JOIN public.admins a ON a.admin_id = ap.admin_id
    WHERE p.permission_code = 'ADMIN.MANAGE'
      AND ap.is_granted = TRUE
      AND a.is_primary_admin = FALSE;

    IF v_manage <> 1 OR v_monitor <> 1 OR v_non_primary_manage <> 0 THEN
        RAISE EXCEPTION
          'Verification failed: ADMIN.MANAGE=% ADMIN.AUDIT.MONITOR=% non_primary_manage=%',
          v_manage, v_monitor, v_non_primary_manage;
    END IF;
END $$;

SELECT
    a.admin_id,
    a.user_id,
    u.auth_user_id,
    u.email,
    u.first_name,
    u.last_name,
    u.phone,
    a.employee_code,
    a.designation,
    a.status,
    a.is_primary_admin
FROM public.admins a
JOIN public.users u ON u.user_id = a.user_id
ORDER BY a.is_primary_admin DESC, a.admin_id;

SELECT
    a.admin_id,
    u.email,
    a.is_primary_admin,
    p.permission_code,
    ap.is_granted
FROM public.admin_permissions ap
JOIN public.admins a ON a.admin_id = ap.admin_id
JOIN public.users u ON u.user_id = a.user_id
JOIN public.permissions p ON p.permission_id = ap.permission_id
WHERE p.permission_code IN ('ADMIN.MANAGE', 'ADMIN.AUDIT.MONITOR')
ORDER BY a.is_primary_admin DESC, p.permission_code;

SELECT count(*) AS non_primary_admin_manage_count
FROM public.admin_permissions ap
JOIN public.admins a ON a.admin_id = ap.admin_id
JOIN public.permissions p ON p.permission_id = ap.permission_id
WHERE p.permission_code = 'ADMIN.MANAGE'
  AND ap.is_granted = TRUE
  AND a.is_primary_admin = FALSE;

SELECT
    has_table_privilege('anon', 'public.admin_activity_logs', 'UPDATE') AS anon_can_update_audit,
    has_table_privilege('anon', 'public.admin_activity_logs', 'DELETE') AS anon_can_delete_audit,
    has_table_privilege('authenticated', 'public.admin_activity_logs', 'UPDATE') AS authenticated_can_update_audit,
    has_table_privilege('authenticated', 'public.admin_activity_logs', 'DELETE') AS authenticated_can_delete_audit;
