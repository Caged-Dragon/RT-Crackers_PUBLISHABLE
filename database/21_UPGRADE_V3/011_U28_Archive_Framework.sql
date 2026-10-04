-- RT CRACKERS | 21_UPGRADE_V3/011_U28_Archive_Framework.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 28 - ARCHIVE FRAMEWORK
-- Archived rows are stored as JSONB so the archive never breaks when a live table changes.
-- Logs and notifications are MOVED (deleted from the live table).
-- Orders are SNAPSHOTTED only: they stay in orders because invoices, refunds, returns and
-- reviews point at them. Purging an archived order is deliberately a manual decision.
-- Nothing runs on its own: call fn_run_data_retention(FALSE) from a scheduler (pg_cron / Supabase cron).
-- =====================================================================
CREATE TABLE archived_orders (
    archived_order_id  BIGINT         GENERATED ALWAYS AS IDENTITY,
    order_id           BIGINT         NOT NULL,                -- no foreign key: the archive outlives the live row
    order_number       VARCHAR(20)    NOT NULL,
    user_id            BIGINT,
    order_status       CHAR(1)        NOT NULL,
    total_amount       NUMERIC(12,2)  NOT NULL,
    ordered_at         TIMESTAMP      NOT NULL,
    order_snapshot     JSONB          NOT NULL,                -- order + items, invoice, shipments, history, COD, refunds, returns
    archived_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_archived_orders PRIMARY KEY (archived_order_id),
    CONSTRAINT uq_archived_orders_order  UNIQUE (order_id),
    CONSTRAINT uq_archived_orders_number UNIQUE (order_number),
    CONSTRAINT ck_archived_orders_snapshot CHECK (jsonb_typeof(order_snapshot) = 'object')
);
CREATE INDEX idx_archived_orders_user ON archived_orders (user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_archived_orders_date ON archived_orders (ordered_at);

CREATE TABLE archived_logs (
    archived_log_id  BIGINT       GENERATED ALWAYS AS IDENTITY,
    source_table     VARCHAR(63)  NOT NULL,
    source_id        VARCHAR(64)  NOT NULL,
    logged_at        TIMESTAMP    NOT NULL,
    log_data         JSONB        NOT NULL,
    archived_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_archived_logs PRIMARY KEY (archived_log_id),
    CONSTRAINT uq_archived_logs_source UNIQUE (source_table, source_id)
);
CREATE INDEX idx_archived_logs_time ON archived_logs (source_table, logged_at);

CREATE TABLE archived_notifications (
    archived_notification_id  BIGINT     GENERATED ALWAYS AS IDENTITY,
    user_notification_id      BIGINT     NOT NULL,
    user_id                   BIGINT     NOT NULL,
    notification_id           BIGINT     NOT NULL,
    notification_data         JSONB      NOT NULL,
    notified_at               TIMESTAMP  NOT NULL,
    archived_at               TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_archived_notifications PRIMARY KEY (archived_notification_id),
    CONSTRAINT uq_archived_notifications_source UNIQUE (user_notification_id)
);
CREATE INDEX idx_archived_notifications_user ON archived_notifications (user_id);
CREATE INDEX idx_archived_notifications_time ON archived_notifications (notified_at);

CREATE TABLE archive_runs (
    archive_run_id  BIGINT        GENERATED ALWAYS AS IDENTITY,
    entity_name     VARCHAR(63)   NOT NULL,
    action          VARCHAR(10)   NOT NULL,                   -- ARCHIVE or PURGE
    cutoff_at       TIMESTAMP     NOT NULL,
    rows_affected   INTEGER       NOT NULL DEFAULT 0,
    started_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at     TIMESTAMP,
    run_by          VARCHAR(80)   NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_archive_runs PRIMARY KEY (archive_run_id),
    CONSTRAINT ck_archive_runs_action CHECK (action IN ('ARCHIVE','PURGE'))
);
CREATE INDEX idx_archive_runs_entity ON archive_runs (entity_name, started_at DESC);

-- move one batch of a log table into archived_logs
CREATE OR REPLACE FUNCTION fn_archive_logs(p_source TEXT, p_cutoff TIMESTAMP, p_limit INTEGER DEFAULT 5000)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_pk   TEXT;
    v_ts   TEXT;
    v_rows INTEGER;
BEGIN
    SELECT m.pk, m.ts INTO v_pk, v_ts
      FROM (VALUES ('audit_logs', 'audit_id', 'changed_at'), ('error_logs', 'error_log_id', 'created_at'),
                   ('login_history', 'login_id', 'created_at'), ('search_logs', 'search_log_id', 'created_at'),
                   ('user_activity_logs', 'activity_id', 'created_at'), ('page_views', 'page_view_id', 'created_at')) m(t, pk, ts)
     WHERE m.t = p_source;
    IF NOT FOUND THEN RAISE EXCEPTION 'fn_archive_logs does not support table %', p_source; END IF;

    EXECUTE format($q$
        WITH moved AS (
            DELETE FROM %1$I WHERE ctid IN (SELECT ctid FROM %1$I WHERE %3$I < $1 ORDER BY %3$I LIMIT $2) RETURNING *)
        INSERT INTO archived_logs (source_table, source_id, logged_at, log_data)
        SELECT %1$L, to_jsonb(moved) ->> %2$L, moved.%3$I, to_jsonb(moved) FROM moved$q$,
        p_source, v_pk, v_ts) USING p_cutoff, p_limit;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows;
END;
$$;

-- move one batch of user_notifications (with the notification text) into archived_notifications
CREATE OR REPLACE FUNCTION fn_archive_notifications(p_cutoff TIMESTAMP, p_limit INTEGER DEFAULT 5000)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_rows INTEGER;
BEGIN
    WITH moved AS (
        DELETE FROM user_notifications
         WHERE user_notification_id IN (SELECT user_notification_id FROM user_notifications
                                         WHERE created_at < p_cutoff ORDER BY created_at LIMIT p_limit)
        RETURNING *)
    INSERT INTO archived_notifications (user_notification_id, user_id, notification_id, notification_data, notified_at)
    SELECT m.user_notification_id, m.user_id, m.notification_id,
           to_jsonb(m) || jsonb_build_object('notification', to_jsonb(n)), m.created_at
      FROM moved m LEFT JOIN notifications n ON n.notification_id = m.notification_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows;
END;
$$;

-- snapshot one batch of finished orders (delivered / cancelled / returned) with everything attached to them.
-- Skips orders with an open return, replacement or refund. The live order is NOT removed.
CREATE OR REPLACE FUNCTION fn_archive_orders(p_cutoff TIMESTAMP, p_limit INTEGER DEFAULT 5000)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE v_rows INTEGER;
BEGIN
    INSERT INTO archived_orders (order_id, order_number, user_id, order_status, total_amount, ordered_at, order_snapshot)
    SELECT o.order_id, o.order_number, o.user_id, o.order_status, o.total_amount, o.created_at,
           to_jsonb(o)
           || jsonb_build_object(
                'items',           COALESCE((SELECT jsonb_agg(to_jsonb(i)) FROM order_items i WHERE i.order_id = o.order_id), '[]'::JSONB),
                'invoice',         (SELECT to_jsonb(v) FROM invoices v WHERE v.order_id = o.order_id),
                'shipments',       COALESCE((SELECT jsonb_agg(to_jsonb(s)) FROM shipments s WHERE s.order_id = o.order_id), '[]'::JSONB),
                'status_history',  COALESCE((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.created_at) FROM order_status_history h WHERE h.order_id = o.order_id), '[]'::JSONB),
                'cod_transaction', (SELECT to_jsonb(c) FROM cod_transactions c WHERE c.order_id = o.order_id),
                'refunds',         COALESCE((SELECT jsonb_agg(to_jsonb(r)) FROM refunds r WHERE r.order_id = o.order_id), '[]'::JSONB),
                'returns',         COALESCE((SELECT jsonb_agg(to_jsonb(rr)) FROM return_requests rr
                                              JOIN order_items oi ON oi.order_item_id = rr.order_item_id WHERE oi.order_id = o.order_id), '[]'::JSONB))
      FROM orders o
     WHERE o.order_status IN ('D','X','R')
       AND o.created_at < p_cutoff
       AND NOT EXISTS (SELECT 1 FROM archived_orders a WHERE a.order_id = o.order_id)
       AND NOT EXISTS (SELECT 1 FROM return_requests rr JOIN order_items oi ON oi.order_item_id = rr.order_item_id
                        WHERE oi.order_id = o.order_id AND rr.status IN ('R','A','P'))
       AND NOT EXISTS (SELECT 1 FROM replacement_requests rp JOIN order_items oi ON oi.order_item_id = rp.order_item_id
                        WHERE oi.order_id = o.order_id AND rp.status IN ('R','A','S'))
       AND NOT EXISTS (SELECT 1 FROM refunds r WHERE r.order_id = o.order_id AND r.status IN ('P','A'))
     ORDER BY o.created_at
     LIMIT p_limit;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN v_rows;
