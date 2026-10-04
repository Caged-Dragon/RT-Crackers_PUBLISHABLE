-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/002_Permissions.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- permissions | Purpose: atomic capabilities, e.g. PRODUCT.MANAGE.
-- Keys : PK(permission_id) | CK/AK: permission_code
-- Rel  : 1:N role_permissions, admin_permissions
-- BCNF : module/description depend only on the permission.
-- ---------------------------------------------------------------------
CREATE TABLE permissions (
    permission_id    SMALLINT     GENERATED ALWAYS AS IDENTITY,
    permission_code  VARCHAR(60)  NOT NULL,
    module_name      VARCHAR(40)  NOT NULL,
    description      VARCHAR(255),
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_permissions PRIMARY KEY (permission_id),
    CONSTRAINT uq_permissions_permission_code UNIQUE (permission_code),
    CONSTRAINT ck_permissions_code_upper CHECK (permission_code = UPPER(permission_code))
);
