-- =====================================================================
-- RT CRACKERS | 13_REVIEWS/003_Review_reports.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- review_reports | Purpose: abuse reports raised on reviews.
-- Keys : PK(report_id) | CK/AK: (review_id, reported_by)
-- Rel  : N:1 reviews, users, admins
-- BCNF : attributes depend on the report.
-- ---------------------------------------------------------------------
CREATE TABLE review_reports (
    report_id    BIGINT        GENERATED ALWAYS AS IDENTITY,
    review_id    BIGINT        NOT NULL,
    reported_by  BIGINT        NOT NULL,
    reason_code  CHAR(1)       NOT NULL,                       -- S spam, A abusive, F fake, I irrelevant, O other
    description  VARCHAR(500),
    status       CHAR(1)       NOT NULL DEFAULT 'P',           -- P pending, R actioned, D dismissed
    reviewed_by  INTEGER,
    reviewed_at  TIMESTAMP,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_review_reports PRIMARY KEY (report_id),
    CONSTRAINT uq_review_reports_review_user UNIQUE (review_id, reported_by),
    CONSTRAINT fk_review_reports_review   FOREIGN KEY (review_id)   REFERENCES reviews (review_id) ON DELETE CASCADE,
    CONSTRAINT fk_review_reports_user     FOREIGN KEY (reported_by) REFERENCES users (user_id)     ON DELETE CASCADE,
    CONSTRAINT fk_review_reports_reviewer FOREIGN KEY (reviewed_by) REFERENCES admins (admin_id)   ON DELETE SET NULL,
    CONSTRAINT ck_review_reports_reason   CHECK (reason_code IN ('S','A','F','I','O')),
    CONSTRAINT ck_review_reports_status   CHECK (status IN ('P','R','D')),
    CONSTRAINT ck_review_reports_reviewed CHECK ((status = 'P') = (reviewed_at IS NULL))
);

-- review_reports -> reviews.reported_count
CREATE OR REPLACE FUNCTION fn_sync_review_reported_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_review_id BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN v_review_id := OLD.review_id; ELSE v_review_id := NEW.review_id; END IF;
    UPDATE reviews
       SET reported_count = (SELECT COUNT(*) FROM review_reports WHERE review_id = v_review_id)
     WHERE review_id = v_review_id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER trg_review_reports_sync_count AFTER INSERT OR DELETE ON review_reports
    FOR EACH ROW EXECUTE FUNCTION fn_sync_review_reported_count();
