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
