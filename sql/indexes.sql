-- Stage 3 index study: EXPLAIN ANALYZE vs baseline.
-- Baseline = sql/schema.sql + data only (PK, UNIQUE uq_*, FKs). No idx_stage3_*.
-- If a prior run left experimental indexes: SHOW INDEX ... LIKE 'idx_stage3_%'; then DROP them before baseline.


-- QUERY 1

-- Baseline
EXPLAIN ANALYZE
SELECT r.region_id, r.code, r.name, r.country, ROUND(AVG(o.value), 4) AS avg_renewables_metric,
    COUNT(*) AS num_points
FROM observations AS o
JOIN regions AS r ON r.region_id = o.region_id
JOIN indicators AS i ON i.indicator_id = o.indicator_id
WHERE i.category = 'Renewables'
  AND o.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
GROUP BY r.region_id, r.code, r.name, r.country
HAVING AVG(o.value) > (
    SELECT AVG(o2.value)
    FROM observations AS o2
    JOIN indicators AS i2 ON i2.indicator_id = o2.indicator_id
    WHERE i2.category = 'Renewables' AND o2.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
)
ORDER BY avg_renewables_metric DESC
LIMIT 15;

-- Design A: (indicator_id, obs_date)
CREATE INDEX idx_stage3_q1_a_obs_ind_date
    ON observations (indicator_id, obs_date);

EXPLAIN ANALYZE
SELECT r.region_id, r.code, r.name, r.country, ROUND(AVG(o.value), 4) AS avg_renewables_metric,
    COUNT(*) AS num_points
FROM observations AS o
JOIN regions AS r ON r.region_id = o.region_id
JOIN indicators AS i ON i.indicator_id = o.indicator_id
WHERE i.category = 'Renewables'
  AND o.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
GROUP BY r.region_id, r.code, r.name, r.country
HAVING AVG(o.value) > (
    SELECT AVG(o2.value)
    FROM observations AS o2
    JOIN indicators AS i2 ON i2.indicator_id = o2.indicator_id
    WHERE i2.category = 'Renewables' AND o2.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
)
ORDER BY avg_renewables_metric DESC
LIMIT 15;

DROP INDEX idx_stage3_q1_a_obs_ind_date ON observations;

-- Design B: (obs_date, indicator_id)
CREATE INDEX idx_stage3_q1_b_obs_date_ind
    ON observations (obs_date, indicator_id);

EXPLAIN ANALYZE
SELECT r.region_id, r.code, r.name, r.country, ROUND(AVG(o.value), 4) AS avg_renewables_metric,
    COUNT(*) AS num_points
FROM observations AS o
JOIN regions AS r ON r.region_id = o.region_id
JOIN indicators AS i ON i.indicator_id = o.indicator_id
WHERE i.category = 'Renewables'
  AND o.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
GROUP BY r.region_id, r.code, r.name, r.country
HAVING AVG(o.value) > (
    SELECT AVG(o2.value)
    FROM observations AS o2
    JOIN indicators AS i2 ON i2.indicator_id = o2.indicator_id
    WHERE i2.category = 'Renewables'
      AND o2.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
)
ORDER BY avg_renewables_metric DESC
LIMIT 15;

DROP INDEX idx_stage3_q1_b_obs_date_ind ON observations;

-- Design C: indicators (category, code)
CREATE INDEX idx_stage3_q1_c_ind_cat_code
    ON indicators (category, code);

EXPLAIN ANALYZE
SELECT r.region_id, r.code, r.name, r.country, ROUND(AVG(o.value), 4) AS avg_renewables_metric,
    COUNT(*) AS num_points
FROM observations AS o
JOIN regions AS r ON r.region_id = o.region_id
JOIN indicators AS i ON i.indicator_id = o.indicator_id
WHERE i.category = 'Renewables'
  AND o.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
GROUP BY r.region_id, r.code, r.name, r.country
HAVING AVG(o.value) > (
    SELECT AVG(o2.value)
    FROM observations AS o2
    JOIN indicators AS i2 ON i2.indicator_id = o2.indicator_id
    WHERE i2.category = 'Renewables'
      AND o2.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
)
ORDER BY avg_renewables_metric DESC
LIMIT 15;

DROP INDEX idx_stage3_q1_c_ind_cat_code ON indicators;


-- QUERY 2

-- Baseline
EXPLAIN ANALYZE
(
    SELECT
        r.code AS region_code,
        r.name AS region_name,
        'high_renewable_twh' AS cohort,
        ROUND(SUM(o.value), 2) AS metric_value
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    JOIN indicators AS i ON i.indicator_id = o.indicator_id
    WHERE i.code = 'ELEC_RENEW_TWH'
      AND o.obs_date BETWEEN '2012-01-01' AND '2019-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING SUM(o.value) > 100
)
UNION
(
    SELECT r.code, r.name, 'many_metrics', CAST(COUNT(DISTINCT o.indicator_id) AS DECIMAL(18, 2))
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    WHERE o.obs_date BETWEEN '2005-01-01' AND '2015-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING COUNT(DISTINCT o.indicator_id) >= 12
)
ORDER BY cohort, metric_value DESC
LIMIT 15;

