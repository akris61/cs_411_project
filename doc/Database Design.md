# Database Design — Renewable Energy Dashboard (CS 411 Stage 3)

**Team:** Team 94 HOA  
**Course / Term:** CS 411, Spring 2026  
**DBMS:** MySQL 8.x (local)  
**Primary Data:** Kaggle — *Global Data on Sustainable Energy*

---

## Step 1 — Dataset Choice and Why We Chose It

For this project, we looked at two datasets: **Global Data on Sustainable Energy** and **Global Energy Consumption**. After comparing both, we decided to use **Global Data on Sustainable Energy** as our main dataset because it fit our schema better and had more useful attributes for advanced queries.

| Criterion | Global Data on Sustainable Energy | Global Energy Consumption |
|-----------|----------------------------------|----------------------------|
| Fit to schema | Strong fit because it has one row per country and year with many numeric columns. This maps well to our `regions`, `indicators`, and `observations` tables. | Weaker fit because it has fewer columns and no location data. |
| Ease of import | Required reshaping from wide format into long-form observations. | Easier structure but had some possible duplicate `(Country, Year)` rows. |
| Row volume | Around 3.6k rows with many metrics, which becomes tens of thousands of rows after transformation. | Around 10k rows but fewer useful metrics. |
| Query support | Includes renewable share, electricity generation, CO₂ emissions, GDP, and access to electricity, which helped with advanced queries. | Useful as a secondary source but not enough by itself. |

We decided to use **Global Data on Sustainable Energy** as the primary dataset. We also included matching rows from the second dataset when country names lined up, such as `USA` and `United States`.

---

## Step 2 — Data Source and Processing

The main load file for our project is `sql/generated_kaggle_data.sql`.

The original CSV from Kaggle includes columns like `Entity`, `Year`, several renewable energy and emissions metrics, and `Latitude` / `Longitude`.

Before loading the data into MySQL, we converted the wide CSV format into the relational structure used by our database. This mainly involved separating the data into `indicators` and `observations`.

Some example indicator codes used in our database are:
- `ELEC_RENEW_TWH`
- `CO2_KT`
- `RENEW_SHARE_TFEC_PCT`

We also included some `GEC_*` metrics from the second dataset.

---

## Step 3 — How the CSV Maps to Our Tables

| Table | Description |
|------|-------------|
| `regions` | Stores country or region names, codes, and location coordinates |
| `indicators` | Stores each metric such as renewable electricity or CO₂ emissions |
| `observations` | Stores the actual values for each region, metric, and date |

For `regions`, we used the distinct `Entity` values from the dataset.

For `indicators`, each measurable metric became its own row with a short code.

For `observations`, each row stores one `(region, indicator, date)` value.

One small change we made was increasing `regions.code` to `VARCHAR(64)` so longer country names would still fit.

For the requirement of having **1000+ rows in at least three tables**, our database meets this with:
- `users`
- `observations`
- `dashboard_regions`

---

## Step 4 — Important Files in the Repo

| File | Purpose |
|------|---------|
| `sql/schema.sql` | Table creation commands |
| `sql/load_data.sql` | Order for loading schema and data |
| `sql/generated_kaggle_data.sql` | Bulk insert statements |
| `sql/queries.sql` | Advanced SQL queries |
| `sql/indexes.sql` | Indexing tests and `EXPLAIN ANALYZE` |
| `doc/Database Design.md` | This write-up |

---

## Step 5 — Advanced Queries Summary

We created three advanced SQL queries for the dashboard.

1. **Countries above the global renewable average**  
   Uses joins, `GROUP BY`, aggregation, and a subquery to find countries performing above the global average.

2. **Countries with strong renewable output or wide data coverage**  
   Uses `UNION`, joins, `GROUP BY`, `SUM`, and `COUNT(DISTINCT)`.

3. **CO₂ years above country average**  
   Uses joins and a correlated subquery to find years where CO₂ emissions are unusually high compared to that country’s own long-term average.

---

## Step 6 — Indexing Analysis

After loading the data, we tested different indexing designs using `EXPLAIN ANALYZE`.

For each query, we first ran a baseline test and then tried three different secondary indexes.

After each test, we dropped the index before trying the next one so that the results would be fair.

In the end, we selected the indexes that gave the best performance based on the query cost shown in `EXPLAIN ANALYZE`.

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
