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
