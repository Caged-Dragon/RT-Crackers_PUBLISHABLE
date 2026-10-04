-- =====================================================================
-- RT CRACKERS | 00_SETUP/003_Helper_functions.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;
