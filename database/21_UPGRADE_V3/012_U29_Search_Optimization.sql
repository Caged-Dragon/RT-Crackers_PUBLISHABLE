-- RT CRACKERS | 21_UPGRADE_V3/012_U29_Search_Optimization.sql
-- Runs inside the transaction opened by 99_DEPLOYMENT/007_Upgrade_v3_build.sql

-- =====================================================================
-- UPGRADE 29 - SEARCH OPTIMIZATION
-- search_keywords  : extra words that should find a product or category
-- search_synonyms  : "patakha" also means "crackers"
-- search_redirects : a search term that sends the visitor to a fixed page
-- All terms are stored lower case with single spaces (trigger), so lookups are plain equality.
-- Search logs (U9) already exist: search_logs.
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_normalize_search_term(p_term TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT LOWER(BTRIM(regexp_replace(p_term, '\s+', ' ', 'g')))
$$;

CREATE OR REPLACE FUNCTION fn_search_terms_normalize()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_col TEXT;
BEGIN
    FOREACH v_col IN ARRAY TG_ARGV LOOP
        NEW := jsonb_populate_record(NEW, jsonb_build_object(v_col, fn_normalize_search_term(to_jsonb(NEW) ->> v_col)));
    END LOOP;
    RETURN NEW;
END;
$$;

CREATE TABLE search_keywords (
    keyword_id   BIGINT        GENERATED ALWAYS AS IDENTITY,
    keyword      VARCHAR(100)  NOT NULL,
    product_id   BIGINT,
    category_id  INTEGER,
    weight       SMALLINT      NOT NULL DEFAULT 1,
    is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_search_keywords PRIMARY KEY (keyword_id),
    CONSTRAINT fk_search_keywords_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)     ON DELETE CASCADE,
    CONSTRAINT fk_search_keywords_category FOREIGN KEY (category_id) REFERENCES categories (category_id) ON DELETE CASCADE,
    CONSTRAINT ck_search_keywords_target  CHECK ((product_id IS NOT NULL)::INT + (category_id IS NOT NULL)::INT = 1),
    CONSTRAINT ck_search_keywords_keyword CHECK (BTRIM(keyword) <> ''),
    CONSTRAINT ck_search_keywords_weight  CHECK (weight BETWEEN 1 AND 100)
);
CREATE UNIQUE INDEX uq_search_keywords_target ON search_keywords (keyword, COALESCE(product_id, 0), COALESCE(category_id, 0));
CREATE INDEX idx_search_keywords_keyword  ON search_keywords (keyword) WHERE is_active;
CREATE INDEX idx_search_keywords_product  ON search_keywords (product_id)  WHERE product_id  IS NOT NULL;
CREATE INDEX idx_search_keywords_category ON search_keywords (category_id) WHERE category_id IS NOT NULL;
CREATE TRIGGER trg_00_search_keywords_normalize BEFORE INSERT OR UPDATE ON search_keywords
    FOR EACH ROW EXECUTE FUNCTION fn_search_terms_normalize('keyword');

CREATE TABLE search_synonyms (
    synonym_id        INTEGER       GENERATED ALWAYS AS IDENTITY,
    term              VARCHAR(100)  NOT NULL,
    synonym           VARCHAR(100)  NOT NULL,
    is_bidirectional  BOOLEAN       NOT NULL DEFAULT TRUE,
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_search_synonyms PRIMARY KEY (synonym_id),
    CONSTRAINT uq_search_synonyms_pair UNIQUE (term, synonym),
    CONSTRAINT ck_search_synonyms_different CHECK (term <> synonym),
    CONSTRAINT ck_search_synonyms_blank     CHECK (BTRIM(term) <> '' AND BTRIM(synonym) <> '')
);
CREATE INDEX idx_search_synonyms_synonym ON search_synonyms (synonym) WHERE is_bidirectional;
CREATE TRIGGER trg_00_search_synonyms_normalize BEFORE INSERT OR UPDATE ON search_synonyms
    FOR EACH ROW EXECUTE FUNCTION fn_search_terms_normalize('term', 'synonym');
INSERT INTO search_synonyms (term, synonym) VALUES
    ('crackers',  'fireworks'),
    ('patakha',   'crackers'),
    ('phuljhari', 'sparklers'),
    ('anar',      'flower pot'),
    ('chakkar',   'ground chakkar'),
    ('bijli',     'lakshmi bomb'),
    ('rocket',    'sky shot');

CREATE TABLE search_redirects (
    redirect_id    INTEGER       GENERATED ALWAYS AS IDENTITY,
    search_term    VARCHAR(100)  NOT NULL,
    redirect_url   VARCHAR(500)  NOT NULL,
    valid_from     TIMESTAMP,
    valid_until    TIMESTAMP,
    is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_search_redirects PRIMARY KEY (redirect_id),
    CONSTRAINT uq_search_redirects_term UNIQUE (search_term),
    CONSTRAINT ck_search_redirects_url    CHECK (redirect_url ~* '^(https?://|/)'),
    CONSTRAINT ck_search_redirects_window CHECK (valid_from IS NULL OR valid_until IS NULL OR valid_until > valid_from)
);
CREATE TRIGGER trg_00_search_redirects_normalize BEFORE INSERT OR UPDATE ON search_redirects
    FOR EACH ROW EXECUTE FUNCTION fn_search_terms_normalize('search_term');

-- the term itself plus its synonyms (both directions where allowed)
CREATE OR REPLACE FUNCTION fn_search_expand(p_term TEXT)
RETURNS TABLE (term TEXT) LANGUAGE sql STABLE AS $$
    SELECT fn_normalize_search_term(p_term)
    UNION SELECT s.synonym FROM search_synonyms s WHERE s.is_active AND s.term = fn_normalize_search_term(p_term)
    UNION SELECT s.term    FROM search_synonyms s WHERE s.is_active AND s.is_bidirectional AND s.synonym = fn_normalize_search_term(p_term)
$$;
