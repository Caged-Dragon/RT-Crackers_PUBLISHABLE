-- RT CRACKERS full build (generated from the module files; do not edit by hand)

BEGIN;

-- =====================================================================
-- RT CRACKERS | 00_SETUP/002_Sequences.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE SEQUENCE seq_order_number       START 1;
CREATE SEQUENCE seq_invoice_number     START 1;
CREATE SEQUENCE seq_return_number      START 1;
CREATE SEQUENCE seq_replacement_number START 1;
CREATE SEQUENCE seq_cod_receipt        START 1;

-- =====================================================================
-- RT CRACKERS | 00_SETUP/003_Helper_functions.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

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

-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/004_Users.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- users | Purpose: every account (customer or staff login identity).
-- Keys : PK(user_id) | CK/AK: email, phone, referral_code
-- Rel  : self N:1 (referred_by); 1:1 user_profiles, admins; 1:N addresses, orders, reviews, carts...
-- BCNF : all attributes describe one account; contact/profile extras live in user_profiles.
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id               BIGINT        GENERATED ALWAYS AS IDENTITY,
    email                 VARCHAR(255)  NOT NULL,
    password_hash         VARCHAR(255)  NOT NULL,
    phone                 CHAR(10)      NOT NULL,
    first_name            VARCHAR(60)   NOT NULL,
    middle_name           VARCHAR(60),
    last_name             VARCHAR(60),
    gender                CHAR(1),                              -- M, F, O
    dob                   DATE,
    profile_image         VARCHAR(500),
    status                CHAR(1)       NOT NULL DEFAULT 'A',   -- A active, I inactive, S suspended, B blocked, D deleted
    email_verified        BOOLEAN       NOT NULL DEFAULT FALSE,
    phone_verified        BOOLEAN       NOT NULL DEFAULT FALSE,
    failed_login_count    SMALLINT      NOT NULL DEFAULT 0,
    account_locked        BOOLEAN       NOT NULL DEFAULT FALSE,
    last_login            TIMESTAMP,
    last_password_change  TIMESTAMP,
    preferred_language    CHAR(2)       NOT NULL DEFAULT 'en',
    preferred_currency    CHAR(3)       NOT NULL DEFAULT 'INR',
    referral_code         VARCHAR(12)   NOT NULL DEFAULT UPPER(SUBSTRING(MD5(RANDOM()::TEXT || CLOCK_TIMESTAMP()::TEXT) FROM 1 FOR 8)),
    referred_by           BIGINT,
    created_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_users PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email         UNIQUE (email),
    CONSTRAINT uq_users_phone         UNIQUE (phone),
    CONSTRAINT uq_users_referral_code UNIQUE (referral_code),
    CONSTRAINT fk_users_referred_by   FOREIGN KEY (referred_by) REFERENCES users (user_id) ON DELETE SET NULL,
    CONSTRAINT ck_users_email_format  CHECK (email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT ck_users_email_lower   CHECK (email = LOWER(email)),
    CONSTRAINT ck_users_phone_format  CHECK (phone ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_users_gender        CHECK (gender IS NULL OR gender IN ('M','F','O')),
    CONSTRAINT ck_users_status        CHECK (status IN ('A','I','S','B','D')),
    CONSTRAINT ck_users_failed_login  CHECK (failed_login_count >= 0),
    CONSTRAINT ck_users_dob_adult     CHECK (dob IS NULL OR dob <= CURRENT_DATE - INTERVAL '18 years'),  -- fireworks: buyers must be 18+
    CONSTRAINT ck_users_self_referral CHECK (referred_by IS NULL OR referred_by <> user_id)
);

-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/005_User_profiles.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- user_profiles | Purpose: optional 1:1 profile/consent extras kept out of users.
-- Keys : PK(user_id) which is also FK
-- Rel  : 1:1 users
-- BCNF : sole determinant is user_id (the key).
-- ---------------------------------------------------------------------
CREATE TABLE user_profiles (
    user_id             BIGINT       NOT NULL,
    display_name        VARCHAR(100),
    bio                 TEXT,
    alternate_phone     CHAR(10),
    whatsapp_number     CHAR(10),
    occupation          VARCHAR(80),
    timezone            VARCHAR(50)  NOT NULL DEFAULT 'Asia/Kolkata',
    age_verified        BOOLEAN      NOT NULL DEFAULT FALSE,
    age_verified_at     TIMESTAMP,
    email_opt_in        BOOLEAN      NOT NULL DEFAULT TRUE,
    sms_opt_in          BOOLEAN      NOT NULL DEFAULT TRUE,
    whatsapp_opt_in     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user_profiles PRIMARY KEY (user_id),
    CONSTRAINT fk_user_profiles_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_user_profiles_alt_phone CHECK (alternate_phone IS NULL OR alternate_phone ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_user_profiles_whatsapp  CHECK (whatsapp_number IS NULL OR whatsapp_number ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_user_profiles_age_verified CHECK (age_verified = (age_verified_at IS NOT NULL))
);

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

-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/007_Sessions.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- sessions | Purpose: server-side login sessions (one per device login).
-- Keys : PK(session_id UUID)
-- Rel  : N:1 users; 1:N refresh_tokens, login_history
-- BCNF : all columns describe the session itself.
-- ---------------------------------------------------------------------
CREATE TABLE sessions (
    session_id        UUID         NOT NULL DEFAULT gen_random_uuid(),
    user_id           BIGINT       NOT NULL,
    ip_address        INET,
    user_agent        VARCHAR(500),
    device_type       CHAR(1)      NOT NULL DEFAULT 'W',     -- W web, M mobile, T tablet, O other
    last_activity_at  TIMESTAMP,
    expires_at        TIMESTAMP    NOT NULL,
    ended_at          TIMESTAMP,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_sessions PRIMARY KEY (session_id),
    CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_sessions_device_type CHECK (device_type IN ('W','M','T','O')),
    CONSTRAINT ck_sessions_expiry      CHECK (expires_at > created_at)
);

-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/008_Refresh_tokens.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- refresh_tokens | Purpose: hashed JWT refresh tokens with rotation chain.
-- Keys : PK(refresh_token_id) | CK/AK: token_hash
-- Rel  : N:1 users, N:1 sessions, self 1:1 (replaced_by_token_id)
-- BCNF : every attribute depends on the token row only.
-- ---------------------------------------------------------------------
CREATE TABLE refresh_tokens (
    refresh_token_id      BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id               BIGINT        NOT NULL,
    session_id            UUID,
    token_hash            VARCHAR(255)  NOT NULL,              -- never store the raw token
    expires_at            TIMESTAMP     NOT NULL,
    revoked_at            TIMESTAMP,
    replaced_by_token_id  BIGINT,
    created_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_refresh_tokens PRIMARY KEY (refresh_token_id),
    CONSTRAINT uq_refresh_tokens_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_refresh_tokens_user     FOREIGN KEY (user_id)    REFERENCES users (user_id)       ON DELETE CASCADE,
    CONSTRAINT fk_refresh_tokens_session  FOREIGN KEY (session_id) REFERENCES sessions (session_id) ON DELETE CASCADE,
    CONSTRAINT fk_refresh_tokens_replaced FOREIGN KEY (replaced_by_token_id) REFERENCES refresh_tokens (refresh_token_id) ON DELETE SET NULL,
    CONSTRAINT ck_refresh_tokens_expiry   CHECK (expires_at > created_at)
);

-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/009_Login_history.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- login_history | Purpose: append-only audit of every login attempt.
-- Keys : PK(login_id)
-- Rel  : N:1 users (null for unknown e-mail), N:1 sessions
-- BCNF : attributes describe the single attempt.
-- ---------------------------------------------------------------------
CREATE TABLE login_history (
    login_id         BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id          BIGINT,
    attempted_email  VARCHAR(255)  NOT NULL,
    login_status     CHAR(1)       NOT NULL,                   -- S success, F failed, L blocked by lock
    failure_reason   VARCHAR(100),
    ip_address       INET,
    user_agent       VARCHAR(500),
    session_id       UUID,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_login_history PRIMARY KEY (login_id),
    CONSTRAINT fk_login_history_user    FOREIGN KEY (user_id)    REFERENCES users (user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_login_history_session FOREIGN KEY (session_id) REFERENCES sessions (session_id) ON DELETE SET NULL,
    CONSTRAINT ck_login_history_status  CHECK (login_status IN ('S','F','L'))
);

-- =====================================================================
-- RT CRACKERS | 01_AUTHENTICATION/010_Password_reset_tokens.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- password_reset_tokens | Purpose: single-use password reset links (hashed).
-- Keys : PK(token_id) | CK/AK: token_hash
-- Rel  : N:1 users
-- BCNF : attributes depend on the token row only.
-- ---------------------------------------------------------------------
CREATE TABLE password_reset_tokens (
    token_id      BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id       BIGINT        NOT NULL,
    token_hash    VARCHAR(255)  NOT NULL,
    requested_ip  INET,
    expires_at    TIMESTAMP     NOT NULL,
    used_at       TIMESTAMP,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_password_reset_tokens PRIMARY KEY (token_id),
    CONSTRAINT uq_password_reset_tokens_hash UNIQUE (token_hash),
    CONSTRAINT fk_password_reset_tokens_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_password_reset_tokens_expiry CHECK (expires_at > created_at)
);

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

-- =====================================================================
-- RT CRACKERS | 02_ADMIN/004_Admin_activity_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- admin_activity_logs | Purpose: append-only trail of admin actions.
-- Keys : PK(log_id)
-- Rel  : N:1 admins
-- BCNF : attributes describe one action.
-- ---------------------------------------------------------------------
CREATE TABLE admin_activity_logs (
    log_id       BIGINT        GENERATED ALWAYS AS IDENTITY,
    admin_id     INTEGER       NOT NULL,
    action       VARCHAR(100)  NOT NULL,
    module_name  VARCHAR(40),
    entity_type  VARCHAR(40),
    entity_id    VARCHAR(64),
    details      JSONB,
    ip_address   INET,
    user_agent   VARCHAR(500),
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_admin_activity_logs PRIMARY KEY (log_id),
    CONSTRAINT fk_admin_activity_logs_admin FOREIGN KEY (admin_id) REFERENCES admins (admin_id) ON DELETE RESTRICT
);

-- =====================================================================
-- RT CRACKERS | 02_ADMIN/005_Admin_notifications.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- admin_notifications | Purpose: in-dashboard alerts for staff (low stock, new COD order...).
-- Keys : PK(admin_notification_id)
-- Rel  : N:1 admins
-- BCNF : attributes describe one alert.
-- ---------------------------------------------------------------------
CREATE TABLE admin_notifications (
    admin_notification_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    admin_id               INTEGER       NOT NULL,
    title                  VARCHAR(150)  NOT NULL,
    message                TEXT          NOT NULL,
    severity               CHAR(1)       NOT NULL DEFAULT 'I',  -- I info, W warning, C critical
    reference_type         VARCHAR(40),
    reference_id           VARCHAR(64),
    is_read                BOOLEAN       NOT NULL DEFAULT FALSE,
    read_at                TIMESTAMP,
    created_at             TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_admin_notifications PRIMARY KEY (admin_notification_id),
    CONSTRAINT fk_admin_notifications_admin FOREIGN KEY (admin_id) REFERENCES admins (admin_id) ON DELETE CASCADE,
    CONSTRAINT ck_admin_notifications_severity CHECK (severity IN ('I','W','C')),
    CONSTRAINT ck_admin_notifications_read     CHECK (is_read = (read_at IS NOT NULL))
);

-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/001_Delivery_zones.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- delivery_zones | Purpose: groups of pincodes sharing delivery rules.
-- Keys : PK(zone_id) | CK/AK: zone_code, zone_name
-- Rel  : 1:N pincodes, zone_shipping_rates
-- BCNF : attributes depend only on the zone.
-- ---------------------------------------------------------------------
CREATE TABLE delivery_zones (
    zone_id            SMALLINT     GENERATED ALWAYS AS IDENTITY,
    zone_code          VARCHAR(10)  NOT NULL,
    zone_name          VARCHAR(80)  NOT NULL,
    description        VARCHAR(255),
    order_cutoff_time  TIME         NOT NULL DEFAULT '16:00',
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_delivery_zones PRIMARY KEY (zone_id),
    CONSTRAINT uq_delivery_zones_zone_code UNIQUE (zone_code),
    CONSTRAINT uq_delivery_zones_zone_name UNIQUE (zone_name)
);

-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/002_Pincodes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- pincodes | Purpose: serviceable-area master; owns district/state/country so addresses stay BCNF.
-- Keys : PK(pincode)
-- Rel  : N:1 delivery_zones; 1:N addresses
-- BCNF : pincode -> district, state, country, zone (pincode is the key). Removing these from
--        addresses eliminates the transitive dependency postal_code -> district/state.
-- ---------------------------------------------------------------------
CREATE TABLE pincodes (
    pincode         CHAR(6)      NOT NULL,
    district        VARCHAR(80)  NOT NULL,
    state           VARCHAR(80)  NOT NULL,
    country_code    CHAR(2)      NOT NULL DEFAULT 'IN',
    zone_id         SMALLINT     NOT NULL,
    is_serviceable  BOOLEAN      NOT NULL DEFAULT FALSE,   -- fireworks are restricted in some areas
    cod_available   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_pincodes PRIMARY KEY (pincode),
    CONSTRAINT fk_pincodes_zone FOREIGN KEY (zone_id) REFERENCES delivery_zones (zone_id) ON DELETE RESTRICT,
    CONSTRAINT ck_pincodes_format CHECK (pincode ~ '^[1-9][0-9]{5}$')
);

-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/003_Shipping_methods.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- shipping_methods | Purpose: delivery speeds offered (standard, express).
-- Keys : PK(shipping_method_id) | CK/AK: method_code, method_name
-- Rel  : 1:N zone_shipping_rates, orders
-- BCNF : attributes depend only on the method; price depends on (zone, method) so lives in zone_shipping_rates.
-- ---------------------------------------------------------------------
CREATE TABLE shipping_methods (
    shipping_method_id  SMALLINT     GENERATED ALWAYS AS IDENTITY,
    method_code         VARCHAR(10)  NOT NULL,
    method_name         VARCHAR(60)  NOT NULL,
    description         VARCHAR(255),
    min_delivery_days   SMALLINT     NOT NULL DEFAULT 1,
    max_delivery_days   SMALLINT     NOT NULL DEFAULT 7,
    slot_start          TIME,
    slot_end            TIME,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_shipping_methods PRIMARY KEY (shipping_method_id),
    CONSTRAINT uq_shipping_methods_method_code UNIQUE (method_code),
    CONSTRAINT uq_shipping_methods_method_name UNIQUE (method_name),
    CONSTRAINT ck_shipping_methods_days CHECK (min_delivery_days >= 0 AND max_delivery_days >= min_delivery_days),
    CONSTRAINT ck_shipping_methods_slot CHECK (slot_start IS NULL OR slot_end IS NULL OR slot_start < slot_end)
);

-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/009_Zone_shipping_rates.sql
-- Source: rt_crackers_schema.sql (split by module) | extra file, not in original tree
-- =====================================================================

-- ---------------------------------------------------------------------
-- zone_shipping_rates | Purpose: shipping price per (zone, method).
-- Keys : COMPOSITE PK(zone_id, shipping_method_id)
-- Rel  : N:1 delivery_zones, N:1 shipping_methods
-- BCNF : charges depend on the full composite key, not on either half.
-- ---------------------------------------------------------------------
CREATE TABLE zone_shipping_rates (
    zone_id                  SMALLINT       NOT NULL,
    shipping_method_id       SMALLINT       NOT NULL,
    base_charge              NUMERIC(10,2)  NOT NULL DEFAULT 0,
    per_kg_charge            NUMERIC(10,2)  NOT NULL DEFAULT 0,
    free_shipping_threshold  NUMERIC(12,2),
    is_active                BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at               TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_zone_shipping_rates PRIMARY KEY (zone_id, shipping_method_id),
    CONSTRAINT fk_zone_shipping_rates_zone   FOREIGN KEY (zone_id)            REFERENCES delivery_zones (zone_id)            ON DELETE CASCADE,
    CONSTRAINT fk_zone_shipping_rates_method FOREIGN KEY (shipping_method_id) REFERENCES shipping_methods (shipping_method_id) ON DELETE CASCADE,
    CONSTRAINT ck_zone_shipping_rates_charges CHECK (base_charge >= 0 AND per_kg_charge >= 0),
    CONSTRAINT ck_zone_shipping_rates_free    CHECK (free_shipping_threshold IS NULL OR free_shipping_threshold > 0)
);

-- =====================================================================
-- RT CRACKERS | 06_CUSTOMERS/001_Addresses.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- addresses | Purpose: a user's delivery/billing addresses. district/state/country come from pincodes
--             (see view v_addresses_full which exposes them as columns).
-- Keys : PK(address_id)
-- Rel  : N:1 users, N:1 pincodes; 1:N orders (billing/shipping), 1:1 saved_addresses
-- BCNF : every attribute depends on address_id; postal_code's dependents were moved out. Rows referenced by
--        an order are immutable (trigger) so order history stays correct.
-- ---------------------------------------------------------------------
CREATE TABLE addresses (
    address_id       BIGINT            GENERATED ALWAYS AS IDENTITY,
    user_id          BIGINT            NOT NULL,
    recipient_name   VARCHAR(120)      NOT NULL,
    recipient_phone  CHAR(10)          NOT NULL,
    house_no         VARCHAR(30)       NOT NULL,
    street           VARCHAR(150)      NOT NULL,
    area             VARCHAR(100)      NOT NULL,
    landmark         VARCHAR(150),
    city             VARCHAR(80)       NOT NULL,
    postal_code      CHAR(6)           NOT NULL,
    latitude         DOUBLE PRECISION,
    longitude        DOUBLE PRECISION,
    address_type     CHAR(1)           NOT NULL DEFAULT 'H',   -- H home, W work, O other
    is_default       BOOLEAN           NOT NULL DEFAULT FALSE,
    is_archived      BOOLEAN           NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_addresses PRIMARY KEY (address_id),
    CONSTRAINT fk_addresses_user    FOREIGN KEY (user_id)     REFERENCES users (user_id)       ON DELETE CASCADE,
    CONSTRAINT fk_addresses_pincode FOREIGN KEY (postal_code) REFERENCES pincodes (pincode)    ON DELETE RESTRICT,
    CONSTRAINT ck_addresses_phone   CHECK (recipient_phone ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT ck_addresses_type    CHECK (address_type IN ('H','W','O')),
    CONSTRAINT ck_addresses_latitude  CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_addresses_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);
CREATE UNIQUE INDEX uq_addresses_one_default_per_user ON addresses (user_id) WHERE is_default AND NOT is_archived;

CREATE VIEW v_addresses_full AS
SELECT a.address_id, a.user_id, a.recipient_name, a.recipient_phone, a.house_no, a.street, a.area,
       a.landmark, a.city, p.district, p.state, p.country_code AS country, a.postal_code,
       a.latitude, a.longitude, a.address_type, a.is_default, a.is_archived, a.created_at, a.updated_at
FROM addresses a
JOIN pincodes p ON p.pincode = a.postal_code;

-- addresses used by an order are immutable (create a new address instead)
CREATE OR REPLACE FUNCTION fn_protect_used_address()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF ROW(NEW.recipient_name, NEW.recipient_phone, NEW.house_no, NEW.street, NEW.area, NEW.landmark, NEW.city, NEW.postal_code)
       IS DISTINCT FROM
       ROW(OLD.recipient_name, OLD.recipient_phone, OLD.house_no, OLD.street, OLD.area, OLD.landmark, OLD.city, OLD.postal_code)
       AND EXISTS (SELECT 1 FROM orders WHERE billing_address_id = OLD.address_id OR shipping_address_id = OLD.address_id)
    THEN
        RAISE EXCEPTION 'Address % is referenced by an order and cannot be edited; create a new address and archive this one', OLD.address_id;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_addresses_protect_used BEFORE UPDATE ON addresses
    FOR EACH ROW EXECUTE FUNCTION fn_protect_used_address();

-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/001_Categories.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- categories | Purpose: top-level catalogue groups (Sparklers, Rockets, Gift Boxes...).
-- Keys : PK(category_id) | CK/AK: category_name, slug
-- Rel  : 1:N subcategories, products, festival_discounts
-- BCNF : attributes depend only on the category.
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    category_id    INTEGER       GENERATED ALWAYS AS IDENTITY,
    category_name  VARCHAR(100)  NOT NULL,
    slug           VARCHAR(120)  NOT NULL,
    description    TEXT,
    image_url      VARCHAR(500),
    display_order  SMALLINT      NOT NULL DEFAULT 0,
    is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_categories PRIMARY KEY (category_id),
    CONSTRAINT uq_categories_category_name UNIQUE (category_name),
    CONSTRAINT uq_categories_slug          UNIQUE (slug)
);

-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/002_Subcategories.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- subcategories | Purpose: second-level grouping inside a category.
-- Keys : PK(subcategory_id) | CK/AK: slug, (category_id, subcategory_name), (category_id, subcategory_id)
-- Rel  : N:1 categories; 1:N products
-- BCNF : attributes depend on subcategory_id; (category_id, subcategory_id) unique pair supports products' composite FK.
-- ---------------------------------------------------------------------
CREATE TABLE subcategories (
    subcategory_id    INTEGER       GENERATED ALWAYS AS IDENTITY,
    category_id       INTEGER       NOT NULL,
    subcategory_name  VARCHAR(100)  NOT NULL,
    slug              VARCHAR(120)  NOT NULL,
    description       TEXT,
    image_url         VARCHAR(500),
    display_order     SMALLINT      NOT NULL DEFAULT 0,
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_subcategories PRIMARY KEY (subcategory_id),
    CONSTRAINT uq_subcategories_slug              UNIQUE (slug),
    CONSTRAINT uq_subcategories_category_name     UNIQUE (category_id, subcategory_name),
    CONSTRAINT uq_subcategories_category_sub      UNIQUE (category_id, subcategory_id),
    CONSTRAINT fk_subcategories_category FOREIGN KEY (category_id) REFERENCES categories (category_id) ON DELETE RESTRICT
);

-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/003_Brands.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- brands | Purpose: product brands/labels.
-- Keys : PK(brand_id) | CK/AK: brand_name, slug
-- Rel  : 1:N products
-- BCNF : attributes depend only on the brand.
-- ---------------------------------------------------------------------
CREATE TABLE brands (
    brand_id     INTEGER       GENERATED ALWAYS AS IDENTITY,
    brand_name   VARCHAR(100)  NOT NULL,
    slug         VARCHAR(120)  NOT NULL,
    logo_url     VARCHAR(500),
    description  TEXT,
    website_url  VARCHAR(255),
    is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_brands PRIMARY KEY (brand_id),
    CONSTRAINT uq_brands_brand_name UNIQUE (brand_name),
    CONSTRAINT uq_brands_slug       UNIQUE (slug)
);

-- =====================================================================
-- RT CRACKERS | 04_PRODUCTS/001_Products.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- products | Purpose: sellable product master.
-- Keys : PK(product_id) | CK/AK: sku, barcode, slug
-- Rel  : N:1 categories, subcategories (composite FK keeps them consistent), brands;
--        1:N images, variants, attribute_values, inventory, reviews, order_items...
-- BCNF : discount_percentage and (via triggers) stock_quantity / rating_* / sales_count / view_count are
--        derived, so they are GENERATED or trigger-maintained and cannot drift. category_id is retained next
--        to the nullable subcategory_id; the composite FK (category_id, subcategory_id) pins them together.
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id           BIGINT         GENERATED ALWAYS AS IDENTITY,
    category_id          INTEGER        NOT NULL,
    subcategory_id       INTEGER,
    brand_id             INTEGER,
    sku                  VARCHAR(40)    NOT NULL,
    barcode              VARCHAR(32),
    slug                 VARCHAR(200)   NOT NULL,
    product_name         VARCHAR(200)   NOT NULL,
    short_description    VARCHAR(500),
    description          TEXT,
    mrp                  NUMERIC(12,2)  NOT NULL,
    selling_price        NUMERIC(12,2)  NOT NULL,
    cost_price           NUMERIC(12,2)  NOT NULL,
    discount_percentage  NUMERIC(5,2)   GENERATED ALWAYS AS (ROUND((mrp - selling_price) * 100 / NULLIF(mrp, 0), 2)) STORED,
    weight               NUMERIC(10,3)  NOT NULL DEFAULT 0,      -- kg
    length               NUMERIC(8,2)   NOT NULL DEFAULT 0,      -- cm
    width                NUMERIC(8,2)   NOT NULL DEFAULT 0,
    height               NUMERIC(8,2)   NOT NULL DEFAULT 0,
    gst_percentage       NUMERIC(5,2)   NOT NULL DEFAULT 18.00,
    country_of_origin    VARCHAR(60)    NOT NULL DEFAULT 'India',
    manufacturer         VARCHAR(150),
    warranty_period      SMALLINT       NOT NULL DEFAULT 0,      -- months
    safety_instructions  TEXT,
    stock_quantity       INTEGER        NOT NULL DEFAULT 0,      -- maintained from inventory
    min_stock_level      INTEGER        NOT NULL DEFAULT 0,
    max_stock_level      INTEGER        NOT NULL DEFAULT 1000,
    is_featured          BOOLEAN        NOT NULL DEFAULT FALSE,
    is_trending          BOOLEAN        NOT NULL DEFAULT FALSE,
    is_new_arrival       BOOLEAN        NOT NULL DEFAULT FALSE,
    status               CHAR(1)        NOT NULL DEFAULT 'D',    -- D draft, A active, I inactive, X archived
    meta_title           VARCHAR(160),
    meta_description     VARCHAR(320),
    meta_keywords        VARCHAR(255),
    view_count           INTEGER        NOT NULL DEFAULT 0,
    sales_count          INTEGER        NOT NULL DEFAULT 0,
    rating_average       NUMERIC(3,2)   NOT NULL DEFAULT 0,
    rating_count         INTEGER        NOT NULL DEFAULT 0,
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_products PRIMARY KEY (product_id),
    CONSTRAINT uq_products_sku     UNIQUE (sku),
    CONSTRAINT uq_products_barcode UNIQUE (barcode),
    CONSTRAINT uq_products_slug    UNIQUE (slug),
    CONSTRAINT fk_products_category    FOREIGN KEY (category_id) REFERENCES categories (category_id) ON DELETE RESTRICT,
    CONSTRAINT fk_products_subcategory FOREIGN KEY (category_id, subcategory_id) REFERENCES subcategories (category_id, subcategory_id) ON DELETE RESTRICT,
    CONSTRAINT fk_products_brand       FOREIGN KEY (brand_id) REFERENCES brands (brand_id) ON DELETE SET NULL,
    CONSTRAINT ck_products_mrp            CHECK (mrp > 0),
    CONSTRAINT ck_products_selling_price  CHECK (selling_price > 0),
    CONSTRAINT ck_products_cost_price     CHECK (cost_price > 0),
    CONSTRAINT ck_products_price_le_mrp   CHECK (selling_price <= mrp),
    CONSTRAINT ck_products_stock_qty      CHECK (stock_quantity >= 0),
    CONSTRAINT ck_products_discount_pct   CHECK (discount_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_products_dimensions     CHECK (weight >= 0 AND length >= 0 AND width >= 0 AND height >= 0),
    CONSTRAINT ck_products_gst            CHECK (gst_percentage BETWEEN 0 AND 40),
    CONSTRAINT ck_products_warranty       CHECK (warranty_period >= 0),
    CONSTRAINT ck_products_stock_levels   CHECK (min_stock_level >= 0 AND max_stock_level >= min_stock_level),
    CONSTRAINT ck_products_status         CHECK (status IN ('D','A','I','X')),
    CONSTRAINT ck_products_counters       CHECK (view_count >= 0 AND sales_count >= 0 AND rating_count >= 0),
    CONSTRAINT ck_products_rating_avg     CHECK (rating_average BETWEEN 0 AND 5)
);

-- =====================================================================
-- RT CRACKERS | 04_PRODUCTS/002_Product_images.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_images | Purpose: gallery images per product.
-- Keys : PK(product_image_id) | CK/AK: (product_id, image_url)
-- Rel  : N:1 products
-- BCNF : attributes depend on the image row.
-- ---------------------------------------------------------------------
CREATE TABLE product_images (
    product_image_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    product_id        BIGINT        NOT NULL,
    image_url         VARCHAR(500)  NOT NULL,
    alt_text          VARCHAR(200),
    is_primary        BOOLEAN       NOT NULL DEFAULT FALSE,
    display_order     SMALLINT      NOT NULL DEFAULT 0,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_images PRIMARY KEY (product_image_id),
    CONSTRAINT uq_product_images_product_url UNIQUE (product_id, image_url),
    CONSTRAINT fk_product_images_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX uq_product_images_one_primary ON product_images (product_id) WHERE is_primary;

-- =====================================================================
-- RT CRACKERS | 04_PRODUCTS/003_Product_variants.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_variants | Purpose: pack sizes / options with their own price (e.g. Box of 10, Box of 25).
-- Keys : PK(variant_id) | CK/AK: variant_sku, barcode, (product_id, variant_name), (product_id, variant_id)
-- Rel  : N:1 products; 1:N inventory, attribute_values, cart_items, order_items
-- BCNF : price/weight depend on the variant; (product_id, variant_id) pair enables composite FKs.
-- ---------------------------------------------------------------------
CREATE TABLE product_variants (
    variant_id     BIGINT         GENERATED ALWAYS AS IDENTITY,
    product_id     BIGINT         NOT NULL,
    variant_sku    VARCHAR(40)    NOT NULL,
    barcode        VARCHAR(32),
    variant_name   VARCHAR(120)   NOT NULL,
    pack_size      SMALLINT       NOT NULL DEFAULT 1,
    mrp            NUMERIC(12,2)  NOT NULL,
    selling_price  NUMERIC(12,2)  NOT NULL,
    cost_price     NUMERIC(12,2)  NOT NULL,
    weight         NUMERIC(10,3)  NOT NULL DEFAULT 0,
    is_active      BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_variants PRIMARY KEY (variant_id),
    CONSTRAINT uq_product_variants_sku      UNIQUE (variant_sku),
    CONSTRAINT uq_product_variants_barcode  UNIQUE (barcode),
    CONSTRAINT uq_product_variants_name     UNIQUE (product_id, variant_name),
    CONSTRAINT uq_product_variants_prod_var UNIQUE (product_id, variant_id),
    CONSTRAINT fk_product_variants_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT ck_product_variants_pack   CHECK (pack_size > 0),
    CONSTRAINT ck_product_variants_prices CHECK (mrp > 0 AND selling_price > 0 AND cost_price > 0 AND selling_price <= mrp),
    CONSTRAINT ck_product_variants_weight CHECK (weight >= 0)
);

-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/004_Product_attributes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_attributes | Purpose: attribute definitions (Shots, Duration, Noise level, Colour effect...).
-- Keys : PK(attribute_id) | CK/AK: attribute_code, attribute_name
-- Rel  : 1:N attribute_values
-- BCNF : attributes depend only on the attribute definition.
-- ---------------------------------------------------------------------
CREATE TABLE product_attributes (
    attribute_id    INTEGER      GENERATED ALWAYS AS IDENTITY,
    attribute_code  VARCHAR(40)  NOT NULL,
    attribute_name  VARCHAR(80)  NOT NULL,
    data_type       CHAR(1)      NOT NULL DEFAULT 'T',     -- T text, N number, B boolean
    unit            VARCHAR(20),
    is_filterable   BOOLEAN      NOT NULL DEFAULT FALSE,
    display_order   SMALLINT     NOT NULL DEFAULT 0,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_attributes PRIMARY KEY (attribute_id),
    CONSTRAINT uq_product_attributes_code UNIQUE (attribute_code),
    CONSTRAINT uq_product_attributes_name UNIQUE (attribute_name),
    CONSTRAINT ck_product_attributes_type CHECK (data_type IN ('T','N','B'))
);

-- =====================================================================
-- RT CRACKERS | 03_MASTER_DATA/005_Attribute_values.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- attribute_values | Purpose: value of an attribute for a product (or one of its variants).
-- Keys : PK(attribute_value_id) | CK/AK: (product_id, variant_id|0, attribute_id) via unique index
-- Rel  : N:1 products, product_variants (composite FK), product_attributes
-- BCNF : value_text depends on (product, variant, attribute) which is a candidate key.
-- ---------------------------------------------------------------------
CREATE TABLE attribute_values (
    attribute_value_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    product_id          BIGINT        NOT NULL,
    variant_id          BIGINT,
    attribute_id        INTEGER       NOT NULL,
    value_text          VARCHAR(255)  NOT NULL,
    created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_attribute_values PRIMARY KEY (attribute_value_id),
    CONSTRAINT fk_attribute_values_product   FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT fk_attribute_values_variant   FOREIGN KEY (product_id, variant_id) REFERENCES product_variants (product_id, variant_id) ON DELETE CASCADE,
    CONSTRAINT fk_attribute_values_attribute FOREIGN KEY (attribute_id) REFERENCES product_attributes (attribute_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX uq_attribute_values_target ON attribute_values (product_id, COALESCE(variant_id, 0), attribute_id);

-- =====================================================================
-- RT CRACKERS | 05_INVENTORY/001_Inventory.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- inventory | Purpose: current stock per product (or per variant) in the single store.
-- Keys : PK(inventory_id) | CK/AK: (product_id, variant_id|0) via unique index
-- Rel  : N:1 products, product_variants; 1:N inventory_movements
-- BCNF : quantities depend on the stocked item (candidate key); products.stock_quantity is the summed cache.
-- ---------------------------------------------------------------------
CREATE TABLE inventory (
    inventory_id       BIGINT     GENERATED ALWAYS AS IDENTITY,
    product_id         BIGINT     NOT NULL,
    variant_id         BIGINT,
    quantity_on_hand   INTEGER    NOT NULL DEFAULT 0,
    reserved_quantity  INTEGER    NOT NULL DEFAULT 0,
    rack_location      VARCHAR(40),
    last_restocked_at  TIMESTAMP,
    created_at         TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventory PRIMARY KEY (inventory_id),
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_variant FOREIGN KEY (product_id, variant_id) REFERENCES product_variants (product_id, variant_id) ON DELETE RESTRICT,
    CONSTRAINT ck_inventory_on_hand  CHECK (quantity_on_hand >= 0),
    CONSTRAINT ck_inventory_reserved CHECK (reserved_quantity >= 0 AND reserved_quantity <= quantity_on_hand)
);
CREATE UNIQUE INDEX uq_inventory_item ON inventory (product_id, COALESCE(variant_id, 0));

-- inventory -> products.stock_quantity
CREATE OR REPLACE FUNCTION fn_sync_product_stock()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_product_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN v_product_id := OLD.product_id; ELSE v_product_id := NEW.product_id; END IF;
    UPDATE products
       SET stock_quantity = (SELECT COALESCE(SUM(quantity_on_hand), 0) FROM inventory WHERE product_id = v_product_id)
     WHERE product_id = v_product_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_inventory_sync_stock AFTER INSERT OR DELETE OR UPDATE OF quantity_on_hand ON inventory
    FOR EACH ROW EXECUTE FUNCTION fn_sync_product_stock();

-- =====================================================================
-- RT CRACKERS | 05_INVENTORY/002_Inventory_movements.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- inventory_movements | Purpose: append-only stock ledger; a trigger applies each row to inventory.
-- Keys : PK(movement_id)
-- Rel  : N:1 inventory, N:1 admins
-- BCNF : attributes describe one movement.
-- ---------------------------------------------------------------------
CREATE TABLE inventory_movements (
    movement_id      BIGINT         GENERATED ALWAYS AS IDENTITY,
    inventory_id     BIGINT         NOT NULL,
    movement_type    CHAR(1)        NOT NULL,   -- P purchase, S sale, R customer return, A adjustment, D damage/write-off, C cancel restock
    quantity_change  INTEGER        NOT NULL,
    unit_cost        NUMERIC(12,2),
    reference_type   CHAR(1),                   -- O order, R return, P purchase, M manual
    reference_id     BIGINT,
    notes            VARCHAR(255),
    performed_by     INTEGER,
    created_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventory_movements PRIMARY KEY (movement_id),
    CONSTRAINT fk_inventory_movements_inventory FOREIGN KEY (inventory_id)  REFERENCES inventory (inventory_id) ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_movements_admin     FOREIGN KEY (performed_by)  REFERENCES admins (admin_id)         ON DELETE SET NULL,
    CONSTRAINT ck_inventory_movements_type   CHECK (movement_type IN ('P','S','R','A','D','C')),
    CONSTRAINT ck_inventory_movements_qty    CHECK (quantity_change <> 0),
    CONSTRAINT ck_inventory_movements_sign   CHECK ((movement_type IN ('P','R','C') AND quantity_change > 0)
                                                 OR (movement_type IN ('S','D')     AND quantity_change < 0)
                                                 OR  movement_type = 'A'),
    CONSTRAINT ck_inventory_movements_reftype CHECK (reference_type IS NULL OR reference_type IN ('O','R','P','M')),
    CONSTRAINT ck_inventory_movements_refpair CHECK ((reference_type IS NULL) = (reference_id IS NULL)),
    CONSTRAINT ck_inventory_movements_cost    CHECK (unit_cost IS NULL OR unit_cost >= 0)
);

-- inventory_movements -> inventory
CREATE OR REPLACE FUNCTION fn_apply_inventory_movement()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE inventory
       SET quantity_on_hand  = quantity_on_hand + NEW.quantity_change,
           last_restocked_at = CASE WHEN NEW.movement_type = 'P' THEN CURRENT_TIMESTAMP ELSE last_restocked_at END
     WHERE inventory_id = NEW.inventory_id;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_inventory_movements_apply AFTER INSERT ON inventory_movements
    FOR EACH ROW EXECUTE FUNCTION fn_apply_inventory_movement();

-- =====================================================================
-- RT CRACKERS | 14_MARKETING/001_Coupons.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- coupons | Purpose: discount codes (percentage or flat).
-- Keys : PK(coupon_id) | CK/AK: coupon_code
-- Rel  : 1:N carts, orders, coupon_usage, referral_rewards
-- BCNF : rule attributes depend only on the coupon. Usage counts are derived from coupon_usage, not stored.
-- ---------------------------------------------------------------------
CREATE TABLE coupons (
    coupon_id             INTEGER        GENERATED ALWAYS AS IDENTITY,
    coupon_code           VARCHAR(30)    NOT NULL,
    description           VARCHAR(255),
    discount_type         CHAR(1)        NOT NULL,                 -- P percentage, F flat amount
    discount_percentage   NUMERIC(5,2),
    discount_amount       NUMERIC(12,2),
    max_discount_amount   NUMERIC(12,2),
    min_order_amount      NUMERIC(12,2)  NOT NULL DEFAULT 0,
    usage_limit           INTEGER,
    usage_limit_per_user  SMALLINT       NOT NULL DEFAULT 1,
    valid_from            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_until           TIMESTAMP      NOT NULL,
    first_order_only      BOOLEAN        NOT NULL DEFAULT FALSE,
    is_active             BOOLEAN        NOT NULL DEFAULT TRUE,
    created_by            INTEGER,
    created_at            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_coupons PRIMARY KEY (coupon_id),
    CONSTRAINT uq_coupons_coupon_code UNIQUE (coupon_code),
    CONSTRAINT fk_coupons_created_by FOREIGN KEY (created_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_coupons_code_upper    CHECK (coupon_code = UPPER(coupon_code)),
    CONSTRAINT ck_coupons_discount_pct  CHECK (discount_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_coupons_type_shape    CHECK ((discount_type = 'P' AND discount_percentage IS NOT NULL AND discount_amount IS NULL)
                                            OR (discount_type = 'F' AND discount_amount IS NOT NULL AND discount_percentage IS NULL)),
    CONSTRAINT ck_coupons_amounts       CHECK ((discount_amount IS NULL OR discount_amount > 0)
                                           AND (max_discount_amount IS NULL OR max_discount_amount > 0)
                                           AND min_order_amount >= 0),
    CONSTRAINT ck_coupons_limits        CHECK ((usage_limit IS NULL OR usage_limit > 0) AND usage_limit_per_user > 0),
    CONSTRAINT ck_coupons_validity      CHECK (valid_until > valid_from)
);

-- =====================================================================
-- RT CRACKERS | 14_MARKETING/003_Banners.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- banners | Purpose: homepage / promo banners.
-- Keys : PK(banner_id)
-- Rel  : 1:N festival_banners
-- BCNF : attributes depend only on the banner.
-- ---------------------------------------------------------------------
CREATE TABLE banners (
    banner_id         INTEGER       GENERATED ALWAYS AS IDENTITY,
    title             VARCHAR(150)  NOT NULL,
    subtitle          VARCHAR(255),
    image_url         VARCHAR(500)  NOT NULL,
    mobile_image_url  VARCHAR(500),
    link_url          VARCHAR(500),
    position          CHAR(1)       NOT NULL DEFAULT 'H',      -- H hero, S sidebar, F footer, P popup
    display_order     SMALLINT      NOT NULL DEFAULT 0,
    start_at          TIMESTAMP,
    end_at            TIMESTAMP,
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    created_by        INTEGER,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_banners PRIMARY KEY (banner_id),
    CONSTRAINT fk_banners_created_by FOREIGN KEY (created_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_banners_position CHECK (position IN ('H','S','F','P')),
    CONSTRAINT ck_banners_window   CHECK (start_at IS NULL OR end_at IS NULL OR end_at > start_at)
);

-- =====================================================================
-- RT CRACKERS | 14_MARKETING/004_Newsletters.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- newsletters | Purpose: marketing e-mail campaigns.
-- Keys : PK(newsletter_id)
-- Rel  : N:1 admins
-- BCNF : attributes depend only on the campaign.
-- ---------------------------------------------------------------------
CREATE TABLE newsletters (
    newsletter_id  INTEGER       GENERATED ALWAYS AS IDENTITY,
    subject        VARCHAR(200)  NOT NULL,
    body_html      TEXT          NOT NULL,
    status         CHAR(1)       NOT NULL DEFAULT 'D',          -- D draft, S scheduled, T sent, X cancelled
    scheduled_at   TIMESTAMP,
    sent_at        TIMESTAMP,
    created_by     INTEGER,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_newsletters PRIMARY KEY (newsletter_id),
    CONSTRAINT fk_newsletters_created_by FOREIGN KEY (created_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_newsletters_status CHECK (status IN ('D','S','T','X')),
    CONSTRAINT ck_newsletters_sent   CHECK ((status = 'T') = (sent_at IS NOT NULL))
);

-- =====================================================================
-- RT CRACKERS | 14_MARKETING/005_Newsletter_subscribers.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- newsletter_subscribers | Purpose: e-mail subscription list (members and guests).
-- Keys : PK(subscriber_id) | CK/AK: email, unsubscribe_token
-- Rel  : N:1 users (optional)
-- BCNF : attributes depend on the subscriber.
-- ---------------------------------------------------------------------
CREATE TABLE newsletter_subscribers (
    subscriber_id      INTEGER       GENERATED ALWAYS AS IDENTITY,
    email              VARCHAR(255)  NOT NULL,
    user_id            BIGINT,
    is_subscribed      BOOLEAN       NOT NULL DEFAULT TRUE,
    subscribed_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    unsubscribed_at    TIMESTAMP,
    unsubscribe_token  VARCHAR(64)   NOT NULL DEFAULT MD5(RANDOM()::TEXT || CLOCK_TIMESTAMP()::TEXT),
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_newsletter_subscribers PRIMARY KEY (subscriber_id),
    CONSTRAINT uq_newsletter_subscribers_email UNIQUE (email),
    CONSTRAINT uq_newsletter_subscribers_token UNIQUE (unsubscribe_token),
    CONSTRAINT fk_newsletter_subscribers_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE SET NULL,
    CONSTRAINT ck_newsletter_subscribers_email CHECK (email = LOWER(email)),
    CONSTRAINT ck_newsletter_subscribers_state CHECK (is_subscribed OR unsubscribed_at IS NOT NULL)
);

-- =====================================================================
-- RT CRACKERS | 07_CART/001_Carts.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- carts | Purpose: a user's shopping cart; at most one active cart per user.
-- Keys : PK(cart_id)
-- Rel  : N:1 users, N:1 coupons; 1:N cart_items
-- BCNF : attributes depend on the cart. Prices are NOT stored: they come from products at checkout.
-- ---------------------------------------------------------------------
CREATE TABLE carts (
    cart_id     BIGINT     GENERATED ALWAYS AS IDENTITY,
    user_id     BIGINT     NOT NULL,
    coupon_id   INTEGER,
    status      CHAR(1)    NOT NULL DEFAULT 'A',               -- A active, C converted to order, X abandoned
    created_at  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_carts PRIMARY KEY (cart_id),
    CONSTRAINT fk_carts_user   FOREIGN KEY (user_id)   REFERENCES users (user_id)     ON DELETE CASCADE,
    CONSTRAINT fk_carts_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (coupon_id) ON DELETE SET NULL,
    CONSTRAINT ck_carts_status CHECK (status IN ('A','C','X'))
);
CREATE UNIQUE INDEX uq_carts_one_active_per_user ON carts (user_id) WHERE status = 'A';

-- =====================================================================
-- RT CRACKERS | 07_CART/002_Cart_items.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- cart_items | Purpose: lines inside a cart.
-- Keys : PK(cart_item_id) | CK/AK: (cart_id, product_id, variant_id|0) via unique index
-- Rel  : N:1 carts, products, product_variants (composite FK)
-- BCNF : quantity depends on the candidate key (cart, item).
-- ---------------------------------------------------------------------
CREATE TABLE cart_items (
    cart_item_id  BIGINT     GENERATED ALWAYS AS IDENTITY,
    cart_id       BIGINT     NOT NULL,
    product_id    BIGINT     NOT NULL,
    variant_id    BIGINT,
    quantity      INTEGER    NOT NULL DEFAULT 1,
    created_at    TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cart_items PRIMARY KEY (cart_item_id),
    CONSTRAINT fk_cart_items_cart    FOREIGN KEY (cart_id)    REFERENCES carts (cart_id)         ON DELETE CASCADE,
    CONSTRAINT fk_cart_items_product FOREIGN KEY (product_id) REFERENCES products (product_id)   ON DELETE CASCADE,
    CONSTRAINT fk_cart_items_variant FOREIGN KEY (product_id, variant_id) REFERENCES product_variants (product_id, variant_id) ON DELETE CASCADE,
    CONSTRAINT ck_cart_items_quantity CHECK (quantity > 0 AND quantity <= 1000)
);
CREATE UNIQUE INDEX uq_cart_items_line ON cart_items (cart_id, product_id, COALESCE(variant_id, 0));

-- =====================================================================
-- RT CRACKERS | 08_WISHLIST/001_Wishlists.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- wishlists | Purpose: named wish lists per user.
-- Keys : PK(wishlist_id) | CK/AK: (user_id, wishlist_name)
-- Rel  : N:1 users; 1:N wishlist_items
-- BCNF : attributes depend on the wishlist.
-- ---------------------------------------------------------------------
CREATE TABLE wishlists (
    wishlist_id    BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id        BIGINT        NOT NULL,
    wishlist_name  VARCHAR(80)   NOT NULL DEFAULT 'My Wishlist',
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_wishlists PRIMARY KEY (wishlist_id),
    CONSTRAINT uq_wishlists_user_name UNIQUE (user_id, wishlist_name),
    CONSTRAINT fk_wishlists_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);

-- =====================================================================
-- RT CRACKERS | 08_WISHLIST/002_Wishlist_items.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- wishlist_items | Purpose: products saved in a wishlist.
-- Keys : COMPOSITE PK(wishlist_id, product_id)
-- Rel  : N:1 wishlists, N:1 products
-- BCNF : no non-key determinants.
-- ---------------------------------------------------------------------
CREATE TABLE wishlist_items (
    wishlist_id  BIGINT     NOT NULL,
    product_id   BIGINT     NOT NULL,
    created_at   TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_wishlist_items PRIMARY KEY (wishlist_id, product_id),
    CONSTRAINT fk_wishlist_items_wishlist FOREIGN KEY (wishlist_id) REFERENCES wishlists (wishlist_id) ON DELETE CASCADE,
    CONSTRAINT fk_wishlist_items_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)   ON DELETE CASCADE
);

-- =====================================================================
-- RT CRACKERS | 09_COMPARISON/001_Comparisons.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- comparisons | Purpose: a product comparison set started by a user.
-- Keys : PK(comparison_id)
-- Rel  : N:1 users; 1:N comparison_items
-- BCNF : attributes depend on the comparison.
-- ---------------------------------------------------------------------
CREATE TABLE comparisons (
    comparison_id  BIGINT     GENERATED ALWAYS AS IDENTITY,
    user_id        BIGINT     NOT NULL,
    created_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_comparisons PRIMARY KEY (comparison_id),
    CONSTRAINT fk_comparisons_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);

-- =====================================================================
-- RT CRACKERS | 09_COMPARISON/002_Comparison_items.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- comparison_items | Purpose: products inside a comparison (max 4 slots).
-- Keys : COMPOSITE PK(comparison_id, product_id) | AK: (comparison_id, slot_no)
-- Rel  : N:1 comparisons, N:1 products
-- BCNF : slot_no determined by the key and is itself unique per comparison (candidate key).
-- ---------------------------------------------------------------------
CREATE TABLE comparison_items (
    comparison_id  BIGINT     NOT NULL,
    product_id     BIGINT     NOT NULL,
    slot_no        SMALLINT   NOT NULL,
    created_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_comparison_items PRIMARY KEY (comparison_id, product_id),
    CONSTRAINT uq_comparison_items_slot UNIQUE (comparison_id, slot_no),
    CONSTRAINT fk_comparison_items_comparison FOREIGN KEY (comparison_id) REFERENCES comparisons (comparison_id) ON DELETE CASCADE,
    CONSTRAINT fk_comparison_items_product    FOREIGN KEY (product_id)    REFERENCES products (product_id)       ON DELETE CASCADE,
    CONSTRAINT ck_comparison_items_slot CHECK (slot_no BETWEEN 1 AND 4)
);

-- =====================================================================
-- RT CRACKERS | 06_CUSTOMERS/002_Saved_addresses.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- saved_addresses | Purpose: the user's address book entries (nickname + usage) pointing at addresses.
-- Keys : PK(saved_address_id) | CK/AK: address_id
-- Rel  : N:1 users, 1:1 addresses
-- BCNF : nickname/use_count depend on the saved entry; each address is saved at most once.
-- ---------------------------------------------------------------------
CREATE TABLE saved_addresses (
    saved_address_id  BIGINT       GENERATED ALWAYS AS IDENTITY,
    user_id           BIGINT       NOT NULL,
    address_id        BIGINT       NOT NULL,
    nickname          VARCHAR(50)  NOT NULL,
    use_count         INTEGER      NOT NULL DEFAULT 0,
    last_used_at      TIMESTAMP,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_saved_addresses PRIMARY KEY (saved_address_id),
    CONSTRAINT uq_saved_addresses_address  UNIQUE (address_id),
    CONSTRAINT uq_saved_addresses_nickname UNIQUE (user_id, nickname),
    CONSTRAINT fk_saved_addresses_user    FOREIGN KEY (user_id)    REFERENCES users (user_id)         ON DELETE CASCADE,
    CONSTRAINT fk_saved_addresses_address FOREIGN KEY (address_id) REFERENCES addresses (address_id)  ON DELETE CASCADE,
    CONSTRAINT ck_saved_addresses_use_count CHECK (use_count >= 0)
);

-- =====================================================================
-- RT CRACKERS | 06_CUSTOMERS/004_Recently_viewed_products.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- recently_viewed_products | Purpose: per-user browsing shortcuts.
-- Keys : COMPOSITE PK(user_id, product_id)
-- Rel  : N:1 users, N:1 products
-- BCNF : last_viewed_at/view_count depend on the whole key.
-- ---------------------------------------------------------------------
CREATE TABLE recently_viewed_products (
    user_id         BIGINT     NOT NULL,
    product_id      BIGINT     NOT NULL,
    view_count      INTEGER    NOT NULL DEFAULT 1,
    last_viewed_at  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_recently_viewed_products PRIMARY KEY (user_id, product_id),
    CONSTRAINT fk_recently_viewed_user    FOREIGN KEY (user_id)    REFERENCES users (user_id)       ON DELETE CASCADE,
    CONSTRAINT fk_recently_viewed_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT ck_recently_viewed_count CHECK (view_count > 0)
);

-- =====================================================================
-- RT CRACKERS | 11_PAYMENTS/001_Payment_methods.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- payment_methods | Purpose: allowed payment modes. Only Cash On Delivery is permitted (CHECK).
-- Keys : PK(payment_method_id) | CK/AK: method_code
-- Rel  : 1:N orders
-- BCNF : attributes depend only on the method.
-- ---------------------------------------------------------------------
CREATE TABLE payment_methods (
    payment_method_id  SMALLINT       GENERATED ALWAYS AS IDENTITY,
    method_code        CHAR(3)        NOT NULL,
    method_name        VARCHAR(60)    NOT NULL,
    description        VARCHAR(255),
    min_order_amount   NUMERIC(12,2)  NOT NULL DEFAULT 0,
    max_order_amount   NUMERIC(12,2),
    is_active          BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_payment_methods PRIMARY KEY (payment_method_id),
    CONSTRAINT uq_payment_methods_code UNIQUE (method_code),
    CONSTRAINT ck_payment_methods_cod_only CHECK (method_code = 'COD'),
    CONSTRAINT ck_payment_methods_limits   CHECK (min_order_amount >= 0 AND (max_order_amount IS NULL OR max_order_amount >= min_order_amount))
);

-- =====================================================================
-- RT CRACKERS | 10_ORDERS/001_Orders.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- orders | Purpose: order header. total_amount is GENERATED from its components.
-- Keys : PK(order_id) | CK/AK: order_number, tracking_number, (order_id,user_id,coupon_id)
-- Rel  : N:1 users, addresses (billing, shipping), coupons, payment_methods, shipping_methods;
--        1:N order_items, order_status_history, shipments; 1:1 invoices, cod_transactions
-- BCNF : total_amount is generated (no separate dependency); addresses are referenced, never copied.
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id                BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_number            VARCHAR(20)    NOT NULL DEFAULT ('RTC' || TO_CHAR(CURRENT_DATE, 'YYMMDD') || LPAD(NEXTVAL('seq_order_number')::TEXT, 6, '0')),
    user_id                 BIGINT         NOT NULL,
    billing_address_id      BIGINT         NOT NULL,
    shipping_address_id     BIGINT         NOT NULL,
    coupon_id               INTEGER,
    payment_method_id       SMALLINT       NOT NULL,
    shipping_method_id      SMALLINT       NOT NULL,
    subtotal                NUMERIC(12,2)  NOT NULL DEFAULT 0,
    discount_amount         NUMERIC(12,2)  NOT NULL DEFAULT 0,
    tax_amount              NUMERIC(12,2)  NOT NULL DEFAULT 0,
    shipping_amount         NUMERIC(12,2)  NOT NULL DEFAULT 0,
    total_amount            NUMERIC(12,2)  GENERATED ALWAYS AS (subtotal - discount_amount + tax_amount + shipping_amount) STORED,
    payment_status          CHAR(1)        NOT NULL DEFAULT 'P',   -- P pending, C collected, F failed, R refunded, Q partially refunded
    order_status            CHAR(1)        NOT NULL DEFAULT 'P',   -- P placed, C confirmed, K packed, S shipped, O out for delivery, D delivered, X cancelled, R returned
    tracking_number         VARCHAR(40),
    expected_delivery_date  DATE,
    delivery_date           DATE,
    cancellation_reason     VARCHAR(255),
    notes                   TEXT,
    created_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT uq_orders_order_number    UNIQUE (order_number),
    CONSTRAINT uq_orders_tracking_number UNIQUE (tracking_number),
    CONSTRAINT uq_orders_order_user_coupon UNIQUE (order_id, user_id, coupon_id),
    CONSTRAINT fk_orders_user             FOREIGN KEY (user_id)             REFERENCES users (user_id)                       ON DELETE RESTRICT,
    CONSTRAINT fk_orders_billing_address  FOREIGN KEY (billing_address_id)  REFERENCES addresses (address_id)                 ON DELETE RESTRICT,
    CONSTRAINT fk_orders_shipping_address FOREIGN KEY (shipping_address_id) REFERENCES addresses (address_id)                 ON DELETE RESTRICT,
    CONSTRAINT fk_orders_coupon           FOREIGN KEY (coupon_id)           REFERENCES coupons (coupon_id)                   ON DELETE SET NULL,
    CONSTRAINT fk_orders_payment_method   FOREIGN KEY (payment_method_id)   REFERENCES payment_methods (payment_method_id)   ON DELETE RESTRICT,
    CONSTRAINT fk_orders_shipping_method  FOREIGN KEY (shipping_method_id)  REFERENCES shipping_methods (shipping_method_id) ON DELETE RESTRICT,
    CONSTRAINT ck_orders_amounts          CHECK (subtotal >= 0 AND discount_amount >= 0 AND tax_amount >= 0 AND shipping_amount >= 0),
    CONSTRAINT ck_orders_discount_le_sub  CHECK (discount_amount <= subtotal),
    CONSTRAINT ck_orders_total_amount     CHECK (total_amount >= 0),
    CONSTRAINT ck_orders_payment_status   CHECK (payment_status IN ('P','C','F','R','Q')),
    CONSTRAINT ck_orders_order_status     CHECK (order_status IN ('P','C','K','S','O','D','X','R')),
    CONSTRAINT ck_orders_cancel_reason    CHECK (order_status <> 'X' OR cancellation_reason IS NOT NULL),
    CONSTRAINT ck_orders_delivered_date   CHECK (order_status <> 'D' OR delivery_date IS NOT NULL)
);

-- orders -> order_status_history (set app.current_admin_id per session to record who changed it)
CREATE OR REPLACE FUNCTION fn_log_order_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO order_status_history (order_id, old_status, new_status)
        VALUES (NEW.order_id, NULL, NEW.order_status);
    ELSIF NEW.order_status IS DISTINCT FROM OLD.order_status THEN
        INSERT INTO order_status_history (order_id, old_status, new_status, changed_by)
        VALUES (NEW.order_id, OLD.order_status, NEW.order_status,
                NULLIF(current_setting('app.current_admin_id', TRUE), '')::INTEGER);
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_orders_log_status AFTER INSERT OR UPDATE OF order_status ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_log_order_status();

-- orders delivered -> products.sales_count
CREATE OR REPLACE FUNCTION fn_update_sales_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE products p
       SET sales_count = p.sales_count + s.qty
      FROM (SELECT product_id, SUM(quantity)::INTEGER AS qty
              FROM order_items WHERE order_id = NEW.order_id GROUP BY product_id) s
     WHERE p.product_id = s.product_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_orders_sales_count AFTER UPDATE OF order_status ON orders
    FOR EACH ROW WHEN (NEW.order_status = 'D' AND OLD.order_status <> 'D')
    EXECUTE FUNCTION fn_update_sales_count();

-- =====================================================================
-- RT CRACKERS | 10_ORDERS/002_Order_items.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- order_items | Purpose: order lines with price snapshots at purchase time (history, not current price).
-- Keys : PK(order_item_id) | CK/AK: (order_id, product_id, variant_id|0) via unique index
-- Rel  : N:1 orders, products, product_variants (composite FK); 1:N return_requests, replacement_requests; 1:1 reviews
-- BCNF : snapshots are facts about this line at order time; line_total is GENERATED.
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id          BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id               BIGINT         NOT NULL,
    product_id             BIGINT         NOT NULL,
    variant_id             BIGINT,
    sku_snapshot           VARCHAR(40)    NOT NULL,
    product_name_snapshot  VARCHAR(200)   NOT NULL,
    quantity               INTEGER        NOT NULL,
    mrp                    NUMERIC(12,2)  NOT NULL,
    unit_price             NUMERIC(12,2)  NOT NULL,
    gst_percentage         NUMERIC(5,2)   NOT NULL,
    discount_amount        NUMERIC(12,2)  NOT NULL DEFAULT 0,
    tax_amount             NUMERIC(12,2)  NOT NULL DEFAULT 0,
    line_total             NUMERIC(12,2)  GENERATED ALWAYS AS (unit_price * quantity - discount_amount + tax_amount) STORED,
    created_at             TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_order_items PRIMARY KEY (order_item_id),
    CONSTRAINT fk_order_items_order   FOREIGN KEY (order_id)   REFERENCES orders (order_id)     ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT,
    CONSTRAINT fk_order_items_variant FOREIGN KEY (product_id, variant_id) REFERENCES product_variants (product_id, variant_id) ON DELETE RESTRICT,
    CONSTRAINT ck_order_items_quantity  CHECK (quantity > 0),
    CONSTRAINT ck_order_items_prices    CHECK (mrp > 0 AND unit_price > 0 AND unit_price <= mrp),
    CONSTRAINT ck_order_items_gst       CHECK (gst_percentage BETWEEN 0 AND 40),
    CONSTRAINT ck_order_items_amounts   CHECK (discount_amount >= 0 AND tax_amount >= 0 AND discount_amount <= unit_price * quantity)
);
CREATE UNIQUE INDEX uq_order_items_line ON order_items (order_id, product_id, COALESCE(variant_id, 0));

-- =====================================================================
-- RT CRACKERS | 10_ORDERS/003_Order_status_history.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- order_status_history | Purpose: append-only status timeline (written by trigger on orders).
-- Keys : PK(history_id)
-- Rel  : N:1 orders, N:1 admins
-- BCNF : attributes describe one transition.
-- ---------------------------------------------------------------------
CREATE TABLE order_status_history (
    history_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    order_id    BIGINT        NOT NULL,
    old_status  CHAR(1),
    new_status  CHAR(1)       NOT NULL,
    changed_by  INTEGER,
    remarks     VARCHAR(255),
    created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_order_status_history PRIMARY KEY (history_id),
    CONSTRAINT fk_order_status_history_order FOREIGN KEY (order_id)   REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_status_history_admin FOREIGN KEY (changed_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_order_status_history_old CHECK (old_status IS NULL OR old_status IN ('P','C','K','S','O','D','X','R')),
    CONSTRAINT ck_order_status_history_new CHECK (new_status IN ('P','C','K','S','O','D','X','R'))
);

-- =====================================================================
-- RT CRACKERS | 10_ORDERS/006_Invoices.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- invoices | Purpose: GST invoice for an order (one per order).
-- Keys : PK(invoice_id) | CK/AK: invoice_number, order_id
-- Rel  : 1:1 orders, N:1 admins
-- BCNF : amounts are read from the order, not copied.
-- ---------------------------------------------------------------------
CREATE TABLE invoices (
    invoice_id         BIGINT        GENERATED ALWAYS AS IDENTITY,
    invoice_number     VARCHAR(25)   NOT NULL DEFAULT ('INV' || TO_CHAR(CURRENT_DATE, 'YYMM') || LPAD(NEXTVAL('seq_invoice_number')::TEXT, 6, '0')),
    order_id           BIGINT        NOT NULL,
    invoice_date       DATE          NOT NULL DEFAULT CURRENT_DATE,
    customer_gstin     CHAR(15),
    invoice_pdf_url    VARCHAR(500),
    status             CHAR(1)       NOT NULL DEFAULT 'G',       -- G generated, C cancelled
    cancelled_at       TIMESTAMP,
    issued_by          INTEGER,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_invoices PRIMARY KEY (invoice_id),
    CONSTRAINT uq_invoices_invoice_number UNIQUE (invoice_number),
    CONSTRAINT uq_invoices_order_id       UNIQUE (order_id),
    CONSTRAINT fk_invoices_order     FOREIGN KEY (order_id)  REFERENCES orders (order_id) ON DELETE RESTRICT,
    CONSTRAINT fk_invoices_issued_by FOREIGN KEY (issued_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_invoices_status    CHECK (status IN ('G','C')),
    CONSTRAINT ck_invoices_cancelled CHECK ((status = 'C') = (cancelled_at IS NOT NULL)),
    CONSTRAINT ck_invoices_gstin     CHECK (customer_gstin IS NULL OR customer_gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
);

-- =====================================================================
-- RT CRACKERS | 10_ORDERS/007_Return_requests.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- return_requests | Purpose: customer return requests (damaged, wrong item...). Customer = order's user.
-- Keys : PK(return_request_id) | CK/AK: return_number
-- Rel  : N:1 order_items, N:1 admins; 1:N refunds
-- BCNF : attributes depend on the request.
-- ---------------------------------------------------------------------
CREATE TABLE return_requests (
    return_request_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    return_number      VARCHAR(25)   NOT NULL DEFAULT ('RET' || TO_CHAR(CURRENT_DATE, 'YYMM') || LPAD(NEXTVAL('seq_return_number')::TEXT, 6, '0')),
    order_item_id      BIGINT        NOT NULL,
    quantity           INTEGER       NOT NULL,
    reason_code        CHAR(1)       NOT NULL,                -- D damaged, W wrong item, Q quality, M missing, O other
    reason_text        VARCHAR(500),
    evidence_url       VARCHAR(500),
    status             CHAR(1)       NOT NULL DEFAULT 'R',    -- R requested, A approved, J rejected, P picked up, C completed
    resolved_by        INTEGER,
    resolved_at        TIMESTAMP,
    admin_remarks      VARCHAR(500),
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_return_requests PRIMARY KEY (return_request_id),
    CONSTRAINT uq_return_requests_number UNIQUE (return_number),
    CONSTRAINT fk_return_requests_order_item FOREIGN KEY (order_item_id) REFERENCES order_items (order_item_id) ON DELETE RESTRICT,
    CONSTRAINT fk_return_requests_resolved_by FOREIGN KEY (resolved_by)  REFERENCES admins (admin_id)           ON DELETE SET NULL,
    CONSTRAINT ck_return_requests_quantity CHECK (quantity > 0),
    CONSTRAINT ck_return_requests_reason   CHECK (reason_code IN ('D','W','Q','M','O')),
    CONSTRAINT ck_return_requests_status   CHECK (status IN ('R','A','J','P','C')),
    CONSTRAINT ck_return_requests_resolved CHECK ((status = 'R') = (resolved_at IS NULL))
);

-- =====================================================================
-- RT CRACKERS | 10_ORDERS/008_Replacement_requests.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- replacement_requests | Purpose: request to replace a faulty/wrong item; may spawn a zero-value replacement order.
-- Keys : PK(replacement_request_id) | CK/AK: replacement_number, replacement_order_id
-- Rel  : N:1 order_items, N:1 return_requests (optional), N:1 orders (replacement order), N:1 admins
-- BCNF : attributes depend on the request.
-- ---------------------------------------------------------------------
CREATE TABLE replacement_requests (
    replacement_request_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    replacement_number      VARCHAR(25)   NOT NULL DEFAULT ('REP' || TO_CHAR(CURRENT_DATE, 'YYMM') || LPAD(NEXTVAL('seq_replacement_number')::TEXT, 6, '0')),
    order_item_id           BIGINT        NOT NULL,
    return_request_id       BIGINT,
    replacement_order_id    BIGINT,
    quantity                INTEGER       NOT NULL,
    reason_code             CHAR(1)       NOT NULL,           -- D damaged, W wrong item, Q quality, M missing, O other
    reason_text             VARCHAR(500),
    status                  CHAR(1)       NOT NULL DEFAULT 'R', -- R requested, A approved, J rejected, S shipped, C completed
    resolved_by             INTEGER,
    resolved_at             TIMESTAMP,
    admin_remarks           VARCHAR(500),
    created_at              TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_replacement_requests PRIMARY KEY (replacement_request_id),
    CONSTRAINT uq_replacement_requests_number   UNIQUE (replacement_number),
    CONSTRAINT uq_replacement_requests_order    UNIQUE (replacement_order_id),
    CONSTRAINT fk_replacement_requests_item     FOREIGN KEY (order_item_id)        REFERENCES order_items (order_item_id)         ON DELETE RESTRICT,
    CONSTRAINT fk_replacement_requests_return   FOREIGN KEY (return_request_id)    REFERENCES return_requests (return_request_id) ON DELETE SET NULL,
    CONSTRAINT fk_replacement_requests_order    FOREIGN KEY (replacement_order_id) REFERENCES orders (order_id)                   ON DELETE SET NULL,
    CONSTRAINT fk_replacement_requests_resolver FOREIGN KEY (resolved_by)          REFERENCES admins (admin_id)                   ON DELETE SET NULL,
    CONSTRAINT ck_replacement_requests_quantity CHECK (quantity > 0),
    CONSTRAINT ck_replacement_requests_reason   CHECK (reason_code IN ('D','W','Q','M','O')),
    CONSTRAINT ck_replacement_requests_status   CHECK (status IN ('R','A','J','S','C')),
    CONSTRAINT ck_replacement_requests_resolved CHECK ((status = 'R') = (resolved_at IS NULL))
);

-- =====================================================================
-- RT CRACKERS | 11_PAYMENTS/002_Cod_transactions.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- cod_transactions | Purpose: cash collected at the doorstep for an order (one per order).
-- Keys : PK(cod_transaction_id) | CK/AK: order_id, receipt_number
-- Rel  : 1:1 orders, N:1 admins (delivery agent); 1:1 cash_collection_logs
-- BCNF : amount due is read from orders.total_amount (not copied); only the collected amount is recorded.
-- ---------------------------------------------------------------------
CREATE TABLE cod_transactions (
    cod_transaction_id  BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id            BIGINT         NOT NULL,
    receipt_number      VARCHAR(25)    NOT NULL DEFAULT ('COD' || TO_CHAR(CURRENT_DATE, 'YYMM') || LPAD(NEXTVAL('seq_cod_receipt')::TEXT, 6, '0')),
    amount_collected    NUMERIC(12,2)  NOT NULL DEFAULT 0,
    status              CHAR(1)        NOT NULL DEFAULT 'P',     -- P pending, C collected, F failed/refused, X cancelled
    collected_by        INTEGER,
    collected_at        TIMESTAMP,
    failure_reason      VARCHAR(255),
    created_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cod_transactions PRIMARY KEY (cod_transaction_id),
    CONSTRAINT uq_cod_transactions_order   UNIQUE (order_id),
    CONSTRAINT uq_cod_transactions_receipt UNIQUE (receipt_number),
    CONSTRAINT fk_cod_transactions_order    FOREIGN KEY (order_id)     REFERENCES orders (order_id) ON DELETE RESTRICT,
    CONSTRAINT fk_cod_transactions_agent    FOREIGN KEY (collected_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_cod_transactions_status   CHECK (status IN ('P','C','F','X')),
    CONSTRAINT ck_cod_transactions_amount   CHECK (amount_collected >= 0),
    CONSTRAINT ck_cod_transactions_collected CHECK ((status = 'C' AND amount_collected > 0 AND collected_by IS NOT NULL AND collected_at IS NOT NULL)
                                                 OR (status <> 'C' AND amount_collected = 0))
);

-- cod_transactions: collected amount must equal the order total; marks the order as paid
CREATE OR REPLACE FUNCTION fn_cod_collected()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_total NUMERIC(12,2);
BEGIN
    IF NEW.status = 'C' THEN
        SELECT total_amount INTO v_total FROM orders WHERE order_id = NEW.order_id;
        IF NEW.amount_collected <> v_total THEN
            RAISE EXCEPTION 'COD amount collected (%) does not match order total (%)', NEW.amount_collected, v_total;
        END IF;
        UPDATE orders SET payment_status = 'C' WHERE order_id = NEW.order_id;
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_cod_transactions_collected AFTER INSERT OR UPDATE OF status, amount_collected ON cod_transactions
    FOR EACH ROW EXECUTE FUNCTION fn_cod_collected();

-- =====================================================================
-- RT CRACKERS | 11_PAYMENTS/004_Refunds.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- refunds | Purpose: money returned to customers (bank transfer or cash) for cancelled/returned COD orders.
-- Keys : PK(refund_id) | CK/AK: refund_number
-- Rel  : N:1 orders, N:1 return_requests, N:1 admins
-- BCNF : attributes depend on the refund. Only the last 4 digits of the account are stored.
-- ---------------------------------------------------------------------
CREATE TABLE refunds (
    refund_id               BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id                BIGINT         NOT NULL,
    return_request_id       BIGINT,
    refund_amount           NUMERIC(12,2)  NOT NULL,
    refund_method           CHAR(1)        NOT NULL,             -- B bank transfer, C cash
    account_holder_name     VARCHAR(120),
    bank_name               VARCHAR(100),
    account_last4           CHAR(4),
    ifsc_code               CHAR(11),
    transaction_reference   VARCHAR(60),
    reason                  VARCHAR(255),
    status                  CHAR(1)        NOT NULL DEFAULT 'P', -- P pending, A approved, C completed, R rejected
    processed_by            INTEGER,
    processed_at            TIMESTAMP,
    created_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_refunds PRIMARY KEY (refund_id),
    CONSTRAINT fk_refunds_order   FOREIGN KEY (order_id)          REFERENCES orders (order_id)                   ON DELETE RESTRICT,
    CONSTRAINT fk_refunds_return  FOREIGN KEY (return_request_id) REFERENCES return_requests (return_request_id) ON DELETE SET NULL,
    CONSTRAINT fk_refunds_admin   FOREIGN KEY (processed_by)      REFERENCES admins (admin_id)                   ON DELETE SET NULL,
    CONSTRAINT ck_refunds_amount  CHECK (refund_amount > 0),
    CONSTRAINT ck_refunds_method  CHECK (refund_method IN ('B','C')),
    CONSTRAINT ck_refunds_status  CHECK (status IN ('P','A','C','R')),
    CONSTRAINT ck_refunds_bank    CHECK (refund_method = 'C' OR (account_holder_name IS NOT NULL AND ifsc_code IS NOT NULL AND account_last4 IS NOT NULL)),
    CONSTRAINT ck_refunds_last4   CHECK (account_last4 IS NULL OR account_last4 ~ '^[0-9]{4}$'),
    CONSTRAINT ck_refunds_ifsc    CHECK (ifsc_code IS NULL OR ifsc_code ~ '^[A-Z]{4}0[A-Z0-9]{6}$'),
    CONSTRAINT ck_refunds_completed CHECK ((status IN ('C','R')) = (processed_at IS NOT NULL))
);

-- =====================================================================
-- RT CRACKERS | 11_PAYMENTS/003_Cash_collection_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- cash_collection_logs | Purpose: hand-over of collected cash from delivery agent to store cashier, per COD transaction.
-- Keys : PK(log_id) | CK/AK: cod_transaction_id
-- Rel  : 1:1 cod_transactions, N:1 admins (agent), N:1 admins (receiver)
-- BCNF : attributes depend on the hand-over record.
-- ---------------------------------------------------------------------
CREATE TABLE cash_collection_logs (
    log_id               BIGINT         GENERATED ALWAYS AS IDENTITY,
    cod_transaction_id   BIGINT         NOT NULL,
    handed_over_by       INTEGER        NOT NULL,
    received_by          INTEGER,
    handed_over_amount   NUMERIC(12,2)  NOT NULL,
    handed_over_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status               CHAR(1)        NOT NULL DEFAULT 'P',    -- P pending verification, V verified, D discrepancy
    remarks              VARCHAR(500),
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_cash_collection_logs PRIMARY KEY (log_id),
    CONSTRAINT uq_cash_collection_logs_cod UNIQUE (cod_transaction_id),
    CONSTRAINT fk_cash_collection_logs_cod      FOREIGN KEY (cod_transaction_id) REFERENCES cod_transactions (cod_transaction_id) ON DELETE RESTRICT,
    CONSTRAINT fk_cash_collection_logs_agent    FOREIGN KEY (handed_over_by)     REFERENCES admins (admin_id)                     ON DELETE RESTRICT,
    CONSTRAINT fk_cash_collection_logs_receiver FOREIGN KEY (received_by)        REFERENCES admins (admin_id)                     ON DELETE SET NULL,
    CONSTRAINT ck_cash_collection_logs_amount   CHECK (handed_over_amount > 0),
    CONSTRAINT ck_cash_collection_logs_status   CHECK (status IN ('P','V','D'))
);

-- =====================================================================
-- RT CRACKERS | 12_SHIPPING/004_Shipments.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- shipments | Purpose: physical dispatch records for an order (an order may ship in several packages).
-- Keys : PK(shipment_id) | CK/AK: carrier_awb_number
-- Rel  : N:1 orders, N:1 admins (delivery agent)
-- BCNF : expected/actual delivery dates live on orders only, so they are not duplicated here.
-- ---------------------------------------------------------------------
CREATE TABLE shipments (
    shipment_id          BIGINT       GENERATED ALWAYS AS IDENTITY,
    order_id             BIGINT       NOT NULL,
    carrier_awb_number   VARCHAR(40),
    delivery_partner     VARCHAR(80),
    delivery_agent_id    INTEGER,
    package_count        SMALLINT     NOT NULL DEFAULT 1,
    package_weight_kg    REAL,
    packed_at            TIMESTAMP,
    shipped_at           TIMESTAMP,
    notes                VARCHAR(500),
    created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_shipments PRIMARY KEY (shipment_id),
    CONSTRAINT uq_shipments_awb UNIQUE (carrier_awb_number),
    CONSTRAINT fk_shipments_order FOREIGN KEY (order_id)          REFERENCES orders (order_id) ON DELETE RESTRICT,
    CONSTRAINT fk_shipments_agent FOREIGN KEY (delivery_agent_id) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_shipments_package_count  CHECK (package_count > 0),
    CONSTRAINT ck_shipments_package_weight CHECK (package_weight_kg IS NULL OR package_weight_kg > 0),
    CONSTRAINT ck_shipments_dispatch_order CHECK (packed_at IS NULL OR shipped_at IS NULL OR shipped_at >= packed_at)
);

-- =====================================================================
-- RT CRACKERS | 13_REVIEWS/001_Reviews.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- reviews | Purpose: customer product reviews; verified_purchase is GENERATED from order_item_id.
-- Keys : PK(review_id) | CK/AK: (product_id, user_id), order_item_id
-- Rel  : N:1 products, users, order_items; 1:N review_images, review_reports
-- BCNF : verified_purchase is generated; reported_count is trigger-maintained from review_reports.
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    review_id          BIGINT        GENERATED ALWAYS AS IDENTITY,
    product_id         BIGINT        NOT NULL,
    user_id            BIGINT        NOT NULL,
    order_item_id      BIGINT,
    rating             SMALLINT      NOT NULL,
    title              VARCHAR(150),
    review_text        TEXT,
    verified_purchase  BOOLEAN       GENERATED ALWAYS AS (order_item_id IS NOT NULL) STORED,
    helpful_count      INTEGER       NOT NULL DEFAULT 0,
    reported_count     INTEGER       NOT NULL DEFAULT 0,
    status             CHAR(1)       NOT NULL DEFAULT 'P',      -- P pending, A approved, R rejected, H hidden
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_reviews PRIMARY KEY (review_id),
    CONSTRAINT uq_reviews_product_user UNIQUE (product_id, user_id),
    CONSTRAINT uq_reviews_order_item   UNIQUE (order_item_id),
    CONSTRAINT fk_reviews_product    FOREIGN KEY (product_id)    REFERENCES products (product_id)       ON DELETE CASCADE,
    CONSTRAINT fk_reviews_user       FOREIGN KEY (user_id)       REFERENCES users (user_id)             ON DELETE CASCADE,
    CONSTRAINT fk_reviews_order_item FOREIGN KEY (order_item_id) REFERENCES order_items (order_item_id) ON DELETE SET NULL,
    CONSTRAINT ck_reviews_rating   CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT ck_reviews_counts   CHECK (helpful_count >= 0 AND reported_count >= 0),
    CONSTRAINT ck_reviews_status   CHECK (status IN ('P','A','R','H'))
);

-- reviews -> products.rating_average / rating_count (approved reviews only)
CREATE OR REPLACE FUNCTION fn_sync_product_rating()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_product_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN v_product_id := OLD.product_id; ELSE v_product_id := NEW.product_id; END IF;
    UPDATE products p
       SET rating_count   = s.cnt,
           rating_average = s.avg_rating
      FROM (SELECT COUNT(*)::INTEGER AS cnt,
                   COALESCE(ROUND(AVG(rating), 2), 0) AS avg_rating
              FROM reviews WHERE product_id = v_product_id AND status = 'A') s
     WHERE p.product_id = v_product_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_reviews_sync_rating AFTER INSERT OR DELETE OR UPDATE OF rating, status ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_sync_product_rating();

-- =====================================================================
-- RT CRACKERS | 13_REVIEWS/002_Review_images.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- review_images | Purpose: photos attached to a review.
-- Keys : PK(review_image_id) | CK/AK: (review_id, image_url)
-- Rel  : N:1 reviews
-- BCNF : attributes depend on the image row.
-- ---------------------------------------------------------------------
CREATE TABLE review_images (
    review_image_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    review_id        BIGINT        NOT NULL,
    image_url        VARCHAR(500)  NOT NULL,
    display_order    SMALLINT      NOT NULL DEFAULT 0,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_review_images PRIMARY KEY (review_image_id),
    CONSTRAINT uq_review_images_review_url UNIQUE (review_id, image_url),
    CONSTRAINT fk_review_images_review FOREIGN KEY (review_id) REFERENCES reviews (review_id) ON DELETE CASCADE
);

-- =====================================================================
-- RT CRACKERS | 13_REVIEWS/003_Review_reports.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- review_reports | Purpose: abuse reports raised on reviews.
-- Keys : PK(report_id) | CK/AK: (review_id, reported_by)
-- Rel  : N:1 reviews, users, admins
-- BCNF : attributes depend on the report.
-- ---------------------------------------------------------------------
CREATE TABLE review_reports (
    report_id    BIGINT        GENERATED ALWAYS AS IDENTITY,
    review_id    BIGINT        NOT NULL,
    reported_by  BIGINT        NOT NULL,
    reason_code  CHAR(1)       NOT NULL,                       -- S spam, A abusive, F fake, I irrelevant, O other
    description  VARCHAR(500),
    status       CHAR(1)       NOT NULL DEFAULT 'P',           -- P pending, R actioned, D dismissed
    reviewed_by  INTEGER,
    reviewed_at  TIMESTAMP,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_review_reports PRIMARY KEY (report_id),
    CONSTRAINT uq_review_reports_review_user UNIQUE (review_id, reported_by),
    CONSTRAINT fk_review_reports_review   FOREIGN KEY (review_id)   REFERENCES reviews (review_id) ON DELETE CASCADE,
    CONSTRAINT fk_review_reports_user     FOREIGN KEY (reported_by) REFERENCES users (user_id)     ON DELETE CASCADE,
    CONSTRAINT fk_review_reports_reviewer FOREIGN KEY (reviewed_by) REFERENCES admins (admin_id)   ON DELETE SET NULL,
    CONSTRAINT ck_review_reports_reason   CHECK (reason_code IN ('S','A','F','I','O')),
    CONSTRAINT ck_review_reports_status   CHECK (status IN ('P','R','D')),
    CONSTRAINT ck_review_reports_reviewed CHECK ((status = 'P') = (reviewed_at IS NULL))
);

-- review_reports -> reviews.reported_count
CREATE OR REPLACE FUNCTION fn_sync_review_reported_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_review_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN v_review_id := OLD.review_id; ELSE v_review_id := NEW.review_id; END IF;
    UPDATE reviews
       SET reported_count = (SELECT COUNT(*) FROM review_reports WHERE review_id = v_review_id)
     WHERE review_id = v_review_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_review_reports_sync_count AFTER INSERT OR DELETE ON review_reports
    FOR EACH ROW EXECUTE FUNCTION fn_sync_review_reported_count();

-- =====================================================================
-- RT CRACKERS | 14_MARKETING/002_Coupon_usage.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- coupon_usage | Purpose: one row per order that redeemed a coupon.
-- Keys : PK(coupon_usage_id) | CK/AK: order_id
-- Rel  : composite FK (order_id, user_id, coupon_id) -> orders keeps user and coupon consistent with the order
-- BCNF : order_id is a candidate key, so order_id -> user_id, coupon_id is a key dependency.
-- ---------------------------------------------------------------------
CREATE TABLE coupon_usage (
    coupon_usage_id  BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id         BIGINT         NOT NULL,
    user_id          BIGINT         NOT NULL,
    coupon_id        INTEGER        NOT NULL,
    discount_applied NUMERIC(12,2)  NOT NULL,
    status           CHAR(1)        NOT NULL DEFAULT 'A',      -- A applied, R reversed (order cancelled)
    created_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_coupon_usage PRIMARY KEY (coupon_usage_id),
    CONSTRAINT uq_coupon_usage_order UNIQUE (order_id),
    CONSTRAINT fk_coupon_usage_order  FOREIGN KEY (order_id, user_id, coupon_id) REFERENCES orders (order_id, user_id, coupon_id) ON DELETE CASCADE,
    CONSTRAINT fk_coupon_usage_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (coupon_id) ON DELETE RESTRICT,
    CONSTRAINT ck_coupon_usage_discount CHECK (discount_applied >= 0),
    CONSTRAINT ck_coupon_usage_status   CHECK (status IN ('A','R'))
);

-- =====================================================================
-- RT CRACKERS | 14_MARKETING/006_Referral_rewards.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- referral_rewards | Purpose: rewards for both sides of a referral. The referrer is users.referred_by of the referred user.
-- Keys : PK(referral_reward_id) | CK/AK: (referred_user_id, beneficiary_role)
-- Rel  : N:1 users (referred), N:1 orders (qualifying order), N:1 coupons (reward coupon)
-- BCNF : beneficiary is derived from role + referred user, so no duplicate referrer column is stored.
-- ---------------------------------------------------------------------
CREATE TABLE referral_rewards (
    referral_reward_id   BIGINT         GENERATED ALWAYS AS IDENTITY,
    referred_user_id     BIGINT         NOT NULL,
    beneficiary_role     CHAR(1)        NOT NULL,              -- R referrer, E referee (the referred user)
    qualifying_order_id  BIGINT,
    reward_amount        NUMERIC(12,2)  NOT NULL,
    coupon_id            INTEGER,
    status               CHAR(1)        NOT NULL DEFAULT 'P',  -- P pending, G granted, X expired
    granted_at           TIMESTAMP,
    expires_at           TIMESTAMP,
    created_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_referral_rewards PRIMARY KEY (referral_reward_id),
    CONSTRAINT uq_referral_rewards_user_role UNIQUE (referred_user_id, beneficiary_role),
    CONSTRAINT fk_referral_rewards_user   FOREIGN KEY (referred_user_id)    REFERENCES users (user_id)     ON DELETE CASCADE,
    CONSTRAINT fk_referral_rewards_order  FOREIGN KEY (qualifying_order_id) REFERENCES orders (order_id)   ON DELETE SET NULL,
    CONSTRAINT fk_referral_rewards_coupon FOREIGN KEY (coupon_id)           REFERENCES coupons (coupon_id) ON DELETE SET NULL,
    CONSTRAINT ck_referral_rewards_role   CHECK (beneficiary_role IN ('R','E')),
    CONSTRAINT ck_referral_rewards_amount CHECK (reward_amount > 0),
    CONSTRAINT ck_referral_rewards_status CHECK (status IN ('P','G','X')),
    CONSTRAINT ck_referral_rewards_granted CHECK ((status = 'G') = (granted_at IS NOT NULL))
);

-- =====================================================================
-- RT CRACKERS | 15_NOTIFICATIONS/003_Email_templates.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- email_templates | Purpose: reusable e-mail bodies keyed by code (ORDER_PLACED, COD_OTP...).
-- Keys : PK(template_id) | CK/AK: template_code
-- Rel  : 1:N notifications
-- BCNF : attributes depend only on the template.
-- ---------------------------------------------------------------------
CREATE TABLE email_templates (
    template_id     INTEGER       GENERATED ALWAYS AS IDENTITY,
    template_code   VARCHAR(50)   NOT NULL,
    subject         VARCHAR(200)  NOT NULL,
    body_html       TEXT          NOT NULL,
    body_text       TEXT,
    placeholders    VARCHAR(500),
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_email_templates PRIMARY KEY (template_id),
    CONSTRAINT uq_email_templates_code UNIQUE (template_code),
    CONSTRAINT ck_email_templates_code_upper CHECK (template_code = UPPER(template_code))
);

-- =====================================================================
-- RT CRACKERS | 15_NOTIFICATIONS/001_Notifications.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- notifications | Purpose: a notification message (broadcast or targeted).
-- Keys : PK(notification_id)
-- Rel  : N:1 email_templates, N:1 admins; 1:N user_notifications
-- BCNF : attributes depend only on the message; per-recipient state is in user_notifications.
-- ---------------------------------------------------------------------
CREATE TABLE notifications (
    notification_id    BIGINT        GENERATED ALWAYS AS IDENTITY,
    template_id        INTEGER,
    title              VARCHAR(150)  NOT NULL,
    message            TEXT          NOT NULL,
    notification_type  CHAR(1)       NOT NULL DEFAULT 'S',     -- O order, P promotion, S system, F festival
    reference_type     VARCHAR(40),
    reference_id       VARCHAR(64),
    expires_at         TIMESTAMP,
    created_by         INTEGER,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_notifications PRIMARY KEY (notification_id),
    CONSTRAINT fk_notifications_template   FOREIGN KEY (template_id) REFERENCES email_templates (template_id) ON DELETE SET NULL,
    CONSTRAINT fk_notifications_created_by FOREIGN KEY (created_by)  REFERENCES admins (admin_id)             ON DELETE SET NULL,
    CONSTRAINT ck_notifications_type CHECK (notification_type IN ('O','P','S','F'))
);

-- =====================================================================
-- RT CRACKERS | 15_NOTIFICATIONS/002_User_notifications.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- user_notifications | Purpose: delivery + read state of a notification for one user per channel.
-- Keys : PK(user_notification_id) | CK/AK: (notification_id, user_id, channel)
-- Rel  : N:1 notifications, N:1 users
-- BCNF : status/read state depend on the (notification, user, channel) candidate key.
-- ---------------------------------------------------------------------
CREATE TABLE user_notifications (
    user_notification_id  BIGINT     GENERATED ALWAYS AS IDENTITY,
    notification_id       BIGINT     NOT NULL,
    user_id               BIGINT     NOT NULL,
    channel               CHAR(1)    NOT NULL DEFAULT 'A',     -- A in-app, E e-mail, S SMS, W WhatsApp
    delivery_status       CHAR(1)    NOT NULL DEFAULT 'Q',     -- Q queued, S sent, F failed
    is_read               BOOLEAN    NOT NULL DEFAULT FALSE,
    read_at               TIMESTAMP,
    created_at            TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user_notifications PRIMARY KEY (user_notification_id),
    CONSTRAINT uq_user_notifications_target UNIQUE (notification_id, user_id, channel),
    CONSTRAINT fk_user_notifications_notification FOREIGN KEY (notification_id) REFERENCES notifications (notification_id) ON DELETE CASCADE,
    CONSTRAINT fk_user_notifications_user         FOREIGN KEY (user_id)         REFERENCES users (user_id)                 ON DELETE CASCADE,
    CONSTRAINT ck_user_notifications_channel CHECK (channel IN ('A','E','S','W')),
    CONSTRAINT ck_user_notifications_status  CHECK (delivery_status IN ('Q','S','F')),
    CONSTRAINT ck_user_notifications_read    CHECK (is_read = (read_at IS NOT NULL))
);

-- =====================================================================
-- RT CRACKERS | 16_FESTIVALS/001_Festivals.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- festivals | Purpose: festival campaigns (Diwali, Pongal, New Year...).
-- Keys : PK(festival_id) | CK/AK: slug, (festival_name, festival_date)
-- Rel  : 1:N festival_products, festival_banners, festival_discounts
-- BCNF : attributes depend only on the festival.
-- ---------------------------------------------------------------------
CREATE TABLE festivals (
    festival_id      INTEGER       GENERATED ALWAYS AS IDENTITY,
    festival_name    VARCHAR(100)  NOT NULL,
    slug             VARCHAR(120)  NOT NULL,
    description      TEXT,
    festival_date    DATE          NOT NULL,
    start_date       DATE          NOT NULL,
    end_date         DATE          NOT NULL,
    hero_image_url   VARCHAR(500),
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_festivals PRIMARY KEY (festival_id),
    CONSTRAINT uq_festivals_slug UNIQUE (slug),
    CONSTRAINT uq_festivals_name_date UNIQUE (festival_name, festival_date),
    CONSTRAINT ck_festivals_window CHECK (end_date >= start_date)
);

-- =====================================================================
-- RT CRACKERS | 16_FESTIVALS/002_Festival_products.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- festival_products | Purpose: products featured in a festival.
-- Keys : COMPOSITE PK(festival_id, product_id)
-- Rel  : N:1 festivals, N:1 products
-- BCNF : display_order/is_highlighted depend on the whole pair.
-- ---------------------------------------------------------------------
CREATE TABLE festival_products (
    festival_id     INTEGER    NOT NULL,
    product_id      BIGINT     NOT NULL,
    display_order   SMALLINT   NOT NULL DEFAULT 0,
    is_highlighted  BOOLEAN    NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_festival_products PRIMARY KEY (festival_id, product_id),
    CONSTRAINT fk_festival_products_festival FOREIGN KEY (festival_id) REFERENCES festivals (festival_id) ON DELETE CASCADE,
    CONSTRAINT fk_festival_products_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)   ON DELETE CASCADE
);

-- =====================================================================
-- RT CRACKERS | 16_FESTIVALS/003_Festival_banners.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- festival_banners | Purpose: banners shown during a festival.
-- Keys : COMPOSITE PK(festival_id, banner_id)
-- Rel  : N:1 festivals, N:1 banners
-- BCNF : display_order depends on the whole pair.
-- ---------------------------------------------------------------------
CREATE TABLE festival_banners (
    festival_id    INTEGER    NOT NULL,
    banner_id      INTEGER    NOT NULL,
    display_order  SMALLINT   NOT NULL DEFAULT 0,
    created_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_festival_banners PRIMARY KEY (festival_id, banner_id),
    CONSTRAINT fk_festival_banners_festival FOREIGN KEY (festival_id) REFERENCES festivals (festival_id) ON DELETE CASCADE,
    CONSTRAINT fk_festival_banners_banner   FOREIGN KEY (banner_id)   REFERENCES banners (banner_id)     ON DELETE CASCADE
);

-- =====================================================================
-- RT CRACKERS | 16_FESTIVALS/004_Festival_discounts.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- festival_discounts | Purpose: festival price cuts scoped to a product, a category, or the whole festival (both NULL).
-- Keys : PK(festival_discount_id) | CK/AK: (festival_id, product_id|0, category_id|0) via unique index
-- Rel  : N:1 festivals, products, categories
-- BCNF : discount attributes depend on the candidate key (festival + scope).
-- ---------------------------------------------------------------------
CREATE TABLE festival_discounts (
    festival_discount_id  INTEGER        GENERATED ALWAYS AS IDENTITY,
    festival_id           INTEGER        NOT NULL,
    product_id            BIGINT,
    category_id           INTEGER,
    discount_percentage   DECIMAL(5,2)   NOT NULL,
    min_order_amount      NUMERIC(12,2)  NOT NULL DEFAULT 0,
    max_discount_amount   NUMERIC(12,2),
    is_active             BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_festival_discounts PRIMARY KEY (festival_discount_id),
    CONSTRAINT fk_festival_discounts_festival FOREIGN KEY (festival_id) REFERENCES festivals (festival_id)   ON DELETE CASCADE,
    CONSTRAINT fk_festival_discounts_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)     ON DELETE CASCADE,
    CONSTRAINT fk_festival_discounts_category FOREIGN KEY (category_id) REFERENCES categories (category_id)  ON DELETE CASCADE,
    CONSTRAINT ck_festival_discounts_pct    CHECK (discount_percentage > 0 AND discount_percentage <= 100),
    CONSTRAINT ck_festival_discounts_scope  CHECK (product_id IS NULL OR category_id IS NULL),
    CONSTRAINT ck_festival_discounts_amount CHECK (min_order_amount >= 0 AND (max_discount_amount IS NULL OR max_discount_amount > 0))
);
CREATE UNIQUE INDEX uq_festival_discounts_scope ON festival_discounts (festival_id, COALESCE(product_id, 0), COALESCE(category_id, 0));

-- =====================================================================
-- RT CRACKERS | 17_ANALYTICS/001_Page_views.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- page_views | Purpose: storefront page hits.
-- Keys : PK(page_view_id)
-- Rel  : N:1 users (optional), N:1 sessions (optional)
-- BCNF : attributes describe one hit.
-- ---------------------------------------------------------------------
CREATE TABLE page_views (
    page_view_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id       BIGINT,
    session_id    UUID,
    anonymous_id  VARCHAR(64),
    page_url      VARCHAR(500)  NOT NULL,
    referrer_url  VARCHAR(500),
    device_type   CHAR(1),                                    -- W web, M mobile, T tablet, O other
    ip_address    INET,
    user_agent    VARCHAR(500),
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_page_views PRIMARY KEY (page_view_id),
    CONSTRAINT fk_page_views_user    FOREIGN KEY (user_id)    REFERENCES users (user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_page_views_session FOREIGN KEY (session_id) REFERENCES sessions (session_id) ON DELETE SET NULL,
    CONSTRAINT ck_page_views_device  CHECK (device_type IS NULL OR device_type IN ('W','M','T','O'))
);

-- =====================================================================
-- RT CRACKERS | 17_ANALYTICS/002_Product_views.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- product_views | Purpose: product detail page views (feeds products.view_count by trigger).
-- Keys : PK(product_view_id)
-- Rel  : N:1 products, N:1 users (optional), N:1 sessions (optional)
-- BCNF : attributes describe one view.
-- ---------------------------------------------------------------------
CREATE TABLE product_views (
    product_view_id  BIGINT     GENERATED ALWAYS AS IDENTITY,
    product_id       BIGINT     NOT NULL,
    user_id          BIGINT,
    session_id       UUID,
    anonymous_id     VARCHAR(64),
    duration_seconds INTEGER,
    created_at       TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_product_views PRIMARY KEY (product_view_id),
    CONSTRAINT fk_product_views_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE,
    CONSTRAINT fk_product_views_user    FOREIGN KEY (user_id)    REFERENCES users (user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_product_views_session FOREIGN KEY (session_id) REFERENCES sessions (session_id) ON DELETE SET NULL,
    CONSTRAINT ck_product_views_duration CHECK (duration_seconds IS NULL OR duration_seconds >= 0)
);

-- product_views -> products.view_count
CREATE OR REPLACE FUNCTION fn_increment_view_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE products SET view_count = view_count + 1 WHERE product_id = NEW.product_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_product_views_count AFTER INSERT ON product_views
    FOR EACH ROW EXECUTE FUNCTION fn_increment_view_count();

-- =====================================================================
-- RT CRACKERS | 17_ANALYTICS/003_Search_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- search_logs | Purpose: what shoppers search for and what they click.
-- Keys : PK(search_log_id)
-- Rel  : N:1 users (optional), N:1 products (clicked)
-- BCNF : attributes describe one search.
-- ---------------------------------------------------------------------
CREATE TABLE search_logs (
    search_log_id       BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id             BIGINT,
    anonymous_id        VARCHAR(64),
    search_query        VARCHAR(255)  NOT NULL,
    results_count       INTEGER       NOT NULL DEFAULT 0,
    clicked_product_id  BIGINT,
    ip_address          INET,
    created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_search_logs PRIMARY KEY (search_log_id),
    CONSTRAINT fk_search_logs_user    FOREIGN KEY (user_id)            REFERENCES users (user_id)       ON DELETE SET NULL,
    CONSTRAINT fk_search_logs_product FOREIGN KEY (clicked_product_id) REFERENCES products (product_id) ON DELETE SET NULL,
    CONSTRAINT ck_search_logs_results CHECK (results_count >= 0)
);

-- =====================================================================
-- RT CRACKERS | 17_ANALYTICS/004_Sales_reports.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- sales_reports | Purpose: pre-aggregated daily/weekly/monthly sales snapshots filled by a scheduled job.
-- Keys : PK(sales_report_id) | CK/AK: (report_type, report_date)
-- Rel  : none (derived reporting table)
-- BCNF : net_sales is GENERATED; all other figures depend on the (type, date) candidate key.
-- ---------------------------------------------------------------------
CREATE TABLE sales_reports (
    sales_report_id   INTEGER        GENERATED ALWAYS AS IDENTITY,
    report_type       CHAR(1)        NOT NULL,                -- D daily, W weekly, M monthly
    report_date       DATE           NOT NULL,
    total_orders      INTEGER        NOT NULL DEFAULT 0,
    cancelled_orders  INTEGER        NOT NULL DEFAULT 0,
    returned_orders   INTEGER        NOT NULL DEFAULT 0,
    items_sold        INTEGER        NOT NULL DEFAULT 0,
    gross_sales       NUMERIC(14,2)  NOT NULL DEFAULT 0,
    discount_total    NUMERIC(14,2)  NOT NULL DEFAULT 0,
    tax_total         NUMERIC(14,2)  NOT NULL DEFAULT 0,
    shipping_total    NUMERIC(14,2)  NOT NULL DEFAULT 0,
    net_sales         NUMERIC(14,2)  GENERATED ALWAYS AS (gross_sales - discount_total + tax_total + shipping_total) STORED,
    cod_collected     NUMERIC(14,2)  NOT NULL DEFAULT 0,
    created_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_sales_reports PRIMARY KEY (sales_report_id),
    CONSTRAINT uq_sales_reports_type_date UNIQUE (report_type, report_date),
    CONSTRAINT ck_sales_reports_type    CHECK (report_type IN ('D','W','M')),
    CONSTRAINT ck_sales_reports_counts  CHECK (total_orders >= 0 AND cancelled_orders >= 0 AND returned_orders >= 0 AND items_sold >= 0),
    CONSTRAINT ck_sales_reports_amounts CHECK (gross_sales >= 0 AND discount_total >= 0 AND tax_total >= 0 AND shipping_total >= 0 AND cod_collected >= 0)
);

-- =====================================================================
-- RT CRACKERS | 17_ANALYTICS/005_User_activity_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- user_activity_logs | Purpose: generic customer activity trail (login, add to cart, checkout...).
-- Keys : PK(activity_id)
-- Rel  : N:1 users
-- BCNF : attributes describe one activity.
-- ---------------------------------------------------------------------
CREATE TABLE user_activity_logs (
    activity_id    BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id        BIGINT        NOT NULL,
    activity_type  VARCHAR(50)   NOT NULL,
    entity_type    VARCHAR(40),
    entity_id      VARCHAR(64),
    description    VARCHAR(255),
    metadata       JSONB,
    ip_address     INET,
    user_agent     VARCHAR(500),
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_user_activity_logs PRIMARY KEY (activity_id),
    CONSTRAINT fk_user_activity_logs_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);

-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/001_Settings.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- settings | Purpose: business settings editable by staff (store name, COD cap...).
-- Keys : PK(setting_id) | CK/AK: setting_key
-- Rel  : N:1 admins (updated_by)
-- BCNF : value/type depend on the setting key.
-- ---------------------------------------------------------------------
CREATE TABLE settings (
    setting_id     INTEGER       GENERATED ALWAYS AS IDENTITY,
    setting_key    VARCHAR(80)   NOT NULL,
    setting_value  TEXT          NOT NULL,
    value_type     CHAR(1)       NOT NULL DEFAULT 'S',        -- S string, N number, B boolean, J json
    description    VARCHAR(255),
    is_public      BOOLEAN       NOT NULL DEFAULT FALSE,
    updated_by     INTEGER,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_settings PRIMARY KEY (setting_id),
    CONSTRAINT uq_settings_key UNIQUE (setting_key),
    CONSTRAINT fk_settings_updated_by FOREIGN KEY (updated_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_settings_value_type CHECK (value_type IN ('S','N','B','J'))
);

-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/003_System_configurations.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- system_configurations | Purpose: technical configuration (token TTLs, login lockout, SMTP host...).
-- Keys : PK(config_id) | CK/AK: (config_group, config_key)
-- Rel  : none
-- BCNF : value/encryption flag depend on the (group, key) candidate key.
-- ---------------------------------------------------------------------
CREATE TABLE system_configurations (
    config_id      INTEGER       GENERATED ALWAYS AS IDENTITY,
    config_group   VARCHAR(40)   NOT NULL,
    config_key     VARCHAR(80)   NOT NULL,
    config_value   TEXT          NOT NULL,
    is_encrypted   BOOLEAN       NOT NULL DEFAULT FALSE,
    description    VARCHAR(255),
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_system_configurations PRIMARY KEY (config_id),
    CONSTRAINT uq_system_configurations_group_key UNIQUE (config_group, config_key)
);

-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/002_Feature_flags.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- feature_flags | Purpose: runtime on/off switches with percentage rollout.
-- Keys : PK(flag_id) | CK/AK: flag_key
-- Rel  : none
-- BCNF : attributes depend only on the flag.
-- ---------------------------------------------------------------------
CREATE TABLE feature_flags (
    flag_id             SMALLINT      GENERATED ALWAYS AS IDENTITY,
    flag_key            VARCHAR(60)   NOT NULL,
    description         VARCHAR(255),
    is_enabled          BOOLEAN       NOT NULL DEFAULT FALSE,
    rollout_percentage  SMALLINT      NOT NULL DEFAULT 100,
    enabled_from        TIMESTAMP,
    enabled_until       TIMESTAMP,
    created_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_feature_flags PRIMARY KEY (flag_id),
    CONSTRAINT uq_feature_flags_key UNIQUE (flag_key),
    CONSTRAINT ck_feature_flags_rollout CHECK (rollout_percentage BETWEEN 0 AND 100),
    CONSTRAINT ck_feature_flags_window  CHECK (enabled_from IS NULL OR enabled_until IS NULL OR enabled_until > enabled_from)
);

-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/005_Audit_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- audit_logs | Purpose: row-level change history (before/after JSON) written by trigger.
-- Keys : PK(audit_log_id)
-- Rel  : N:1 users (optional)
-- BCNF : attributes describe one change.
-- ---------------------------------------------------------------------
CREATE TABLE audit_logs (
    audit_log_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    table_name    VARCHAR(63)   NOT NULL,
    record_id     VARCHAR(64)   NOT NULL,
    action        CHAR(1)       NOT NULL,                     -- I insert, U update, D delete
    old_data      JSONB,
    new_data      JSONB,
    changed_by    BIGINT,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_audit_logs PRIMARY KEY (audit_log_id),
    CONSTRAINT fk_audit_logs_user FOREIGN KEY (changed_by) REFERENCES users (user_id) ON DELETE SET NULL,
    CONSTRAINT ck_audit_logs_action CHECK (action IN ('I','U','D'))
);

-- generic row-level audit trail (argument = primary key column name)
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk  TEXT := TG_ARGV[0];
    v_old JSONB;
    v_new JSONB;
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN v_old := to_jsonb(OLD); END IF;
    IF TG_OP IN ('INSERT','UPDATE') THEN v_new := to_jsonb(NEW); END IF;
    INSERT INTO audit_logs (table_name, record_id, action, old_data, new_data, changed_by)
    VALUES (TG_TABLE_NAME, COALESCE(v_new ->> v_pk, v_old ->> v_pk), LEFT(TG_OP, 1), v_old, v_new,
            NULLIF(current_setting('app.current_user_id', TRUE), '')::BIGINT);
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_products_audit         AFTER INSERT OR UPDATE OR DELETE ON products         FOR EACH ROW EXECUTE FUNCTION fn_audit_log('product_id');
CREATE TRIGGER trg_orders_audit           AFTER INSERT OR UPDATE OR DELETE ON orders           FOR EACH ROW EXECUTE FUNCTION fn_audit_log('order_id');
CREATE TRIGGER trg_coupons_audit          AFTER INSERT OR UPDATE OR DELETE ON coupons          FOR EACH ROW EXECUTE FUNCTION fn_audit_log('coupon_id');
CREATE TRIGGER trg_settings_audit         AFTER INSERT OR UPDATE OR DELETE ON settings         FOR EACH ROW EXECUTE FUNCTION fn_audit_log('setting_id');
CREATE TRIGGER trg_payment_methods_audit  AFTER INSERT OR UPDATE OR DELETE ON payment_methods  FOR EACH ROW EXECUTE FUNCTION fn_audit_log('payment_method_id');

-- =====================================================================
-- RT CRACKERS | 18_SYSTEM/004_Error_logs.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- error_logs | Purpose: application/database errors for triage.
-- Keys : PK(error_log_id)
-- Rel  : N:1 users (optional), N:1 admins (resolver)
-- BCNF : attributes describe one error event.
-- ---------------------------------------------------------------------
CREATE TABLE error_logs (
    error_log_id    BIGINT         GENERATED ALWAYS AS IDENTITY,
    error_level     CHAR(1)        NOT NULL DEFAULT 'E',      -- W warning, E error, F fatal
    error_code      VARCHAR(40),
    error_message   TEXT           NOT NULL,
    stack_trace     TEXT,
    source          VARCHAR(100),
    request_url     VARCHAR(500),
    request_method  VARCHAR(10),
    user_id         BIGINT,
    ip_address      INET,
    context         JSONB,
    is_resolved     BOOLEAN        NOT NULL DEFAULT FALSE,
    resolved_by     INTEGER,
    resolved_at     TIMESTAMP,
    created_at      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_error_logs PRIMARY KEY (error_log_id),
    CONSTRAINT fk_error_logs_user     FOREIGN KEY (user_id)     REFERENCES users (user_id)   ON DELETE SET NULL,
    CONSTRAINT fk_error_logs_resolver FOREIGN KEY (resolved_by) REFERENCES admins (admin_id) ON DELETE SET NULL,
    CONSTRAINT ck_error_logs_level    CHECK (error_level IN ('W','E','F')),
    CONSTRAINT ck_error_logs_resolved CHECK (is_resolved = (resolved_at IS NOT NULL))
);

-- =====================================================================
-- RT CRACKERS | 19_INDEXES/001_Authentication_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_users_referred_by          ON users (referred_by);
CREATE INDEX idx_users_status               ON users (status);
CREATE INDEX idx_sessions_user_id           ON sessions (user_id, expires_at);
CREATE INDEX idx_refresh_tokens_user_id     ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_session_id  ON refresh_tokens (session_id);
CREATE INDEX idx_login_history_user_time    ON login_history (user_id, created_at DESC);
CREATE INDEX idx_login_history_ip           ON login_history (ip_address);
CREATE INDEX idx_password_reset_user        ON password_reset_tokens (user_id);
CREATE INDEX idx_admin_activity_admin_time  ON admin_activity_logs (admin_id, created_at DESC);
CREATE INDEX idx_admin_notifications_unread ON admin_notifications (admin_id) WHERE NOT is_read;

-- NOTE: users.email/phone already have unique indexes (uq_users_email, uq_users_phone).

-- =====================================================================
-- RT CRACKERS | 19_INDEXES/002_Product_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_subcategories_category_id  ON subcategories (category_id);
CREATE INDEX idx_products_category_id       ON products (category_id, subcategory_id);
CREATE INDEX idx_products_brand_id          ON products (brand_id);
CREATE INDEX idx_products_active_featured   ON products (is_featured) WHERE status = 'A';
CREATE INDEX idx_products_active_trending   ON products (is_trending) WHERE status = 'A';
CREATE INDEX idx_products_search            ON products USING GIN (TO_TSVECTOR('english', product_name || ' ' || COALESCE(short_description, '')));
CREATE INDEX idx_product_variants_product   ON product_variants (product_id);
CREATE INDEX idx_attribute_values_attribute ON attribute_values (attribute_id);
CREATE INDEX idx_reviews_product_status     ON reviews (product_id, status);
CREATE INDEX idx_reviews_user_id            ON reviews (user_id);
CREATE INDEX idx_review_reports_review      ON review_reports (review_id);

-- NOTE: products.sku/barcode/slug already have unique indexes (uq_products_sku, uq_products_barcode, uq_products_slug).
-- A second CREATE INDEX on the same columns would only duplicate them.

-- =====================================================================
-- RT CRACKERS | 19_INDEXES/003_Order_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_pincodes_zone_id           ON pincodes (zone_id);
CREATE INDEX idx_addresses_user_id          ON addresses (user_id);
CREATE INDEX idx_addresses_postal_code      ON addresses (postal_code);
CREATE INDEX idx_coupons_active_valid       ON coupons (valid_until) WHERE is_active;
CREATE INDEX idx_cart_items_product         ON cart_items (product_id);
CREATE INDEX idx_wishlist_items_product     ON wishlist_items (product_id);
CREATE INDEX idx_orders_user_created        ON orders (user_id, created_at DESC);
CREATE INDEX idx_orders_status              ON orders (order_status, created_at DESC);
CREATE INDEX idx_orders_payment_status      ON orders (payment_status) WHERE payment_status = 'P';
CREATE INDEX idx_orders_coupon_id           ON orders (coupon_id);
CREATE INDEX idx_orders_shipping_address    ON orders (shipping_address_id);
CREATE INDEX idx_orders_billing_address     ON orders (billing_address_id);
CREATE INDEX idx_order_items_order_id       ON order_items (order_id);
CREATE INDEX idx_order_items_product_id     ON order_items (product_id);
CREATE INDEX idx_order_status_history_order ON order_status_history (order_id, created_at);
CREATE INDEX idx_return_requests_item       ON return_requests (order_item_id);
CREATE INDEX idx_replacement_requests_item  ON replacement_requests (order_item_id);
CREATE INDEX idx_refunds_order_id           ON refunds (order_id);
CREATE INDEX idx_cod_transactions_pending   ON cod_transactions (status) WHERE status = 'P';
CREATE INDEX idx_shipments_order_id         ON shipments (order_id);

-- NOTE: orders.order_number, invoices.invoice_number and coupons.coupon_code are already covered by
-- unique indexes (uq_orders_order_number, uq_invoices_invoice_number, uq_coupons_coupon_code).

-- =====================================================================
-- RT CRACKERS | 19_INDEXES/004_Inventory_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_inventory_low_stock        ON inventory (quantity_on_hand);
CREATE INDEX idx_inventory_movements_inv    ON inventory_movements (inventory_id, created_at DESC);

-- =====================================================================
-- RT CRACKERS | 19_INDEXES/005_Analytics_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_page_views_created         ON page_views (created_at);
CREATE INDEX idx_product_views_product_time ON product_views (product_id, created_at);
CREATE INDEX idx_search_logs_query          ON search_logs (search_query);
CREATE INDEX idx_user_activity_user_time    ON user_activity_logs (user_id, created_at DESC);

-- =====================================================================
-- RT CRACKERS | 19_INDEXES/006_System_indexes.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE INDEX idx_user_notifications_user    ON user_notifications (user_id, is_read);
CREATE INDEX idx_festival_products_product  ON festival_products (product_id);
CREATE INDEX idx_audit_logs_record          ON audit_logs (table_name, record_id);
CREATE INDEX idx_error_logs_open            ON error_logs (created_at DESC) WHERE NOT is_resolved;

-- updated_at triggers
-- updated_at maintenance on every table that has the column
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT c.table_name
        FROM information_schema.columns c
        JOIN information_schema.tables t
          ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
        WHERE c.table_schema = 'public' AND c.column_name = 'updated_at'
    LOOP
        EXECUTE format('CREATE TRIGGER trg_%1$s_updated_at BEFORE UPDATE ON public.%1$I FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()', r.table_name);
    END LOOP;
END;
$$;

-- =====================================================================
-- 20. SUPABASE: ROW LEVEL SECURITY (deny by default)
-- Every table in public is exposed through the Supabase API, so RLS is
-- enabled with no policies: only the service-role key (your backend)
-- can read/write until you add explicit policies.
-- =====================================================================

DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.tablename);
    END LOOP;
END;
$$;

COMMIT;


-- ---- seed data ----
-- =====================================================================
-- RT CRACKERS | 99_DEPLOYMENT/002_Master_seed_data.sql
-- Source: rt_crackers_schema.sql (split by module) | minimal reference rows
-- =====================================================================

BEGIN;

INSERT INTO roles (role_code, role_name, role_scope, description, is_system) VALUES
    ('CUSTOMER',       'Customer',        'U', 'Registered shopper',                 TRUE),
    ('SUPER_ADMIN',    'Super Admin',     'A', 'Full access to every module',        TRUE),
    ('STORE_MANAGER',  'Store Manager',   'A', 'Catalogue, orders and inventory',    TRUE),
    ('DELIVERY_AGENT', 'Delivery Agent',  'A', 'Delivers orders and collects cash',  TRUE),
    ('SUPPORT_AGENT',  'Support Agent',   'A', 'Handles returns and reviews',        TRUE);

INSERT INTO permissions (permission_code, module_name, description) VALUES
    ('PRODUCT.MANAGE',   'product',   'Create and edit products'),
    ('INVENTORY.MANAGE', 'inventory', 'Adjust stock'),
    ('ORDER.MANAGE',     'order',     'View and update orders'),
    ('COD.COLLECT',      'payment',   'Record COD collection'),
    ('COD.RECONCILE',    'payment',   'Verify cash hand-over'),
    ('REFUND.APPROVE',   'payment',   'Approve refunds'),
    ('REVIEW.MODERATE',  'review',    'Moderate reviews'),
    ('MARKETING.MANAGE', 'marketing', 'Coupons, banners, festivals'),
    ('SETTINGS.MANAGE',  'system',    'Edit settings and feature flags');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM roles r CROSS JOIN permissions p WHERE r.role_code = 'SUPER_ADMIN';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM roles r JOIN permissions p
  ON p.permission_code IN ('PRODUCT.MANAGE','INVENTORY.MANAGE','ORDER.MANAGE','COD.RECONCILE','MARKETING.MANAGE')
WHERE r.role_code = 'STORE_MANAGER';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM roles r JOIN permissions p ON p.permission_code = 'COD.COLLECT'
WHERE r.role_code = 'DELIVERY_AGENT';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM roles r JOIN permissions p ON p.permission_code IN ('REVIEW.MODERATE','REFUND.APPROVE')
WHERE r.role_code = 'SUPPORT_AGENT';

INSERT INTO payment_methods (method_code, method_name, description, min_order_amount, max_order_amount)
VALUES ('COD', 'Cash On Delivery', 'Pay in cash when the order is delivered', 0, 50000);

INSERT INTO shipping_methods (method_code, method_name, description, min_delivery_days, max_delivery_days) VALUES
    ('STD', 'Standard Delivery', 'Regular road delivery', 3, 7),
    ('EXP', 'Express Delivery',  'Priority dispatch',     1, 3);

INSERT INTO settings (setting_key, setting_value, value_type, description, is_public) VALUES
    ('store_name',            'RT Crackers', 'S', 'Public store name',                    TRUE),
    ('store_currency',        'INR',         'S', 'Store currency',                       TRUE),
    ('cod_enabled',           'true',        'B', 'Master switch for Cash On Delivery',   TRUE),
    ('min_order_amount',      '500',         'N', 'Minimum order value',                  TRUE),
    ('allow_guest_checkout',  'false',       'B', 'Guests cannot place COD orders',       FALSE);

INSERT INTO feature_flags (flag_key, description, is_enabled) VALUES
    ('wishlist',           'Wishlist feature',            TRUE),
    ('product_comparison', 'Product comparison feature',  TRUE),
    ('referral_program',   'Referral rewards',            FALSE),
    ('festival_mode',      'Festival landing pages',      FALSE);

COMMIT;
