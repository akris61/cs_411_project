# Database Design — Renewable Energy Dashboard (CS 411 Stage 3)

Team: Team 94 HOA
Course / term: CS 411, Spring 2026
DBMS: MySQL 8.x (local)
Primary data: Kaggle — Global Data on Sustainable Energy

---

## Step 1 — Which dataset we chose (and why)

| Criterion | Global Data on Sustainable Energy (anshtanwar) | Global Energy Consumption (atharvasoundankar) |
|-----------|-------------------------------------------------|---------------------------------------------------|
| Fit to schema | Strong: one row per country × year with many numeric columns → maps cleanly to regions + indicators + observations (unpivot). Includes latitude/longitude for regions. | Weaker: only nine columns, no coordinates; country names may not match the first dataset (e.g. USA vs United States). |
| Ease of import | Wide CSV was reshaped into long-form observations offline; we ship the result as sql/generated_kaggle_data.sql (MySQL-only load). | Easier structurally, but duplicate (Country, Year) rows can appear in the raw file if you re-import yourself. |
| Row volume | ~3.6k rows × ~15 metrics ⇒ tens of thousands of observations after unpivot. | ~10k rows; fewer metrics per row. |
| Advanced queries | Rich mix: renewables %, TWh by source, CO₂, GDP, access — good for GROUP BY, UNION cohorts, correlated “vs country average” queries. | Useful as a second source (we add GEC_* indicators) but not enough alone for a full dashboard story. |

Decision: Use Sustainable Energy as the primary dataset. Our checked-in generated_kaggle_data.sql also includes rows from Global Energy Consumption where country names matched (with aliases like USA → United States).

---

## Step 2 — Data provenance

Load path: sql/generated_kaggle_data.sql (no extra tools). Optional copies of the raw Kaggle CSVs may live under data/ for citation only (data/README.md).

Original wide CSV (Sustainable Energy): Entity, Year, many numeric metric columns, Latitude, Longitude. GEC CSV: Country, Year, consumption and share columns. Those were unpivoted into indicators + observations before we froze the bulk SQL file. Indicator codes in the database include e.g. ELEC_RENEW_TWH, CO2_KT, RENEW_SHARE_TFEC_PCT, and prefixed GEC_* metrics from the second dataset.

---

## Step 3 — Mapping CSV → relational schema

| Our table | Source |
|-----------|--------|
| regions | Distinct Entity; code = slug from name (≤64 chars); name/country = Entity; latitude/longitude from first row seen for that entity. |
| indicators | One row per metric; code short stable key (e.g. ELEC_RENEW_TWH); unit/category/description set in the bulk load to match Kaggle semantics. |
| observations | One row per (region, indicator, year-01-01) with non-null numeric value; data_source string identifies the CSV; recorded_by_user_id = NULL. |

Minimal schema change: regions.code widened to VARCHAR(64) so long country names still produce unique codes after slugging.

Stage 3 “1000+ rows in three tables”: After load, users (1200 synthetic), observations (very large), and dashboard_regions (≥1200 link rows) each exceed 1000 rows. regions stays ~176 (real countries) — that is OK because the assignment counts three tables, not every table.

---

## Step 4 — Repo files (DDL + SQL + report)

| Path | Role |
|------|------|
| sql/schema.sql | Full DDL (eight tables). |
| sql/load_data.sql | MySQL SOURCE order for schema + data. |
| sql/generated_kaggle_data.sql | Bulk INSERTs (~5 MB): users, regions, indicators, observations, dashboards, links. |
| sql/queries.sql | Three advanced queries aligned to loaded data. |
| sql/indexes.sql | EXPLAIN ANALYZE + index experiments. |
| doc/Database Design.md | This writeup. |


## Step 5 — Advanced queries (summary)

All three are in sql/queries.sql with header comments. They use:

1. Uses Joins, GROUP BY and HAVING — renewable-category countries above global average (2010–2019).
2. Uses UNION, joins, GROUP BY and SUM / COUNT(DISTINCT) — high cumulative renewable TWh vs many distinct metrics.
3. Joins and subquery — CO₂ years above that country’s long-run average on the same indicator.

---

## Step 6 — Indexing analysis (what to screenshot)

Run sections of sql/indexes.sql after data is loaded. For each of the three queries:

1. Capture baseline EXPLAIN ANALYZE (cost from plan).
2. Add three secondary indexes (not PK/unique), EXPLAIN ANALYZE after each, then DROP INDEX before the next design on the same table.
3. Write one paragraph per query comparing costs; explain tradeoffs (e.g. faster SELECT vs slower bulk load).


Suggested final indexes (team choice after measuring): We chose the indexes that resulted in the fastest query execution time for each of the 3 queries we tested. 

---

