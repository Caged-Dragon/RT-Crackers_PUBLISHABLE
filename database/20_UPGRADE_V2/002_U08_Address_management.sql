-- =====================================================================
-- RT CRACKERS | 20_UPGRADE_V2/002_U08_Address_management.sql
-- Source: rt_crackers_upgrade_v2.sql (split by upgrade) | U8 Advanced address management (+ v_addresses_full, pincodes view)
-- Runs inside the transaction opened by 99_DEPLOYMENT/006_Upgrade_v2_build.sql
-- =====================================================================

-- =====================================================================
-- UPGRADE 8 - ADVANCED ADDRESS MANAGEMENT  (done here because the view below needs it)
-- latitude/longitude and landmark already existed.
-- =====================================================================
ALTER TABLE addresses
    ADD COLUMN delivery_instructions  VARCHAR(500),
    ADD COLUMN address_label          VARCHAR(10)  NOT NULL DEFAULT 'HOME',
    ADD COLUMN is_verified            BOOLEAN      NOT NULL DEFAULT FALSE,
    ADD COLUMN verification_date      TIMESTAMP,
    ADD COLUMN contact_person         VARCHAR(120),
    ADD COLUMN contact_phone          CHAR(10);

UPDATE addresses SET address_label = CASE address_type WHEN 'W' THEN 'OFFICE' WHEN 'O' THEN 'OTHER' ELSE 'HOME' END;
ALTER TABLE addresses DROP COLUMN address_type;     -- replaced by address_label (also drops ck_addresses_type)

ALTER TABLE addresses
    ADD CONSTRAINT ck_addresses_label        CHECK (address_label IN ('HOME','OFFICE','WAREHOUSE','OTHER')),
    ADD CONSTRAINT ck_addresses_verified     CHECK (is_verified = (verification_date IS NOT NULL)),
    ADD CONSTRAINT ck_addresses_contact_phone CHECK (contact_phone IS NULL OR contact_phone ~ '^[6-9][0-9]{9}$'),
    ADD CONSTRAINT ck_addresses_contact_person CHECK (contact_person IS NULL OR BTRIM(contact_person) <> ''),
    ADD CONSTRAINT ck_addresses_geo_pair     CHECK ((latitude IS NULL) = (longitude IS NULL));

CREATE INDEX idx_addresses_postal_code_id ON addresses (postal_code_id);

-- Same columns the old view exposed (address_type is computed from the new label), plus the new ones.
CREATE VIEW v_addresses_full WITH (security_invoker = true) AS
SELECT a.address_id, a.user_id, a.recipient_name, a.recipient_phone, a.house_no, a.street, a.area,
       a.landmark, ci.city_name AS city, d.district_name AS district, s.state_name AS state,
       co.country_code AS country, pc.postal_code,
       a.latitude, a.longitude,
       CASE a.address_label WHEN 'OFFICE' THEN 'W' WHEN 'HOME' THEN 'H' ELSE 'O' END::CHAR(1) AS address_type,
       a.address_label, a.delivery_instructions, a.is_verified, a.verification_date,
       a.contact_person, a.contact_phone,
       a.is_default, a.is_archived, a.created_at, a.updated_at,
       a.postal_code_id, ci.city_id, d.district_id, s.state_id, co.country_id
FROM addresses a
JOIN postal_codes pc ON pc.postal_code_id = a.postal_code_id
JOIN cities ci       ON ci.city_id        = pc.city_id
JOIN districts d     ON d.district_id     = ci.district_id
JOIN states s        ON s.state_id        = d.state_id
JOIN countries co    ON co.country_id     = s.country_id;

-- Read-only compatibility view for code that still reads the old pincodes table.
CREATE VIEW pincodes WITH (security_invoker = true) AS
SELECT pc.postal_code AS pincode, d.district_name AS district, s.state_name AS state,
       co.country_code, pc.zone_id, pc.is_serviceable, pc.cod_available, pc.created_at, pc.updated_at
FROM postal_codes pc
JOIN cities ci    ON ci.city_id    = pc.city_id
JOIN districts d  ON d.district_id = ci.district_id
JOIN states s     ON s.state_id    = d.state_id
JOIN countries co ON co.country_id = s.country_id;

CREATE INDEX idx_states_country_id        ON states (country_id);
CREATE INDEX idx_districts_state_id       ON districts (state_id);
CREATE INDEX idx_cities_district_id       ON cities (district_id);
CREATE INDEX idx_postal_codes_city_id     ON postal_codes (city_id);
CREATE INDEX idx_postal_codes_zone_id     ON postal_codes (zone_id);