-- Design A: (indicator_id, obs_date)
CREATE INDEX idx_stage3_q2_a_obs_ind_date
    ON observations (indicator_id, obs_date);

EXPLAIN ANALYZE
(
    SELECT r.code AS region_code, r.name AS region_name, 'high_renewable_twh' AS cohort, ROUND(SUM(o.value), 2) AS metric_value
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    JOIN indicators AS i ON i.indicator_id = o.indicator_id
    WHERE i.code = 'ELEC_RENEW_TWH'
      AND o.obs_date BETWEEN '2012-01-01' AND '2019-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING SUM(o.value) > 100
)
UNION
(
    SELECT
        r.code,
        r.name,
        'many_metrics',
        CAST(COUNT(DISTINCT o.indicator_id) AS DECIMAL(18, 2))
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    WHERE o.obs_date BETWEEN '2005-01-01' AND '2015-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING COUNT(DISTINCT o.indicator_id) >= 12
)
ORDER BY cohort, metric_value DESC
LIMIT 15;

DROP INDEX idx_stage3_q2_a_obs_ind_date ON observations;

-- Design B: (region_id, obs_date)
CREATE INDEX idx_stage3_q2_b_obs_reg_date
    ON observations (region_id, obs_date);

EXPLAIN ANALYZE
(
    SELECT
        r.code AS region_code,
        r.name AS region_name,
        'high_renewable_twh' AS cohort,
        ROUND(SUM(o.value), 2) AS metric_value
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    JOIN indicators AS i ON i.indicator_id = o.indicator_id
    WHERE i.code = 'ELEC_RENEW_TWH'
      AND o.obs_date BETWEEN '2012-01-01' AND '2019-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING SUM(o.value) > 100
)
UNION
(
    SELECT
        r.code,
        r.name,
        'many_metrics',
        CAST(COUNT(DISTINCT o.indicator_id) AS DECIMAL(18, 2))
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    WHERE o.obs_date BETWEEN '2005-01-01' AND '2015-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING COUNT(DISTINCT o.indicator_id) >= 12
)
ORDER BY cohort, metric_value DESC
LIMIT 15;

DROP INDEX idx_stage3_q2_b_obs_reg_date ON observations;

-- Design C: (obs_date, region_id) — column order swapped vs B
CREATE INDEX idx_stage3_q2_c_obs_date_reg
    ON observations (obs_date, region_id);

EXPLAIN ANALYZE
(
    SELECT
        r.code AS region_code,
        r.name AS region_name,
        'high_renewable_twh' AS cohort,
        ROUND(SUM(o.value), 2) AS metric_value
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    JOIN indicators AS i ON i.indicator_id = o.indicator_id
    WHERE i.code = 'ELEC_RENEW_TWH'
      AND o.obs_date BETWEEN '2012-01-01' AND '2019-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING SUM(o.value) > 100
)
UNION
(
    SELECT
        r.code,
        r.name,
        'many_metrics',
        CAST(COUNT(DISTINCT o.indicator_id) AS DECIMAL(18, 2))
    FROM observations AS o
    JOIN regions AS r ON r.region_id = o.region_id
    WHERE o.obs_date BETWEEN '2005-01-01' AND '2015-01-01'
    GROUP BY r.region_id, r.code, r.name
    HAVING COUNT(DISTINCT o.indicator_id) >= 12
)
ORDER BY cohort, metric_value DESC
LIMIT 15;

DROP INDEX idx_stage3_q2_c_obs_date_reg ON observations;


-- QUERY 3

-- Baseline
EXPLAIN ANALYZE
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
          AND o2.obs_date BETWEEN '2000-01-01' AND '2015-01-01'
    )
ORDER BY o.value DESC
LIMIT 15;

-- Design A: (region_id, indicator_id, obs_date)
CREATE INDEX idx_stage3_q3_a_obs_reg_ind_date
    ON observations (region_id, indicator_id, obs_date);

EXPLAIN ANALYZE
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
          AND o2.obs_date BETWEEN '2000-01-01' AND '2015-01-01'
    )
ORDER BY o.value DESC
LIMIT 15;

DROP INDEX idx_stage3_q3_a_obs_reg_ind_date ON observations;

-- Design B: (obs_date, region_id, indicator_id)
CREATE INDEX idx_stage3_q3_b_obs_date_reg_ind
    ON observations (obs_date, region_id, indicator_id);

EXPLAIN ANALYZE
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
          AND o2.obs_date BETWEEN '2000-01-01' AND '2015-01-01'
    )
ORDER BY o.value DESC
LIMIT 15;

DROP INDEX idx_stage3_q3_b_obs_date_reg_ind ON observations;

-- Design C: (indicator_id, region_id, obs_date)
CREATE INDEX idx_stage3_q3_c_obs_ind_reg_date
    ON observations (indicator_id, region_id, obs_date);

EXPLAIN ANALYZE
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
          AND o2.obs_date BETWEEN '2000-01-01' AND '2015-01-01'
    )
ORDER BY o.value DESC
LIMIT 15;

DROP INDEX idx_stage3_q3_c_obs_ind_reg_date ON observations;