END;
$$;

-- Runs every active retention policy. DRY RUN BY DEFAULT: it only reports what it would do.
--   SELECT * FROM fn_run_data_retention();        -- look first
--   SELECT * FROM fn_run_data_retention(FALSE);   -- then archive for real
CREATE OR REPLACE FUNCTION fn_run_data_retention(p_dry_run BOOLEAN DEFAULT TRUE)
RETURNS TABLE (entity_name TEXT, cutoff_at TIMESTAMP, eligible_rows BIGINT, archived_rows INTEGER)
LANGUAGE plpgsql AS $$
DECLARE
    r        RECORD;
    v_batch  INTEGER := COALESCE(fn_rule_number('archive.batch_size'), 5000)::INTEGER;
    v_cut    TIMESTAMP;
    v_total  INTEGER;
    v_n      INTEGER;
    v_elig   BIGINT;
    v_run    BIGINT;
BEGIN
    FOR r IN SELECT * FROM data_retention_policies WHERE is_active ORDER BY policy_id LOOP
        v_cut := CURRENT_TIMESTAMP - make_interval(days => r.archive_after_days);
        v_total := 0;

        IF r.entity_name = 'orders' THEN
            SELECT COUNT(*) INTO v_elig FROM orders o
             WHERE o.order_status IN ('D','X','R') AND o.created_at < v_cut
               AND NOT EXISTS (SELECT 1 FROM archived_orders a WHERE a.order_id = o.order_id);
        ELSIF r.entity_name = 'user_notifications' THEN
            SELECT COUNT(*) INTO v_elig FROM user_notifications WHERE created_at < v_cut;
        ELSIF r.entity_name IN ('audit_logs','error_logs','login_history','search_logs','user_activity_logs','page_views') THEN
            EXECUTE format('SELECT COUNT(*) FROM %I WHERE %I < $1', r.entity_name,
                           CASE r.entity_name WHEN 'audit_logs' THEN 'changed_at' ELSE 'created_at' END)
               INTO v_elig USING v_cut;
        ELSE
            RAISE NOTICE 'No archive routine for "%": policy skipped', r.entity_name;
            CONTINUE;
        END IF;

        IF NOT p_dry_run AND v_elig > 0 THEN
            INSERT INTO archive_runs (entity_name, action, cutoff_at) VALUES (r.entity_name, 'ARCHIVE', v_cut) RETURNING archive_run_id INTO v_run;
            LOOP
                v_n := CASE r.entity_name
                           WHEN 'orders'             THEN fn_archive_orders(v_cut, v_batch)
                           WHEN 'user_notifications' THEN fn_archive_notifications(v_cut, v_batch)
                           ELSE fn_archive_logs(r.entity_name, v_cut, v_batch) END;
                v_total := v_total + v_n;
                EXIT WHEN v_n < v_batch;
            END LOOP;
            UPDATE archive_runs SET rows_affected = v_total, finished_at = CURRENT_TIMESTAMP WHERE archive_run_id = v_run;
        END IF;

        entity_name := r.entity_name; cutoff_at := v_cut; eligible_rows := v_elig; archived_rows := v_total;
        RETURN NEXT;
    END LOOP;
