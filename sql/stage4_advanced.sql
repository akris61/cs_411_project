CREATE TABLE IF NOT EXISTS stage4_audit_log (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    row_pk VARCHAR(64) NOT NULL,
    action VARCHAR(32) NOT NULL,
    detail VARCHAR(512) NULL
);

DROP TRIGGER IF EXISTS trg_stage4_regions_audit_update;

CREATE TRIGGER trg_stage4_regions_audit_update
AFTER UPDATE ON regions
FOR EACH ROW
BEGIN
    IF OLD.name IS DISTINCT FROM NEW.name
        OR OLD.code IS DISTINCT FROM NEW.code
        OR OLD.country IS DISTINCT FROM NEW.country THEN
        INSERT INTO stage4_audit_log (table_name, row_pk, action, detail)
        VALUES (
            'regions',
            NEW.region_id,
            'UPDATE',
            CONCAT('code=', NEW.code, '; name=', NEW.name)
        );
    END IF;
END;

DROP PROCEDURE IF EXISTS sp_stage4_region_category_totals;

CREATE PROCEDURE sp_stage4_region_category_totals(IN p_region_code VARCHAR(64))
SELECT
    i.category,
    i.indicator_id,
    i.code AS indicator_code,
    COUNT(*) AS obs_count,
    ROUND(SUM(o.value), 4) AS sum_value,
    ROUND(AVG(o.value), 6) AS avg_value
FROM observations AS o
INNER JOIN regions AS r ON r.region_id = o.region_id
INNER JOIN indicators AS i ON i.indicator_id = o.indicator_id
WHERE r.code = p_region_code
GROUP BY i.category, i.indicator_id, i.code
HAVING AVG(o.value) > (
    SELECT AVG(o2.value)
    FROM observations AS o2
    WHERE o2.indicator_id = i.indicator_id
      AND o2.obs_date BETWEEN '2005-01-01' AND '2019-01-01'
)
ORDER BY sum_value DESC
LIMIT 50;
