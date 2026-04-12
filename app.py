"""
Minimal CS 411 checkpoint web app: Flask + MySQL reads queries from sql/queries.sql.
Run from repo root after loading schema and data (see sql/load_data.sql).
"""

import os
from pathlib import Path

from dotenv import load_dotenv
import pymysql
from flask import Flask, render_template, request
from pymysql.cursors import DictCursor

# Load .env from the folder that contains app.py (not the shell's current directory).
_BASE_DIR = Path(__file__).resolve().parent
load_dotenv(_BASE_DIR / ".env")

app = Flask(__name__)


def load_queries_from_sql_file():
    """Pull Query 1 / 2 / 3 bodies from sql/queries.sql (same file used in the course work)."""
    sql_path = Path(__file__).resolve().parent / "sql" / "queries.sql"
    text = sql_path.read_text(encoding="utf-8")
    queries = []
    for n in range(1, 4):
        marker = f"-- Query {n}"
        start = text.find(marker)
        if start == -1:
            raise FileNotFoundError(f"Could not find {marker} in {sql_path}")
        start = text.find("\n", start)
        if start == -1:
            raise ValueError(f"Malformed queries file after {marker}")
        start += 1
        if n < 3:
            next_marker = f"-- Query {n + 1}"
            end = text.find(next_marker, start)
            if end == -1:
                raise ValueError(f"Could not find {next_marker} after {marker}")
        else:
            end = len(text)
        body = text[start:end].strip().rstrip(";")
        queries.append(body)
    return queries


QUERIES = load_queries_from_sql_file()

QUERY_LABELS = [
    "Query 1 — Countries above global renewable average (top 15)",
    "Query 2 — Energy Watchlist (Top 15)",
    "Query 3 — CO2 above long-run average per country (top 15)",
]


def open_db():
    host = os.environ.get("MYSQL_HOST", "127.0.0.1")
    port = int(os.environ.get("MYSQL_PORT", "3306"))
    user = os.environ.get("MYSQL_USER", "root")
    password = os.environ.get("MYSQL_PASSWORD", "")
    database = os.environ.get("MYSQL_DATABASE", "renewable_energy_dashboard")
    return pymysql.connect(
        host=host,
        port=port,
        user=user,
        password=password,
        database=database,
        charset="utf8mb4",
        cursorclass=DictCursor,
    )


@app.route("/", methods=["GET", "POST"])
def home():
    choice = "1"
    rows = []
    columns = []
    error_message = None

    if request.method == "POST":
        choice = request.form.get("query_choice", "1")
        idx = int(choice) - 1
        if idx < 0 or idx >= len(QUERIES):
            error_message = "Invalid query choice."
        else:
            sql = QUERIES[idx]
            conn = None
            try:
                conn = open_db()
                with conn.cursor() as cur:
                    cur.execute(sql)
                    columns = [d[0] for d in cur.description]
                    rows = cur.fetchall()
            except Exception as exc:
                error_message = str(exc)
            finally:
                if conn is not None:
                    conn.close()

    return render_template(
        "index.html",
        query_labels=QUERY_LABELS,
        choice=choice,
        rows=rows,
        columns=columns,
        error_message=error_message,
    )


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
