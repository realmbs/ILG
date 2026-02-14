#!/usr/bin/env python3
"""
Export scored leads to CSV.

Usage:
    python3 scripts/export-leads.py [vertical_id] [output_path]

If no vertical_id is given, exports all verticals.
If no output_path is given, exports to exports/leads_YYYYMMDD_HHMMSS.csv
"""

import sqlite3
import csv
import sys
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = PROJECT_ROOT / "db" / "ilg.db"
EXPORTS_DIR = PROJECT_ROOT / "exports"


def export_leads(vertical_id: str | None = None, output_path: str | None = None) -> None:
    if not DB_PATH.exists():
        print(f"ERROR: Database not found at {DB_PATH}")
        sys.exit(1)

    EXPORTS_DIR.mkdir(exist_ok=True)

    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row

    query = """
        SELECT
            ls.tier,
            ls.composite_score,
            c.first_name,
            c.last_name,
            c.title,
            c.email,
            c.linkedin_url,
            c.is_decision_maker,
            o.name AS org_name,
            o.website AS org_website,
            o.state,
            o.city,
            o.fit_score AS org_fit_score,
            ls.signal_score,
            ls.role_score,
            ls.org_fit_score AS score_org_fit,
            ls.scored_at
        FROM lead_scores ls
        JOIN contacts c ON ls.contact_id = c.id
        JOIN organizations o ON c.org_id = o.id
        WHERE 1=1
    """
    params: list = []

    if vertical_id:
        query += " AND ls.vertical_id = ?"
        params.append(vertical_id)

    query += " ORDER BY ls.composite_score DESC"

    rows = conn.execute(query, params).fetchall()

    if not rows:
        print("No scored leads found.")
        conn.close()
        return

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    suffix = f"_{vertical_id}" if vertical_id else ""
    out_path = Path(output_path) if output_path else EXPORTS_DIR / f"leads{suffix}_{timestamp}.csv"

    fieldnames = [
        "tier", "composite_score", "first_name", "last_name", "title",
        "email", "linkedin_url", "is_decision_maker", "org_name",
        "org_website", "state", "city", "org_fit_score",
        "signal_score", "role_score", "scored_at"
    ]

    with open(out_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row[k] for k in fieldnames})

    print(f"Exported {len(rows)} leads to {out_path}")
    conn.close()


if __name__ == "__main__":
    v_id = sys.argv[1] if len(sys.argv) > 1 else None
    o_path = sys.argv[2] if len(sys.argv) > 2 else None
    export_leads(v_id, o_path)
