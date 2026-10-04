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