## Step 7 — Screenshot checklist (all images at bottom)

Files live under `doc/screenshots/` (paths below are relative to this markdown file). Captions below map each **Stage 3 checklist item** to the image file we checked in.

### Database implementation

1. **Database connection screenshot**

   Connection info (`connection.png` — local MySQL, database `renewable_energy_dashboard`):

   > ![Database connection](./screenshots/connection.png)

   `SHOW TABLES` in the same database (`show_tables.png`):

   > ![SHOW TABLES](./screenshots/show_tables.png)

2. **Count screenshot for Table 1 (≥1000 rows)**

   `users` — `COUNT(*)` = 1200 (`count_table1.png`):

   > ![COUNT users](./screenshots/count_table1.png)

3. **Count screenshot for Table 2 (≥1000 rows)**

   Same run as the checklist: one query returns per-table row counts; `observations` ≥ 1000 (`count_table2.png`). *Source:* multi-table aggregate screenshot (`count_all_tables.png`).

   > ![Row counts including observations](./screenshots/count_table2.png)

4. **Count screenshot for Table 3 (≥1000 rows)**

   Same run: e.g. `dashboard_regions` (and other large tables) ≥ 1000 (`count_table3.png`). *Source:* same file as item 3 — `count_all_tables.png`.

   > ![Row counts including dashboard_regions](./screenshots/count_table3.png)

   Full multi-table count output (for reference; `count_all_tables.png`):

   > ![All table row counts](./screenshots/count_all_tables.png)

### Advanced queries

5. **Advanced Query 1 — top 15 rows**

   > ![Advanced Query 1 — top 15 rows](./screenshots/query1_top15.png)

6. **Advanced Query 2 — top 15 rows**

   > ![Advanced Query 2 — top 15 rows](./screenshots/query2_top15.png)

7. **Advanced Query 3 — top 15 rows**

   > ![Advanced Query 3 — top 15 rows](./screenshots/query3_top15.png)

### Indexing analysis — Query 1

For each design we captured the `EXPLAIN ANALYZE` output and wrote a short paragraph explaining how the plan and timing changed.

8. **Query 1 — before adding new indexes**

   Baseline `EXPLAIN ANALYZE` (`q1_before.png` — label in terminal: `stage3_q1_before`):

   > ![Query 1 — baseline EXPLAIN ANALYZE](./screenshots/q1_before.png)

9. **Query 1 — Index Design 1**

   > ![Query 1 — Index Design 1](./screenshots/q1_design1.png)

10. **Query 1 — Index Design 2**

   > ![Query 1 — Index Design 2](./screenshots/q1_design2.png)

11. **Query 1 — Index Design 3**

   > ![Query 1 — Index Design 3](./screenshots/q1_design3.png)

### Indexing analysis — Query 2

12. **Query 2 — before adding new indexes**

   Baseline (`q2_before.png` — `stage3_q2_before`):

   > ![Query 2 — baseline EXPLAIN ANALYZE](./screenshots/q2_before.png)

13. **Query 2 — Index Design 1**

   (`q2_design1.png` — `stage3_q2_design1`):

   > ![Query 2 — Index Design 1](./screenshots/q2_design1.png)

14. **Query 2 — Index Design 2**

   (`q2_design2.png` — `stage3_q2_design2`):

   > ![Query 2 — Index Design 2](./screenshots/q2_design2.png)

15. **Query 2 — Index Design 3**

   (`q2_design3.png` — `stage3_q2_design3`):

   > ![Query 2 — Index Design 3](./screenshots/q2_design3.png)

### Indexing analysis — Query 3

16. **Query 3 — before adding new indexes**

   Baseline (`q3_before.png` — `stage3_q3_before`):

   > ![Query 3 — baseline EXPLAIN ANALYZE](./screenshots/q3_before.png)

17. **Query 3 — Index Design 1**

   (`q3_design1.png` — `stage3_q3_design1`):

   > ![Query 3 — Index Design 1](./screenshots/q3_design1.png)

18. **Query 3 — Index Design 2**

   (`q3_design2.png` — `stage3_q3_design2`):

   > ![Query 3 — Index Design 2](./screenshots/q3_design2.png)

19. **Query 3 — Index Design 3**

   (`q3_design3.png` — `stage3_q3_design3`):

   > ![Query 3 — Index Design 3](./screenshots/q3_design3.png)

### Extra COUNT(*) captures (not required for the three “≥1000 rows” slots)

These were included in the same screenshot batch; row counts are below 1000 for the rubric, but they document additional tables.

**`regions`** (`extra_count_regions.png`):

> ![COUNT regions](./screenshots/extra_count_regions.png)

**`indicators`** (`extra_count_indicators.png`):

> ![COUNT indicators](./screenshots/extra_count_indicators.png)
