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
