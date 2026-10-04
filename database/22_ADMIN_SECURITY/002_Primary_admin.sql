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
