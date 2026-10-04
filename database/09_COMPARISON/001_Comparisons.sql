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
