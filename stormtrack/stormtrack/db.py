"""SQLite storage for stormtrack.

The database lives at ~/.stormtrack/stormtrack.db (override with the
STORMTRACK_DB environment variable). Schema changes go through MIGRATIONS:
append a new list of SQL statements and the next run upgrades in place.
"""

import os
import sqlite3
from pathlib import Path

# Pipeline order matters: index position defines stage progression.
PIPELINE = [
    "knocked",
    "inspected",
    "claim-filed",
    "adjuster-scheduled",
    "adjuster-met",
    "approved",
    "contract-signed",
    "build-scheduled",
    "built",
    "closed",
]
TERMINAL = ["dead", "denied"]
ALL_STATUSES = PIPELINE + TERMINAL

SOURCES = ["knock", "referral", "sign-call", "canvass"]
TOUCH_TYPES = ["call", "text", "door", "email", "adjuster-meeting", "status-change", "note"]

# Days a lead may sit untouched in a status before `followups` flags it.
# 0 means same-day: flag it if it hasn't been touched today.
FOLLOWUP_THRESHOLDS = {
    "knocked": 2,
    "inspected": 1,
    "claim-filed": 3,
    "adjuster-scheduled": 0,
    "adjuster-met": 1,
    "approved": 1,
    "contract-signed": 5,
    "build-scheduled": 7,
}

MIGRATIONS = [
    # v1 — initial schema
    [
        """CREATE TABLE leads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            address TEXT DEFAULT '',
            phone TEXT DEFAULT '',
            email TEXT DEFAULT '',
            storm_date DATE,
            carrier TEXT DEFAULT '',
            claim_number TEXT DEFAULT '',
            deductible REAL,
            estimated_value REAL,
            status TEXT NOT NULL DEFAULT 'knocked',
            source TEXT DEFAULT 'knock',
            dead_reason TEXT DEFAULT '',
            notes TEXT DEFAULT '',
            created_at TIMESTAMP NOT NULL,
            last_touch TIMESTAMP NOT NULL
        )""",
        """CREATE TABLE touches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lead_id INTEGER NOT NULL REFERENCES leads(id),
            touch_type TEXT NOT NULL,
            note TEXT DEFAULT '',
            timestamp TIMESTAMP NOT NULL
        )""",
        "CREATE INDEX idx_touches_lead ON touches(lead_id)",
        "CREATE INDEX idx_leads_status ON leads(status)",
    ],
]


def db_path() -> Path:
    return Path(os.environ.get("STORMTRACK_DB", "~/.stormtrack/stormtrack.db")).expanduser()


def connect() -> sqlite3.Connection:
    path = db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    migrate(conn)
    return conn


def migrate(conn: sqlite3.Connection) -> None:
    conn.execute(
        "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)"
    )
    row = conn.execute("SELECT version FROM schema_version").fetchone()
    current = row["version"] if row else 0
    for version, statements in enumerate(MIGRATIONS, start=1):
        if version <= current:
            continue
        for sql in statements:
            conn.execute(sql)
        current = version
    if row is None:
        conn.execute("INSERT INTO schema_version (version) VALUES (?)", (current,))
    else:
        conn.execute("UPDATE schema_version SET version = ?", (current,))
    conn.commit()
