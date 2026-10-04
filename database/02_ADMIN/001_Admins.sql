-- =====================================================================
-- RT CRACKERS | 02_ADMIN/001_Admins.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- admins | Purpose: staff profile attached to a user login (managers, delivery agents...).
-- Keys : PK(admin_id) | CK/AK: user_id, employee_code
-- Rel  : 1:1 users; 1:N admin_roles, admin_permissions, admin_activity_logs, admin_notifications
-- BCNF : staff attributes depend on admin_id; identity data stays in users.
-- ---------------------------------------------------------------------
CREATE TABLE admins (
    admin_id          INTEGER      GENERATED ALWAYS AS IDENTITY,
    user_id           BIGINT       NOT NULL,
    employee_code     VARCHAR(20)  NOT NULL,
    department        VARCHAR(50),
    designation       VARCHAR(60),
    hired_date        DATE,
    status            CHAR(1)      NOT NULL DEFAULT 'A',       -- A active, I inactive, S suspended
    last_admin_login  TIMESTAMP,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_admins PRIMARY KEY (admin_id),
    CONSTRAINT uq_admins_user_id       UNIQUE (user_id),
    CONSTRAINT uq_admins_employee_code UNIQUE (employee_code),
    CONSTRAINT fk_admins_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT ck_admins_status CHECK (status IN ('A','I','S'))
);
