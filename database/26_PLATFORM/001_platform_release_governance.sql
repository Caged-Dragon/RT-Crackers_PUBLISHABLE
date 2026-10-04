-- RTCrackers additive platform/release/content governance migration.
-- Does not drop, truncate, replace, or reset existing business tables.
BEGIN;

CREATE TABLE IF NOT EXISTS site_releases (
    release_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version VARCHAR(40) NOT NULL UNIQUE,
    name VARCHAR(160) NOT NULL DEFAULT 'RTCrackers update',
    message TEXT NOT NULL DEFAULT '',
    snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
      CHECK (status IN ('DRAFT','VERIFIED','PUBLISHED','SUPERSEDED','REJECTED')),
    created_by INTEGER,
    verified_at TIMESTAMP,
    published_at TIMESTAMP,
    verification_error TEXT,
    is_current BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_site_releases_current ON site_releases(is_current) WHERE is_current = TRUE;
CREATE INDEX IF NOT EXISTS ix_site_releases_status_published ON site_releases(status,published_at DESC);

CREATE TABLE IF NOT EXISTS site_content_revisions (
    revision_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    content_key VARCHAR(180) NOT NULL,
    page_path VARCHAR(240) NOT NULL DEFAULT '/',
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
      CHECK (status IN ('DRAFT','VERIFIED','PUBLISHED','SUPERSEDED','REJECTED')),
    release_id BIGINT REFERENCES site_releases(release_id) ON DELETE SET NULL,
    edited_by INTEGER,
    verified_at TIMESTAMP,
    published_at TIMESTAMP,
    verification_error TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_site_content_key_status ON site_content_revisions(content_key,status,published_at DESC);
CREATE INDEX IF NOT EXISTS ix_site_content_release ON site_content_revisions(release_id);

CREATE TABLE IF NOT EXISTS deployment_change_notifications (
    notification_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    release_id BIGINT REFERENCES site_releases(release_id) ON DELETE SET NULL,
    admin_id INTEGER,
    action VARCHAR(30) NOT NULL,
    result VARCHAR(20) NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_deployment_notifications_admin ON deployment_change_notifications(admin_id,created_at DESC);

-- Every release is a complete immutable snapshot. Public traffic only reads PUBLISHED/current.
-- Normal admins may edit content; existing RBAC remains authoritative.
COMMIT;
