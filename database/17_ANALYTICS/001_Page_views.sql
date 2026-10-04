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
