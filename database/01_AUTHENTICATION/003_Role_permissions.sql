-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/003_Role_permissions.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- role_permissions | Purpose: M:N link roles <-> permissions.
-- Keys : COMPOSITE PK(role_id, permission_id)
-- Rel  : N:1 roles, N:1 permissions
-- BCNF : only determinant is the composite key; granted_at depends on the whole pair.
-- ---------------------------------------------------------------------
CREATE TABLE role_permissions (
    role_id        SMALLINT   NOT NULL,
    permission_id  SMALLINT   NOT NULL,
    created_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_role_permissions PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role       FOREIGN KEY (role_id)       REFERENCES roles (role_id)             ON DELETE CASCADE,
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions (permission_id) ON DELETE CASCADE
);
