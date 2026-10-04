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
