-- =====================================================================
-- RT CRACKERS | 02_ADMIN/003_Admin_permissions.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- admin_permissions | Purpose: per-admin permission overrides (grant or explicit deny).
-- Keys : COMPOSITE PK(admin_id, permission_id)
-- Rel  : N:1 admins, N:1 permissions
-- BCNF : is_granted/granted_by depend on the whole pair.
-- ---------------------------------------------------------------------
CREATE TABLE admin_permissions (
    admin_id       INTEGER    NOT NULL,
    permission_id  SMALLINT   NOT NULL,
    is_granted     BOOLEAN    NOT NULL DEFAULT TRUE,
    granted_by     INTEGER,
    created_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_admin_permissions PRIMARY KEY (admin_id, permission_id),
    CONSTRAINT fk_admin_permissions_admin      FOREIGN KEY (admin_id)      REFERENCES admins (admin_id)           ON DELETE CASCADE,
    CONSTRAINT fk_admin_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions (permission_id) ON DELETE CASCADE,
    CONSTRAINT fk_admin_permissions_granted_by FOREIGN KEY (granted_by)    REFERENCES admins (admin_id)           ON DELETE SET NULL
);
