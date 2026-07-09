# CLAUDE.md

Guidance for AI assistants (Claude Code and others) working in this repository.

## What this repo is

The **AQE Roofing Consultant Toolkit** — a set of standalone field tools for
storm-damage restoration sales (built for Kurt Olsen / American Quality
Exteriors). Each tool is independently installable but they interoperate
through a shared SQLite database and a shared on-disk client folder layout.

There is **no single application**. The repo is a monorepo of small,
single-purpose command-line tools plus two markdown design/review documents.

## Layout

| Path | What it is | Stack |
|---|---|---|
| `stormtrack/` | Lead & claim pipeline CLI (knock → closed). The **hub** — owns the SQLite DB every other tool reads. | Python, click, rich, SQLite |
| `obj/` | Objection-handling knowledge base + fuzzy-search CLI with a self-quiz mode. Standalone. | Python, rapidfuzz, rich, click |
| `adjprep/` | Generates a one-page adjuster-meeting battle-card PDF; `adjprep learn` accumulates per-carrier intel. Reads stormtrack's DB. | Python, reportlab, PyYAML, click |
| `inspecto/` | Turns a folder of photos + `notes.txt` into a carrier-ready branded PDF inspection report. Reads the client folder. | Python, reportlab, Pillow, click |
| `newclient/newclient` | Bash script — one command creates a standardized client folder tree, README, creation log, and a macOS Apple Reminders follow-up. `--sync` writes the lead back to stormtrack's DB. | Bash + osascript |
| `tests/` | Pytest smoke tests for all tools; what CI runs. | pytest |
| `claude-code-specs-roofing-tools.md` | The original spec the Python tools were built from. Source of truth for intended behavior. | Markdown |
| `performance-windows-app-review.md` | A standalone feature review of a separate app. Documentation only. | Markdown |
| `environment.yml` | Conda env used by CI to install all runtime deps. | — |
| `.github/workflows/python-package-conda.yml` | CI: flake8 lint + pytest on every push. | — |

Each Python tool is its own installable package with a `pyproject.toml` and a
`[project.scripts]` console entry point. Package directories use an inner
package folder (e.g. `stormtrack/stormtrack/`, `obj/obj_cli/`).

## How the tools fit together (integration map)

```
stormtrack ──── SQLite DB everything else reads (~/.stormtrack/stormtrack.db)
    ├── newclient --sync    writes new leads back into the DB
    ├── adjprep <lead-id>   reads the lead, drops the prep PDF into the client folder
    └── inspecto            reads the client folder that newclient created
obj ── fully standalone; knowledge base lives in ~/objections/ as plain markdown
```

The database schema (leads, touches, pipeline stages) is defined and owned by
`stormtrack/stormtrack/db.py`. Other tools read it but must not redefine it.

## Environment / data locations

All tools honor environment-variable overrides; defaults live under the user's
home directory so nothing is written into the repo at runtime:

| Var | Default | Used by |
|---|---|---|
| `STORMTRACK_DB` | `~/.stormtrack/stormtrack.db` | stormtrack, adjprep |
| `AQE_CLIENTS_DIR` | `~/Documents/AQE Clients` | newclient, inspecto |
| `OBJ_KB_DIR` | `~/objections/` | obj |
| `ADJPREP_HOME` | adjprep config dir (carrier intel) | adjprep |

When adding features, **read the location from the env var with a sane default**
— never hard-code an absolute path.

## Development workflow

### Setup
```bash
# Runtime deps for all tools (mirrors CI):
conda env update --file environment.yml --name base
# or, per-tool editable installs:
pipx install ./stormtrack ./obj ./adjprep ./inspecto   # or: pip install -e <dir>
```

Python **3.11+** is required by the tool packages (`requires-python = ">=3.11"`);
note CI's conda job pins 3.10 for linting — keep code compatible with both.

### Run the tests
```bash
pytest                      # from repo root; conftest.py makes each tool importable
```
`tests/conftest.py` inserts each tool directory onto `sys.path`, so tests run
against the checkout **without** pip-installing first. Tests use `monkeypatch`
to point `STORMTRACK_DB` at a `tmp_path` DB and drive CLIs via
`click.testing.CliRunner`. Add tests here when you add behavior.

### Lint (matches CI)
```bash
flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics   # hard-fails the build
flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
```
Keep lines ≤127 chars and avoid syntax/undefined-name errors — those fail CI.

### Try it safely
```bash
stormtrack demo        # seeds 10 fake leads so you can poke around
stormtrack followups   # who needs attention now
```

## Conventions to follow

- **click for Python CLIs, rich for output.** Every command has `--help` with a
  usage example; keep that up when adding commands. stormtrack/inspecto expose a
  `@click.group()` named `main`; adjprep uses a group named `cli`.
- **SQLite migrations are append-only.** In `db.py`, add a new list of SQL
  statements to `MIGRATIONS` — never edit an existing migration. `migrate()`
  upgrades in place using the `schema_version` table.
- **Pipeline order is semantic.** The index position in `db.PIPELINE` defines
  stage progression; `TERMINAL` statuses (`dead`, `denied`) are separate.
  Changing a lead's status auto-logs a `touch`.
- **Reference intended behavior from the spec** (`claude-code-specs-roofing-tools.md`)
  before changing tool semantics.
- **Cross-tool contracts:** if you change the DB schema or the client folder
  layout, check every consumer in the integration map above.
- **newclient is macOS-aware:** the Reminders step uses `osascript` and degrades
  gracefully (warns, skips) on non-macOS. `set -euo pipefail` is in force.
- Match the surrounding style: module docstrings, small helper functions grouped
  under `# ---` comment banners, type hints on helpers.

## Git / branch conventions

- Active development branch for this work: `claude/claude-md-docs-wi04os`.
- Default branch: `main`.
- Commit with clear messages; open PRs as drafts.
