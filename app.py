import os
from pathlib import Path

import pymysql
from pymysql.err import ProgrammingError
from dotenv import load_dotenv
from flask import Flask, flash, redirect, render_template, request, url_for

ROOT = Path(__file__).resolve().parent
load_dotenv(ROOT / ".env")

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "dev-change-me-for-production")

SQL_REGIONS = "SELECT region_id, code, name, country, latitude, longitude FROM regions ORDER BY region_id LIMIT 60"
SQL_AUDIT = "SELECT audit_id, table_name, row_pk, action, detail, created_at FROM stage4_audit_log ORDER BY audit_id DESC LIMIT 25"


def connect():
    return pymysql.connect(
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=os.getenv("MYSQL_USER", "root"),
        password=os.getenv("MYSQL_PASSWORD", ""),
        database=os.getenv("MYSQL_DATABASE", "renewable_energy_dashboard"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )


def q(sql, args=()):
    c = connect()
    try:
        with c.cursor() as cur:
            cur.execute(sql, args)
            return cur.fetchall()
    finally:
        c.close()


def x(sql, args=()):
    c = connect()
    try:
        with c.cursor() as cur:
            cur.execute(sql, args)
            n = cur.rowcount
        c.commit()
        return n
    except Exception:
        c.rollback()
        raise
    finally:
        c.close()


def load_saved_queries():
    text = (ROOT / "sql" / "queries.sql").read_text()
    out = []
    for chunk in text.split("\n-- Query ")[1:]:
        chunk = chunk.lstrip("\r")
        head, tail, body = chunk.partition("\n")
        n = ""
        for ch in head:
            if ch.isdigit():
                n = n + ch
            else:
                break
        rest = head[len(n) :].strip()
        while len(rest) > 0 and rest[0] in "-\u2014 ":
            rest = rest[1:].strip()
        out.append(("Query " + n + " — " + rest, body.strip()))
    return out


SAVED = load_saved_queries()


def load_regions_audit():
    try:
        r = q(SQL_REGIONS, ())
    except pymysql.Error as e:
        flash("Database error: " + str(e), "error")
        r = []
    try:
        a = q(SQL_AUDIT, ())
    except ProgrammingError:
        a = []
    return r, a


def page(title, rows):
    r, a = load_regions_audit()
    return render_template(
        "index.html",
        saved_queries=SAVED,
        regions=r,
        audit_log=a,
        result_title=title,
        result_rows=rows,
    )


@app.route("/", methods=["GET"])
def index():
    r, a = load_regions_audit()
    return render_template("index.html", saved_queries=SAVED, regions=r, audit_log=a)


@app.route("/run-saved-query", methods=["POST"])
def run_saved_query():
    try:
        i = int(request.form.get("query_index", "0"))
    except ValueError:
        flash("Bad query index.", "error")
        return redirect(url_for("index"))
    if i < 0 or i >= len(SAVED):
        flash("Bad query index.", "error")
        return redirect(url_for("index"))
    title, sql = SAVED[i]
    try:
        rows = q(sql, ())
    except pymysql.Error as e:
        flash("Query failed: " + str(e), "error")
        return redirect(url_for("index"))
    return page(title, rows)


@app.route("/regions/create", methods=["POST"])
def regions_create():
    code = (request.form.get("code") or "").strip()
    name = (request.form.get("name") or "").strip()
    country = (request.form.get("country") or "").strip()
    lat = request.form.get("latitude") or None
    lon = request.form.get("longitude") or None
    if not code or not name or not country:
        flash("Need code, name, country.", "error")
        return redirect(url_for("index"))
    try:
        x("INSERT INTO regions (code, name, country, latitude, longitude) VALUES (%s,%s,%s,%s,%s)", (code, name, country, lat, lon))
        flash("Created " + code, "success")
    except pymysql.Error as e:
        flash("Create failed: " + str(e), "error")
    return redirect(url_for("index"))


@app.route("/regions/update", methods=["POST"])
def regions_update():
    try:
        rid = int(request.form.get("region_id", ""))
    except ValueError:
        flash("Bad region_id.", "error")
        return redirect(url_for("index"))
    code = (request.form.get("code") or "").strip()
    name = (request.form.get("name") or "").strip()
    country = (request.form.get("country") or "").strip()
    lat = request.form.get("latitude") or None
    lon = request.form.get("longitude") or None
    if not code or not name or not country:
        flash("Need code, name, country.", "error")
        return redirect(url_for("index"))
    try:
        n = x(
            "UPDATE regions SET code=%s,name=%s,country=%s,latitude=%s,longitude=%s WHERE region_id=%s",
            (code, name, country, lat, lon, rid),
        )
        flash("Nothing updated." if n == 0 else "Updated.", "error" if n == 0 else "success")
    except pymysql.Error as e:
        flash("Update failed: " + str(e), "error")
    return redirect(url_for("index"))


@app.route("/regions/delete", methods=["POST"])
def regions_delete():
    try:
        rid = int(request.form.get("region_id", ""))
    except ValueError:
        flash("Bad region_id.", "error")
        return redirect(url_for("index"))
    try:
        n = x("DELETE FROM regions WHERE region_id=%s", (rid,))
        flash("Nothing deleted." if n == 0 else "Deleted.", "error" if n == 0 else "success")
    except pymysql.IntegrityError:
        flash("Still used by other rows.", "error")
    except pymysql.Error as e:
        flash("Delete failed: " + str(e), "error")
    return redirect(url_for("index"))


@app.route("/search/keywords", methods=["POST"])
def search_keywords():
    kw = (request.form.get("keyword") or "").strip()
    if not kw:
        flash("Enter a keyword.", "error")
        return redirect(url_for("index"))
    like = "%" + kw + "%"
    sr = "SELECT 'region' AS entity_type, CAST(region_id AS CHAR) AS entity_id, code AS label, CONCAT(name,', ',country) AS detail FROM regions WHERE name LIKE %s OR country LIKE %s OR code LIKE %s LIMIT 100"
    si = "SELECT 'indicator' AS entity_type, CAST(indicator_id AS CHAR) AS entity_id, code AS label, CONCAT(name,' [',unit,']') AS detail FROM indicators WHERE name LIKE %s OR code LIKE %s OR IFNULL(description,'') LIKE %s OR category LIKE %s LIMIT 100"
    try:
        rows = list(q(sr, (like, like, like))) + list(q(si, (like, like, like, like)))
        rows.sort(key=lambda row: (row["entity_type"], row["label"]))
        rows = rows[:200]
    except pymysql.Error as e:
        flash("Search failed: " + str(e), "error")
        return redirect(url_for("index"))
    return page('Search: "' + kw + '"', rows)


@app.route("/stage4/transaction-attach-hot-regions", methods=["POST"])
def stage4_transaction_attach_hot_regions():
    try:
        did = int(request.form.get("dashboard_id", ""))
    except ValueError:
        flash("Bad dashboard_id.", "error")
        return redirect(url_for("index"))
    lo, hi = "2010-01-01", "2019-01-01"
    ins = (
        "INSERT INTO dashboard_regions (dashboard_id, region_id) SELECT %s, t.region_id FROM ("
        "SELECT o.region_id FROM observations o JOIN indicators i ON i.indicator_id=o.indicator_id "
        "WHERE i.category='Renewables' AND o.obs_date BETWEEN %s AND %s GROUP BY o.region_id "
        "HAVING AVG(o.value)>(SELECT AVG(o2.value) FROM observations o2 JOIN indicators i2 ON i2.indicator_id=o2.indicator_id "
        "WHERE i2.category='Renewables' AND o2.obs_date BETWEEN %s AND %s)) t"
    )
    c = connect()
    try:
        with c.cursor() as cur:
            cur.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED")
            cur.execute("START TRANSACTION")
            cur.execute("SELECT dashboard_id FROM dashboards WHERE dashboard_id=%s FOR UPDATE", (did,))
            if not cur.fetchone():
                c.rollback()
                flash("No such dashboard.", "error")
                return redirect(url_for("index"))
            cur.execute("DELETE FROM dashboard_regions WHERE dashboard_id=%s", (did,))
            cur.execute(ins, (did, lo, hi, lo, hi))
            cur.execute("UPDATE dashboards SET updated_at=CURRENT_TIMESTAMP WHERE dashboard_id=%s", (did,))
            c.commit()
            flash("Transaction done.", "success")
    except pymysql.Error as e:
        c.rollback()
        flash("Rolled back: " + str(e), "error")
    finally:
        c.close()
    return redirect(url_for("index"))


@app.route("/stage4/run-procedure-region-totals", methods=["POST"])
def stage4_run_procedure_region_totals():
    code = (request.form.get("region_code") or "").strip()
    if not code:
        flash("Enter region_code.", "error")
        return redirect(url_for("index"))
    c = connect()
    try:
        with c.cursor() as cur:
            cur.execute("CALL sp_stage4_region_category_totals(%s)", (code,))
            rows = cur.fetchall()
            while cur.nextset():
                pass
        return page("Procedure: " + code, rows)
    except pymysql.Error as e:
        flash("Procedure failed: " + str(e), "error")
        return redirect(url_for("index"))
    finally:
        c.close()


if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)
