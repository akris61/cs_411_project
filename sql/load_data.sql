-- Stage 3 data load (MySQL). Run sql/schema.sql on an empty database first.
--
-- Example (mysql client, repo root):
--   CREATE DATABASE IF NOT EXISTS renewable_energy_dashboard
--     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
--   USE renewable_energy_dashboard;
--   SOURCE sql/schema.sql;
--   SOURCE sql/generated_kaggle_data.sql;   -- large (~5 MB)

SELECT 'Run SOURCE sql/schema.sql then SOURCE sql/generated_kaggle_data.sql (see comments above).' AS instruction;