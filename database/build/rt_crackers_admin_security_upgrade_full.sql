-- =====================================================================
-- RT CRACKERS | 22_ADMIN_SECURITY/001_Auth_identity_link.sql
-- Purpose: link application users to Supabase Auth identities.
-- =====================================================================

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS auth_user_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_auth_user_id
    ON public.users (auth_user_id)
    WHERE auth_user_id IS NOT NULL;

-- Supabase Auth owns credentials. public.users is application identity.
ALTER TABLE public.users
    ALTER COLUMN password_hash DROP NOT NULL;

COMMENT ON COLUMN public.users.auth_user_id IS
'Supabase auth.users.id for browser-authenticated application users.';
-- =====================================================================
-- RT CRACKERS | 22_ADMIN_SECURITY/002_Primary_admin.sql
-- Primary Admin: caged.dragon.official@gmail.com
-- Auth UUID: f96528ac-4322-4082-b707-d62bebdfcffe
-- =====================================================================

ALTER TABLE public.admins
    ADD COLUMN IF NOT EXISTS is_primary_admin BOOLEAN NOT NULL DEFAULT FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS uq_admins_one_primary_admin
    ON public.admins (is_primary_admin)
    WHERE is_primary_admin = TRUE;

ALTER TABLE public.admins
    DROP CONSTRAINT IF EXISTS ck_admins_primary_active;

ALTER TABLE public.admins
    ADD CONSTRAINT ck_admins_primary_active
    CHECK (NOT is_primary_admin OR status = 'A');

DO $$
DECLARE
    v_auth_id UUID := 'f96528ac-4322-4082-b707-d62bebdfcffe';
    v_email TEXT := 'caged.dragon.official@gmail.com';
    v_user_id BIGINT;
    v_admin_id INTEGER;
    v_employee_code TEXT;
    v_n INTEGER := 1;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM auth.users
        WHERE id = v_auth_id
          AND lower(email) = lower(v_email)
    ) THEN
        RAISE EXCEPTION
          'Primary Admin setup aborted: supplied Supabase Auth account was not found.';
    END IF;

    SELECT user_id INTO v_user_id
    FROM public.users
    WHERE auth_user_id = v_auth_id
       OR lower(email) = lower(v_email)
    ORDER BY CASE WHEN auth_user_id = v_auth_id THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_user_id IS NULL THEN
        INSERT INTO public.users (
            email, phone, first_name, last_name, password_hash, auth_user_id
        ) VALUES (
            v_email, '8438182960', 'Caged', 'Dragon', NULL, v_auth_id
        )
        RETURNING user_id INTO v_user_id;
    ELSE
        UPDATE public.users
        SET email = v_email,
            phone = '8438182960',
            first_name = 'Caged',
            last_name = 'Dragon',
            auth_user_id = v_auth_id
        WHERE user_id = v_user_id;
    END IF;

    SELECT admin_id INTO v_admin_id
    FROM public.admins
    WHERE user_id = v_user_id
    LIMIT 1;

    IF v_admin_id IS NULL THEN
        LOOP
            v_employee_code := 'PA-' || lpad(v_n::text, 3, '0');
            EXIT WHEN NOT EXISTS (
                SELECT 1 FROM public.admins WHERE employee_code = v_employee_code
            );
            v_n := v_n + 1;
        END LOOP;

        INSERT INTO public.admins (
            user_id, employee_code, designation, status, is_primary_admin
        ) VALUES (
            v_user_id, v_employee_code, 'Primary Administrator', 'A', TRUE
        )
        RETURNING admin_id INTO v_admin_id;
    ELSE
        UPDATE public.admins
        SET status = 'A',
            is_primary_admin = TRUE,
            designation = COALESCE(designation, 'Primary Administrator')
        WHERE admin_id = v_admin_id;
    END IF;

    UPDATE public.admins
    SET is_primary_admin = FALSE
    WHERE admin_id <> v_admin_id
      AND is_primary_admin = TRUE;
END $$;
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
