# 22_ADMIN_SECURITY

Final application-admin security module applied after V3.

## Design
- Exactly one Primary Admin.
- Primary Admin is the existing Supabase Auth account `caged.dragon.official@gmail.com`.
- Primary Admin can manage other administrators through `ADMIN.MANAGE`.
- Primary Admin can monitor administrator activity through `ADMIN.AUDIT.MONITOR`.
- Other administrators may retain their normal website-management permissions but do not receive `ADMIN.MANAGE`.
- `admin_activity_logs` is protected from UPDATE/DELETE by `anon` and `authenticated` roles.
- `public.users.auth_user_id` links application identity to Supabase Auth.

## Files
1. `001_Auth_identity_link.sql`
2. `002_Primary_admin.sql`
3. `003_Primary_admin_permissions.sql`
4. `004_Admin_audit_protection.sql`
5. `005_Verification.sql`

Run in this order, after base + V2 + V3.
