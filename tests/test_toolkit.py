"""Smoke tests for the AQE roofing toolkit — run by the CI workflow."""

from datetime import date, timedelta
from pathlib import Path

import pytest

REPO = Path(__file__).parent.parent


# ---------------------------------------------------------------------------
# stormtrack

@pytest.fixture
def st_db(tmp_path, monkeypatch):
    monkeypatch.setenv("STORMTRACK_DB", str(tmp_path / "st.db"))


def test_parse_date_formats(st_db):
    from stormtrack.cli import parse_date

    assert parse_date("today") == date.today().isoformat()
    assert parse_date("yesterday") == (date.today() - timedelta(days=1)).isoformat()
    assert parse_date("2026-05-15") == "2026-05-15"
    assert parse_date("05/15") == f"{date.today().year}-05-15"


def test_pipeline_flow(st_db):
    from click.testing import CliRunner
    from stormtrack import db
    from stormtrack.cli import main

    runner = CliRunner()
    result = runner.invoke(main, ["add", "Jane Doe", "--address", "12 Elm St",
                                  "--carrier", "State Farm", "--value", "15000"])
    assert result.exit_code == 0, result.output

    result = runner.invoke(main, ["status", "1", "inspected"])
    assert result.exit_code == 0, result.output

    conn = db.connect()
    lead = conn.execute("SELECT * FROM leads WHERE id = 1").fetchone()
    assert lead["status"] == "inspected"
    # status change auto-logs a touch
    touches = conn.execute("SELECT * FROM touches WHERE lead_id = 1").fetchall()
    assert len(touches) == 1

    # dead requires a reason
    result = runner.invoke(main, ["status", "1", "dead"])
    assert result.exit_code != 0

    result = runner.invoke(main, ["demo"])
    assert result.exit_code == 0
    result = runner.invoke(main, ["followups"])
    assert result.exit_code == 0
    assert "Follow-ups needed" in result.output


def test_migration_bookkeeping(st_db):
    from stormtrack import db

    conn = db.connect()
    version = conn.execute("SELECT version FROM schema_version").fetchone()[0]
    assert version == len(db.MIGRATIONS)


# ---------------------------------------------------------------------------
# obj

@pytest.fixture
def kb(monkeypatch, tmp_path):
    monkeypatch.setenv("OBJ_KB_DIR", str(tmp_path / "objections"))


def test_seed_kb_parses(kb):
    from obj_cli.cli import load_all

    entries = load_all()
    assert len(entries) >= 30
    for e in entries:
        assert e.objection and e.response and e.tags, e.objection


def test_fuzzy_search_handles_typos(kb):
    from obj_cli.cli import load_all, score

    entries = load_all()
    best = max(entries, key=lambda e: score("deductable", e))
    assert "deductible" in (best.objection + " ".join(best.tags)).lower()


# ---------------------------------------------------------------------------
# inspecto

def test_terminology_single_pass():
    from inspecto.cli import upgrade_terminology

    out = upgrade_terminology("North slope: hail hits, 9+ per square with granule loss")
    assert "hail impact bruising with granular displacement" in out
    assert "impact impact" not in out
    assert "displacement with granular displacement" not in out


def test_scope_derivation():
    from inspecto.cli import derive_scope

    items = derive_scope(["hail bruising on north slope", "dented gutters"])
    joined = " ".join(items).lower()
    assert "replacement of affected slopes" in joined
    assert "gutters" in joined


def test_notes_parser(tmp_path):
    from inspecto.cli import parse_notes

    notes = tmp_path / "notes.txt"
    notes.write_text(
        "CLIENT: Jane Doe\nADDRESS: 12 Elm St\nDAMAGE:\n- hail hits\n"
        "PHOTOS:\nIMG_1.jpg: test square\n"
    )
    data = parse_notes(notes)
    assert data["client"] == "Jane Doe"
    assert data["damage"] == ["hail hits"]
    assert data["captions"]["img_1.jpg"] == "test square"


# ---------------------------------------------------------------------------
# adjprep

@pytest.fixture
def adjprep_home(monkeypatch, tmp_path):
    monkeypatch.setenv("ADJPREP_HOME", str(tmp_path / ".adjprep"))


def test_carrier_key():
    from adjprep.cli import carrier_key

    assert carrier_key("State Farm") == "state_farm"
    assert carrier_key("  Liberty-Mutual ") == "liberty_mutual"


def test_seed_carriers_load(adjprep_home):
    from adjprep.cli import load_carriers

    carriers = load_carriers()
    for key in ("state_farm", "allstate", "farmers", "usaa", "travelers", "liberty_mutual"):
        assert carriers[key]["known_pushback"], key
        assert carriers[key]["counter_strategy"], key


def test_learn_roundtrip(adjprep_home):
    from click.testing import CliRunner
    from adjprep.cli import cli, load_carriers

    runner = CliRunner()
    result = runner.invoke(cli, ["learn", "state_farm", "new pattern observed"])
    assert result.exit_code == 0, result.output
    assert "new pattern observed" in load_carriers()["state_farm"]["known_pushback"]
