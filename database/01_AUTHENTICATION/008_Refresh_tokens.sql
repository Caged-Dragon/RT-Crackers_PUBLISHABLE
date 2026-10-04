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
