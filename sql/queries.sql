-- Advanced queries — Kaggle “Global Data on Sustainable Energy” (see sql/generated_kaggle_data.sql).
-- Uses joins, UNION, GROUP BY, and subqueries.

-- Query 1 — Countries above global renewable average (2010–2019)
SELECT 
    r.region_id,
    r.code,
    r.name,
    r.country,
    ROUND(AVG(o.value), 4) AS avg_renewables_metric,
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

-- Query 2 — High renewable TWH (2012–2019) OR many distinct metrics (2005–2015); UNION
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

-- Query 3 — CO2 above per-country long-run average (correlated subquery)
SELECT 
    o.observation_id,
    r.code AS region_code,
    i.code AS indicator_code,
    o.obs_date,
    o.value
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