END;
$$;

-- Destroys ARCHIVED rows older than retention_period. DRY RUN BY DEFAULT.
CREATE OR REPLACE FUNCTION fn_purge_expired_archives(p_dry_run BOOLEAN DEFAULT TRUE)
RETURNS TABLE (archive_table TEXT, source_entity TEXT, expired_rows BIGINT)
LANGUAGE plpgsql AS $$
DECLARE
    r       RECORD;
    v_cut   TIMESTAMP;
    v_cnt   BIGINT;
BEGIN
    FOR r IN SELECT * FROM data_retention_policies WHERE is_active ORDER BY policy_id LOOP
        v_cut := CURRENT_TIMESTAMP - make_interval(days => r.retention_period);
        IF r.entity_name = 'orders' THEN
            SELECT COUNT(*) INTO v_cnt FROM archived_orders WHERE ordered_at < v_cut;
            IF NOT p_dry_run AND v_cnt > 0 THEN DELETE FROM archived_orders WHERE ordered_at < v_cut; END IF;
            archive_table := 'archived_orders';
        ELSIF r.entity_name = 'user_notifications' THEN
            SELECT COUNT(*) INTO v_cnt FROM archived_notifications WHERE notified_at < v_cut;
            IF NOT p_dry_run AND v_cnt > 0 THEN DELETE FROM archived_notifications WHERE notified_at < v_cut; END IF;
            archive_table := 'archived_notifications';
        ELSE
            SELECT COUNT(*) INTO v_cnt FROM archived_logs WHERE source_table = r.entity_name AND logged_at < v_cut;
            IF NOT p_dry_run AND v_cnt > 0 THEN DELETE FROM archived_logs WHERE source_table = r.entity_name AND logged_at < v_cut; END IF;
            archive_table := 'archived_logs';
        END IF;
        IF NOT p_dry_run AND v_cnt > 0 THEN
            INSERT INTO archive_runs (entity_name, action, cutoff_at, rows_affected, finished_at) VALUES (r.entity_name, 'PURGE', v_cut, v_cnt, CURRENT_TIMESTAMP);
        END IF;
        source_entity := r.entity_name; expired_rows := v_cnt;
        RETURN NEXT;
    END LOOP;
END;
$$;
