-- Renewable Energy Dashboard — advanced queries (MySQL 8+)
-- Data: Kaggle “Global Data on Sustainable Energy” (+ optional GEC CSV) loaded via
--       scripts/build_stage3_data.py → sql/generated_kaggle_data.sql
-- Each query uses at least two of: joins, set operators, GROUP BY aggregation,
-- subqueries that are not a simple join rewrite.

-- =======================================================================================
-- Query 1 — Renewable-heavy regions vs global benchmark (2010–2019)
-- Description: For each region, averages all “Renewables” category
--   indicators with annual observations in 2010–2019, and keeps only countries
--   whose average is above the global average for that same slice.
-- Assignment concepts: joins (observations, regions, indicators); GROUP BY +
--   AVG/COUNT; scalar subquery in HAVING (benchmark not expressible as one extra join).
-- App usage: Leaderboard of countries outperforming the world on renewable metrics.
-- =======================================================================================
SELECT r.region_id, r.code, r.name, r.country, ROUND(AVG(o.value), 4) AS avg_renewables_metric, COUNT(*) AS num_points
FROM observations AS o
JOIN regions AS r ON r.region_id = o.region_id
JOIN indicators AS i ON i.indicator_id = o.indicator_id
WHERE i.category = 'Renewables' AND o.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
GROUP BY r.region_id, r.code, r.name, r.country
HAVING AVG(o.value) > (
    SELECT AVG(o2.value)
    FROM observations AS o2
    JOIN indicators AS i2 ON i2.indicator_id = o2.indicator_id
    WHERE i2.category = 'Renewables' AND o2.obs_date BETWEEN '2010-01-01' AND '2019-01-01')
ORDER BY avg_renewables_metric DESC
LIMIT 15;

-- =============================================================================
-- Query 2 — High renewable electricity or many distinct metrics
-- Description: Shows countries whose total “Electricity from renewables
--   (TWh)” across 2012–2019 exceeds a threshold in addition to countries with
--   at least 12 distinct indicator codes in 2005–2015 rich data coverage.
-- Assignment concepts: UNION; joins; GROUP BY with SUM and COUNT(DISTINCT).
-- App use: Countries to follow closely because of wither strong renewable power or 
--   wide range of reports.
-- =============================================================================
(
    SELECT r.code AS region_code, r.name AS region_name,'high_renewable_twh' AS cohort, ROUND(SUM(o.value), 2) AS metric_value
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    JOIN indicators AS i ON i.indicator_id = o.indicator_id
    WHERE i.code = 'ELEC_RENEW_TWH' 
    AND o.obs_date BETWEEN '2012-01-01' AND '2019-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING SUM(o.value) > 100)
UNION
(
    SELECT r.code, r.name, 'many_metrics', CAST(COUNT(DISTINCT o.indicator_id) AS DECIMAL(18, 2))
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    WHERE o.obs_date BETWEEN '2005-01-01' AND '2015-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING COUNT(DISTINCT o.indicator_id) >= 12)
ORDER BY cohort, metric_value DESC
LIMIT 15;

-- =============================================================================
-- Query 3 — Years a country’s emissions are greater than its long-run average
-- What it does: Rows where CO2 emissions (kt) for that country in that year is
--   greater than that country’s average CO2 over 2000–2015 (same indicator).
-- Assignment concepts: joins; correlated subquery in WHERE (inner references
--   outer region and compares to a per-country aggregate).
-- App use: Flag unusually high emission years for recent or historical emissions spikes.
-- =============================================================================
SELECT o.observation_id, r.code AS region_code, i.code AS indicator_code, o.obs_date, o.value
FROM observations AS o
JOIN regions AS r ON r.region_id = o.region_id
JOIN indicators AS i ON i.indicator_id = o.indicator_id
WHERE i.code = 'CO2_KT'
  AND o.obs_date BETWEEN '2000-01-01' AND '2019-01-01'
  AND o.value > (
        SELECT AVG(o2.value)
        FROM observations AS o2
        WHERE o2.region_id = o.region_id
        AND o2.indicator_id = o.indicator_id
        AND o2.obs_date BETWEEN '2000-01-01' AND '2015-01-01')
ORDER BY o.value DESC
LIMIT 15;