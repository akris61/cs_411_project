# Stage 4 — Advanced database programs

This document matches the SQL shipped in `sql/stage4_advanced.sql` and the transaction logic implemented in `app.py` (raw PyMySQL, no ORM).

---

## 1. Transaction (multi-step, explicit commit/rollback)

### What it does for the app

An analyst can **re-attach** a dashboard to the set of regions whose **average Renewables** observations between **2010-01-01** and **2019-01-01** are **above the global average** for the same window. The dashboard’s `updated_at` timestamp is refreshed so the UI (or future features) can tell the dashboard was rebuilt.

### Flask route

- **URL:** `POST /stage4/transaction-attach-hot-regions`
- **Form field:** `dashboard_id` (integer, must exist in `dashboards`)
- **Implementation:** `stage4_transaction_attach_hot_regions()` in `app.py`

### SQL pattern (same statements as in code)

Isolation level is set for the **session**, then a transaction begins. On any error, the connection rolls back.

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;

-- Lock the dashboard row (InnoDB) while we replace links
SELECT dashboard_id FROM dashboards WHERE dashboard_id = ? FOR UPDATE;

DELETE FROM dashboard_regions WHERE dashboard_id = ?;

INSERT INTO dashboard_regions (dashboard_id, region_id)
SELECT ? AS dashboard_id, inner_q.region_id
FROM (
    SELECT o.region_id
    FROM observations AS o
    INNER JOIN indicators AS i ON i.indicator_id = o.indicator_id
    WHERE i.category = 'Renewables'
      AND o.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
    GROUP BY o.region_id
    HAVING AVG(o.value) > (
        SELECT AVG(o2.value)
        FROM observations AS o2
        INNER JOIN indicators AS i2 ON i2.indicator_id = o2.indicator_id
        WHERE i2.category = 'Renewables'
          AND o2.obs_date BETWEEN '2010-01-01' AND '2019-01-01'
    )
) AS inner_q;

UPDATE dashboards
SET updated_at = CURRENT_TIMESTAMP
WHERE dashboard_id = ?;

COMMIT;
```

### Advanced concepts used

- **Join** across `observations` and `indicators`
- **Aggregation** with `GROUP BY` and `HAVING`
- **Subquery** comparing each region’s average to a **global** average (not a trivial join replacement)

---

## 2. Stored procedure

### What it does for the app

Given a **region `code`** (e.g. `GERMANY`), returns indicator-level totals for that region **only when** the region’s average for that indicator beats the **global average** for the same indicator across **2005–2019** — useful to spot where a country outperforms the world on specific metrics.

### Flask route

- **URL:** `POST /stage4/run-procedure-region-totals`
- **Form field:** `region_code`
- **Implementation:** `stage4_run_procedure_region_totals()` in `app.py` using `CALL sp_stage4_region_category_totals(%s)`

### SQL source

Full `CREATE PROCEDURE` body is in `sql/stage4_advanced.sql` (`sp_stage4_region_category_totals`). It uses:

- **Joins** (`observations` ↔ `regions` ↔ `indicators`)
- **`GROUP BY`** with aggregates
- **Correlated subquery** in `HAVING` comparing to `AVG(o2.value)` over all regions for the same `indicator_id`

---

## 3. Trigger

### What it does for the app

Whenever an existing **region** row is **updated** and any of `code`, `name`, or `country` actually change, a row is inserted into **`stage4_audit_log`** using a **`BEGIN` / `IF` / `END IF`** block in the trigger. That gives a lightweight **audit trail** for manual edits from the CRUD form.

### How the frontend causes it

- **URL:** `POST /regions/update`
- Changing `name`, `country`, or `code` through the form runs an `UPDATE` on `regions`, which fires the trigger.

### SQL source

`CREATE TRIGGER trg_stage4_regions_audit_update ... AFTER UPDATE ON regions` in `sql/stage4_advanced.sql` uses **`BEGIN` … `IF` … `THEN` … `INSERT` … `END IF` … `END`** and **does not** ship `DELIMITER` lines (run the script from **Workbench** or set a delimiter yourself in the `mysql` client; plain `mysql < file.sql` usually breaks on the inner semicolons).

### Viewing results

The home page section **Audit log** runs `SELECT ... FROM stage4_audit_log ORDER BY audit_id DESC LIMIT 25` (see `load_regions_audit()` / `SQL_AUDIT` in `app.py`).

---

## 4. Constraints

- **Existing:** Primary keys, foreign keys, and `UNIQUE` constraints from `sql/schema.sql` are unchanged.
- **Stage 4 SQL file:** does not add new `CHECK` constraints (no extra rules on `latitude` / `longitude` beyond the base schema).

---

## Appendix — verbatim trigger & procedure (from `sql/stage4_advanced.sql`)

Copy from `sql/stage4_advanced.sql` or use:

### Trigger `trg_stage4_regions_audit_update`

```sql
DROP TRIGGER IF EXISTS trg_stage4_regions_audit_update;

CREATE TRIGGER trg_stage4_regions_audit_update
AFTER UPDATE ON regions
FOR EACH ROW
BEGIN
    IF NOT (OLD.name <=> NEW.name)
        OR NOT (OLD.code <=> NEW.code)
        OR NOT (OLD.country <=> NEW.country) THEN
        INSERT INTO stage4_audit_log (table_name, row_pk, action, detail)
        VALUES (
            'regions',
            CAST(NEW.region_id AS CHAR),
            'UPDATE',
            CONCAT('code=', NEW.code, '; name=', NEW.name)
        );
    END IF;
END;
```

### Procedure `sp_stage4_region_category_totals`

```sql
DROP PROCEDURE IF EXISTS sp_stage4_region_category_totals;

CREATE PROCEDURE sp_stage4_region_category_totals(IN p_region_code VARCHAR(64))
SELECT
    i.category,
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
```

---

## Quick route index

| Feature | Method | Route |
|---------|--------|--------|
| Saved queries | POST | `/run-saved-query` |
| Region create | POST | `/regions/create` |
| Region update (fires trigger) | POST | `/regions/update` |
| Region delete | POST | `/regions/delete` |
| Keyword search | POST | `/search/keywords` |
| Transaction | POST | `/stage4/transaction-attach-hot-regions` |
| Stored procedure | POST | `/stage4/run-procedure-region-totals` |
| Home (lists regions + audit) | GET | `/` |
