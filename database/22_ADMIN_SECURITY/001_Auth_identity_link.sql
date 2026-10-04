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
