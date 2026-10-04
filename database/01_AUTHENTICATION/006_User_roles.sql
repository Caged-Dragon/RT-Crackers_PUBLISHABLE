-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/006_User_roles.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- user_roles | Purpose: M:N user <-> role (customer-side roles).
-- Keys : COMPOSITE PK(user_id, role_id)
-- Rel  : N:1 users, N:1 roles, N:1 users (assigned_by)
-- BCNF : assigned_by depends on the whole pair only.
-- ---------------------------------------------------------------------
CREATE TABLE user_roles (
    user_id      BIGINT     NOT NULL,
    role_id      SMALLINT   NOT NULL,
    assigned_by  BIGINT,
    created_at   TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user        FOREIGN KEY (user_id)     REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role        FOREIGN KEY (role_id)     REFERENCES roles (role_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_assigned_by FOREIGN KEY (assigned_by) REFERENCES users (user_id) ON DELETE SET NULL
);
