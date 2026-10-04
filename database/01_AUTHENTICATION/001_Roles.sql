-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/001_Roles.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- roles | Purpose: named bundles of permissions (customer-side 'U' and admin-side 'A').
-- Keys : PK(role_id) | CK/AK: role_code, role_name
-- Rel  : 1:N role_permissions, user_roles, admin_roles
-- BCNF : every non-key attribute depends only on role_id; role_code and role_name are candidate keys.
-- ---------------------------------------------------------------------
CREATE TABLE roles (
    role_id      SMALLINT     GENERATED ALWAYS AS IDENTITY,
    role_code    VARCHAR(30)  NOT NULL,
    role_name    VARCHAR(60)  NOT NULL,
    role_scope   CHAR(1)      NOT NULL DEFAULT 'U',      -- U=user side, A=admin side
    description  VARCHAR(255),
    is_system    BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_roles           PRIMARY KEY (role_id),
    CONSTRAINT uq_roles_role_code UNIQUE (role_code),
    CONSTRAINT uq_roles_role_name UNIQUE (role_name),
    CONSTRAINT ck_roles_role_scope CHECK (role_scope IN ('U','A')),
    CONSTRAINT ck_roles_role_code_upper CHECK (role_code = UPPER(role_code))
);
