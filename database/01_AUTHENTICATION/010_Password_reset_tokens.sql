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
