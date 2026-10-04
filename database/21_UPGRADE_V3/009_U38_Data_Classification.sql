-- RT CRACKERS | 21_UPGRADE_V3/009_U38_Data_Classification.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 38 - DATA CLASSIFICATION
-- Four levels, plus a register that says which tables / columns sit at which level.
-- The register is pre-filled for every table at the end of this file; adjust it to your policy.
-- =====================================================================
CREATE TABLE data_classification (
    classification_id    SMALLINT      GENERATED ALWAYS AS IDENTITY,
    level_code           VARCHAR(15)   NOT NULL,
    sensitivity_rank     SMALLINT      NOT NULL,
    description          VARCHAR(255)  NOT NULL,
    handling_guidelines  TEXT,
    requires_encryption  BOOLEAN       NOT NULL DEFAULT FALSE,
    requires_masking     BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active            BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_data_classification PRIMARY KEY (classification_id),
    CONSTRAINT uq_data_classification_level UNIQUE (level_code),
    CONSTRAINT uq_data_classification_rank  UNIQUE (sensitivity_rank),
    CONSTRAINT ck_data_classification_level CHECK (level_code IN ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED')),
    CONSTRAINT ck_data_classification_rank  CHECK (sensitivity_rank BETWEEN 1 AND 4)
);
INSERT INTO data_classification (level_code, sensitivity_rank, description, handling_guidelines, requires_encryption, requires_masking) VALUES
    ('PUBLIC',       1, 'Safe to show to anyone (catalogue, banners, festival pages)', 'No restrictions.', FALSE, FALSE),
    ('INTERNAL',     2, 'Business data for staff and the application only',           'Not exposed through public APIs without a policy.', FALSE, FALSE),
    ('CONFIDENTIAL', 3, 'Personal or commercial data about customers or the business', 'Access on a need-to-know basis; mask in logs and exports.', FALSE, TRUE),
    ('RESTRICTED',   4, 'Secrets and credentials',                                    'Store hashed or encrypted only; never log, never export.', TRUE, TRUE);

CREATE TABLE data_classification_assignments (
    assignment_id      INTEGER       GENERATED ALWAYS AS IDENTITY,
    table_name         VARCHAR(63)   NOT NULL,
    column_name        VARCHAR(63),                           -- NULL = the table as a whole
    classification_id  SMALLINT      NOT NULL,
    rationale          VARCHAR(255),
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_data_classification_assignments PRIMARY KEY (assignment_id),
    CONSTRAINT fk_data_classification_assignments_level FOREIGN KEY (classification_id) REFERENCES data_classification (classification_id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX uq_data_classification_assignments_target ON data_classification_assignments (table_name, COALESCE(column_name, ''));
CREATE INDEX idx_data_classification_assignments_level ON data_classification_assignments (classification_id);
