-- =====================================================================
-- RT CRACKERS | 02_ADMIN/002_Admin_roles.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- admin_roles | Purpose: M:N admin <-> role (roles with scope 'A').
-- Keys : COMPOSITE PK(admin_id, role_id)
-- Rel  : N:1 admins, N:1 roles, N:1 admins (assigned_by)
-- BCNF : assigned_by depends on the whole pair only.
-- ---------------------------------------------------------------------
CREATE TABLE admin_roles (
    admin_id     INTEGER    NOT NULL,
    role_id      SMALLINT   NOT NULL,
    assigned_by  INTEGER,
    created_at   TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_admin_roles PRIMARY KEY (admin_id, role_id),
    CONSTRAINT fk_admin_roles_admin       FOREIGN KEY (admin_id)    REFERENCES admins (admin_id) ON DELETE CASCADE,
    CONSTRAINT fk_admin_roles_role        FOREIGN KEY (role_id)     REFERENCES roles (role_id)   ON DELETE CASCADE,
    CONSTRAINT fk_admin_roles_assigned_by FOREIGN KEY (assigned_by) REFERENCES admins (admin_id) ON DELETE SET NULL
);
