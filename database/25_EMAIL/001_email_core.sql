-- RTC Crackers Mail
-- Additive schema only. Existing commerce/auth tables are not modified.
-- Apply after the supplied base database build.

CREATE TABLE IF NOT EXISTS mailboxes (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(160) NOT NULL,
    email VARCHAR(320) NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS emails (
    id BIGSERIAL PRIMARY KEY,
    resend_email_id VARCHAR(255),
    mailbox_id BIGINT NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
    from_address VARCHAR(320) NOT NULL,
    to_address TEXT,
    cc TEXT,
    bcc TEXT,
    reply_to VARCHAR(320),
    subject TEXT NOT NULL DEFAULT '',
    body_text TEXT,
    body_html TEXT,
    direction VARCHAR(20) NOT NULL CHECK (direction IN ('inbound','outbound','draft')),
    status VARCHAR(40) NOT NULL DEFAULT 'received',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    is_starred BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    message_id VARCHAR(512),
    in_reply_to VARCHAR(512),
    thread_id VARCHAR(255),
    resend_event_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mailboxes_active
    ON mailboxes(is_active);

CREATE INDEX IF NOT EXISTS idx_emails_mailbox_created
    ON emails(mailbox_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_emails_inbox
    ON emails(mailbox_id, direction, is_archived, is_deleted, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_emails_starred
    ON emails(mailbox_id, is_starred, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_emails_resend_id
    ON emails(resend_email_id);

CREATE INDEX IF NOT EXISTS idx_emails_thread
    ON emails(thread_id);

-- Safe upgrade for databases where the email tables were created by an
-- earlier revision of the supplied email module.
ALTER TABLE emails ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE emails ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE emails ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE OR REPLACE FUNCTION rtc_email_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_emails_touch_updated_at ON emails;
CREATE TRIGGER trg_emails_touch_updated_at
BEFORE UPDATE ON emails
FOR EACH ROW EXECUTE FUNCTION rtc_email_touch_updated_at();
