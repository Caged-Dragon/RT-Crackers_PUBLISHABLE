-- =====================================================================
-- RT CRACKERS | 99_DEPLOYMENT/008_Admin_security_build.sql
-- Run AFTER base + seed + V2 + V3.
-- psql only: run from database root.
-- =====================================================================

BEGIN;

\i 22_ADMIN_SECURITY/001_Auth_identity_link.sql
\i 22_ADMIN_SECURITY/002_Primary_admin.sql
\i 22_ADMIN_SECURITY/003_Primary_admin_permissions.sql
\i 22_ADMIN_SECURITY/004_Admin_audit_protection.sql
\i 22_ADMIN_SECURITY/005_Verification.sql

COMMIT;
