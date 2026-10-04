-- RT CRACKERS | 21_UPGRADE_V3/016_U36_Document_Management.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 36 - DOCUMENT MANAGEMENT
-- Manuals, safety data sheets, licences and certificates. The file itself lives in storage
-- (Supabase Storage / S3); the database keeps the metadata and what each document is attached to.
-- document_links is polymorphic: entity_name is a table name, entity_id its primary key as text.
-- =====================================================================
CREATE TABLE document_types (
    document_type_id   SMALLINT      GENERATED ALWAYS AS IDENTITY,
    type_code          VARCHAR(30)   NOT NULL,
    type_name          VARCHAR(80)   NOT NULL,
    description        VARCHAR(255),
    requires_expiry    BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_document_types PRIMARY KEY (document_type_id),
    CONSTRAINT uq_document_types_code UNIQUE (type_code),
    CONSTRAINT uq_document_types_name UNIQUE (type_name),
    CONSTRAINT ck_document_types_code CHECK (type_code = UPPER(type_code))
);
INSERT INTO document_types (type_code, type_name, description, requires_expiry) VALUES
    ('USER_MANUAL',        'User manual',             'How to use a product',                         FALSE),
    ('SAFETY_DATA_SHEET',  'Safety data sheet',       'Handling, storage and fire-safety information', FALSE),
    ('PESO_LICENCE',       'PESO licence',            'Explosives licence for manufacture, storage or sale', TRUE),
    ('TEST_CERTIFICATE',   'Test certificate',        'Laboratory or batch test report',              TRUE),
    ('COMPLIANCE_CERT',    'Compliance certificate',  'Statutory or quality certification',           TRUE),
    ('PRODUCT_BROCHURE',   'Product brochure',        'Marketing material',                           FALSE),
    ('LEGAL_POLICY',       'Legal policy',            'Terms, privacy, returns policy',               FALSE),
    ('OTHER',              'Other',                   'Anything else',                                FALSE);

CREATE TABLE documents (
    document_id        BIGINT        GENERATED ALWAYS AS IDENTITY,
    document_number    VARCHAR(20)   NOT NULL DEFAULT fn_next_business_code('DOCUMENT'),
    document_type_id   SMALLINT      NOT NULL,
    classification_id  SMALLINT,
    title              VARCHAR(200)  NOT NULL,
    description        TEXT,
    file_url           VARCHAR(500)  NOT NULL,
    file_name          VARCHAR(255),
    mime_type          VARCHAR(100),
    file_size_bytes    BIGINT,
    checksum_sha256    CHAR(64),
    version_label      VARCHAR(20)   NOT NULL DEFAULT '1.0',
    issued_by          VARCHAR(150),
    issue_date         DATE,
    expiry_date        DATE,
    is_public          BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE,
    uploaded_by        BIGINT,
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_documents PRIMARY KEY (document_id),
    CONSTRAINT uq_documents_number UNIQUE (document_number),
    CONSTRAINT fk_documents_type           FOREIGN KEY (document_type_id)  REFERENCES document_types (document_type_id)       ON DELETE RESTRICT,
    CONSTRAINT fk_documents_classification FOREIGN KEY (classification_id) REFERENCES data_classification (classification_id) ON DELETE RESTRICT,
    CONSTRAINT fk_documents_uploaded_by    FOREIGN KEY (uploaded_by)       REFERENCES users (user_id)                          ON DELETE SET NULL,
    CONSTRAINT ck_documents_number   CHECK (document_number ~ '^DOC[0-9]{8}$'),
    CONSTRAINT ck_documents_file_url CHECK (file_url ~* '^(https?://|/|[a-z0-9_-]+/)'),
    CONSTRAINT ck_documents_size     CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0),
    CONSTRAINT ck_documents_checksum CHECK (checksum_sha256 IS NULL OR checksum_sha256 ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ck_documents_dates    CHECK (issue_date IS NULL OR expiry_date IS NULL OR expiry_date >= issue_date)
);
CREATE INDEX idx_documents_type        ON documents (document_type_id);
CREATE INDEX idx_documents_expiry      ON documents (expiry_date) WHERE expiry_date IS NOT NULL AND is_active;
CREATE INDEX idx_documents_uploaded_by ON documents (uploaded_by) WHERE uploaded_by IS NOT NULL;

CREATE TABLE document_links (
    document_link_id  BIGINT       GENERATED ALWAYS AS IDENTITY,
    document_id       BIGINT       NOT NULL,
    entity_name       VARCHAR(63)  NOT NULL,
    entity_id         VARCHAR(64)  NOT NULL,
    link_role         VARCHAR(30)  NOT NULL DEFAULT 'ATTACHMENT',
    display_order     SMALLINT     NOT NULL DEFAULT 0,
    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_document_links PRIMARY KEY (document_link_id),
    CONSTRAINT uq_document_links_target UNIQUE (document_id, entity_name, entity_id, link_role),
    CONSTRAINT fk_document_links_document FOREIGN KEY (document_id) REFERENCES documents (document_id) ON DELETE CASCADE,
    CONSTRAINT ck_document_links_role CHECK (link_role = UPPER(link_role))
);
CREATE INDEX idx_document_links_entity ON document_links (entity_name, entity_id);

CREATE OR REPLACE FUNCTION fn_document_link_check()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF to_regclass(format('public.%I', NEW.entity_name)) IS NULL THEN
        RAISE EXCEPTION 'document_links.entity_name "%" is not a table', NEW.entity_name USING ERRCODE = 'foreign_key_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_document_links_check BEFORE INSERT OR UPDATE OF entity_name ON document_links
    FOR EACH ROW EXECUTE FUNCTION fn_document_link_check();

-- licences / certificates that need an expiry date must carry one
CREATE OR REPLACE FUNCTION fn_document_expiry_check()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.expiry_date IS NULL AND EXISTS (SELECT 1 FROM document_types t WHERE t.document_type_id = NEW.document_type_id AND t.requires_expiry) THEN
        RAISE EXCEPTION 'This document type requires an expiry_date' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_documents_expiry_check BEFORE INSERT OR UPDATE OF document_type_id, expiry_date ON documents
    FOR EACH ROW EXECUTE FUNCTION fn_document_expiry_check();
