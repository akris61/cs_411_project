-- =============================================================================
-- Stage 3 data load — MySQL only
-- =============================================================================
-- Prerequisite: run schema.sql first on an empty database.
--
-- Workflow (repo root, mysql client):
--   CREATE DATABASE IF NOT EXISTS renewable_energy_dashboard
--     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
--   USE renewable_energy_dashboard;
--   SOURCE schema.sql;
--   SOURCE generated_kaggle_data.sql;
--
-- `generated_kaggle_data.sql` is large (~5 MB): bulk INSERTs for users, regions,
-- indicators, observations, dashboards, and link tables (from Kaggle-derived data).
-- =============================================================================

SELECT 'Run SOURCE schema.sql then SOURCE generated_kaggle_data.sql (see comments above).' AS instruction;
