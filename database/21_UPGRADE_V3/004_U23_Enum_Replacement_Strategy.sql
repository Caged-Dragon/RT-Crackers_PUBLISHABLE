-- RT CRACKERS | 21_UPGRADE_V3/004_U23_Enum_Replacement_Strategy.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 23 - ENUM REPLACEMENT STRATEGY
-- Gender and address type become reference tables with foreign keys.
-- (Order status is U22 above; languages, currencies, device types... are in U31 reference_data.)
-- =====================================================================
CREATE TABLE genders (
    gender_id    SMALLINT     GENERATED ALWAYS AS IDENTITY,
    gender_code  CHAR(1)      NOT NULL,
    gender_name  VARCHAR(40)  NOT NULL,
    sort_order   SMALLINT     NOT NULL DEFAULT 0,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_genders PRIMARY KEY (gender_id),
    CONSTRAINT uq_genders_code UNIQUE (gender_code),
    CONSTRAINT uq_genders_name UNIQUE (gender_name),
    CONSTRAINT ck_genders_code CHECK (gender_code ~ '^[A-Z]$')
);
INSERT INTO genders (gender_code, gender_name, sort_order) VALUES ('M', 'Male', 1), ('F', 'Female', 2), ('O', 'Other', 3);

CREATE TABLE address_types (
    address_type_id    SMALLINT     GENERATED ALWAYS AS IDENTITY,
    address_type_code  VARCHAR(10)  NOT NULL,
    address_type_name  VARCHAR(40)  NOT NULL,
    sort_order         SMALLINT     NOT NULL DEFAULT 0,
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_address_types PRIMARY KEY (address_type_id),
    CONSTRAINT uq_address_types_code UNIQUE (address_type_code),
    CONSTRAINT uq_address_types_name UNIQUE (address_type_name),
    CONSTRAINT ck_address_types_code CHECK (address_type_code ~ '^[A-Z]+$')
);
INSERT INTO address_types (address_type_code, address_type_name, sort_order) VALUES ('HOME', 'Home', 1), ('OFFICE', 'Office', 2), ('WAREHOUSE', 'Warehouse', 3), ('OTHER', 'Other', 4);
-- (v2 U8 replaced addresses.address_type with address_label; the label is what now references this table)

ALTER TABLE users     DROP CONSTRAINT ck_users_gender;
ALTER TABLE users     ADD CONSTRAINT fk_users_gender FOREIGN KEY (gender) REFERENCES genders (gender_code) ON DELETE RESTRICT;
ALTER TABLE addresses DROP CONSTRAINT ck_addresses_label;
ALTER TABLE addresses ADD CONSTRAINT fk_addresses_address_label FOREIGN KEY (address_label) REFERENCES address_types (address_type_code) ON DELETE RESTRICT;
