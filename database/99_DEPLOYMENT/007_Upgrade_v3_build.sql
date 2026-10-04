-- =====================================================================
-- RT CRACKERS | 99_DEPLOYMENT/007_Upgrade_v3_build.sql
-- Master script for upgrade V3 (psql). Run AFTER 001_Schema_build.sql + 002_Master_seed_data.sql + 006_Upgrade_v2_build.sql.
-- =====================================================================

-- Run from the database root folder:
--   psql "$DATABASE_URL" -f 99_DEPLOYMENT/007_Upgrade_v3_build.sql
-- (\i 21_UPGRADE_V3/000_Header_and_preflight.sql
\i 21_UPGRADE_V3/001_Schema_versions.sql
\i 21_UPGRADE_V3/002_U21_Business_Code_Standardization.sql
\i 21_UPGRADE_V3/003_U22_Master_Status_Tables.sql
\i 21_UPGRADE_V3/004_U23_Enum_Replacement_Strategy.sql
\i 21_UPGRADE_V3/005_U31_Reference_Data_Management.sql
\i 21_UPGRADE_V3/006_U24_Business_Rule_Centralization.sql
\i 21_UPGRADE_V3/007_U25_Country_Configuration.sql
\i 21_UPGRADE_V3/008_U26_Product_Classification_Framework.sql
\i 21_UPGRADE_V3/009_U38_Data_Classification.sql
\i 21_UPGRADE_V3/010_U27_Data_Retention_Policy.sql
\i 21_UPGRADE_V3/011_U28_Archive_Framework.sql
\i 21_UPGRADE_V3/012_U29_Search_Optimization.sql
\i 21_UPGRADE_V3/013_U30_Data_Quality_Framework.sql
\i 21_UPGRADE_V3/014_U32_Application_Configuration.sql
\i 21_UPGRADE_V3/015_U33_Security_Audit_Enhancement.sql
\i 21_UPGRADE_V3/016_U36_Document_Management.sql
\i 21_UPGRADE_V3/017_U37_System_Health_Monitoring.sql
\i 21_UPGRADE_V3/018_U34_Data_Ownership_Tracking.sql
\i 21_UPGRADE_V3/019_U35_Version_Control_For_Master_Data.sql
\i 21_UPGRADE_V3/020_U39_Index_Governance.sql
\i 21_UPGRADE_V3/021_U40_Database_Documentation_Table.sql
\i 21_UPGRADE_V3/022_Finalize.sql
\i 21_UPGRADE_V3/023_Verification.sql

COMMIT;
