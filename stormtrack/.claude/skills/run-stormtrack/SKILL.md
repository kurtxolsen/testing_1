---
name: run-stormtrack
description: Build, install, run, and drive the stormtrack lead-pipeline CLI. Use when asked to run stormtrack, smoke-test it, exercise its commands (add/status/touch/followups/pipeline/search/export), or verify a change to its pipeline/followup/export logic.
---

`stormtrack` is a Python `click` CLI (SQLite-backed) for storm-damage
restoration leads. Drive it with the smoke script at
`.claude/skills/run-stormtrack/smoke.sh` — it installs the package, runs
every command against a throwaway database, and exit-codes 0 on success.

All paths below are relative to the `stormtrack/` package directory (the
one with `pyproject.toml`). The shared test suite lives at the **repo
root**, one level up.

## Prerequisites

Python 3.11+ is already present in this container; no `apt-get` needed.
Runtime deps (`click`, `rich`) are pulled in by the install step below.
For the test suite you also need `pytest`:

```bash
pip install pytest
```

## Setup

Install the package editable — this puts `stormtrack` on `PATH` **and**
registers the distribution metadata that `--version` needs:

```bash
pip install -e .
```

Verify:

```bash
stormtrack --version
# → stormtrack, version 1.0.0
```

## Run (agent path)

The smoke driver is the primary handle. It creates an isolated
`STORMTRACK_DB` in a temp dir (never touches `~/.stormtrack/`), installs
the package if it isn't already, and drives the full command surface plus
a direct-invocation check of the internal helpers:

```bash
bash .claude/skills/run-stormtrack/smoke.sh
# ... rich tables for followups / pipeline / search / show ...
# → ALL SMOKE CHECKS PASSED   (exit 0)
```

What it exercises, in order: `--version`, `--help`, `demo` (seeds 10
leads), `add`, `status` (with a stage-skip warning + auto-logged touch),
`touch`, `followups`, `pipeline`, `search`, `show`, the `dead`-requires-
`--reason` guard (asserts non-zero exit), `status … dead --reason`,
`export` (asserts the CSV has data rows), and finally imports
`pipeline_stats` + `is_breaching` and checks the conversion math and
threshold boundaries.

### Direct invocation (internal helpers)

Most changes here touch `pipeline_stats()` / `is_breaching()` in
`stormtrack/cli.py`. Call them without the CLI — point `STORMTRACK_DB` at
a temp file so importing never opens real data:

```bash
STORMTRACK_DB=/tmp/st-scratch.db python -c '
from stormtrack.cli import pipeline_stats, is_breaching
counts, values, conv = pipeline_stats(
    [{"status": "knocked", "estimated_value": 1000}] * 2
    + [{"status": "inspected", "estimated_value": 2000}]
    + [{"status": "claim-filed", "estimated_value": None}])
print("knocked->inspected:", conv["knocked"], "%")   # 50.0
print("breach knocked@3d:", is_breaching("knocked", 3))  # True
'
```

## Run (human path)

Drive the real commands directly (writes to `~/.stormtrack/stormtrack.db`
unless `STORMTRACK_DB` is set):

```bash
stormtrack demo          # seed 10 demo leads
stormtrack followups     # the money command — who's overdue, color-coded
stormtrack pipeline      # counts, value, and stage-to-stage conversion %
```

## Test

The suite lives at the repo root and covers all five tools; run it from
there:

```bash
cd .. && python -m pytest tests/ -q
# → 15 passed
```

`tests/conftest.py` puts each tool package on `sys.path`, so no install is
needed just to run the tests.

## Gotchas

- **`python -m stormtrack.cli --version` crashes on an *uninstalled*
  tree** with `RuntimeError: 'stormtrack' is not installed`. `click`'s
  `@version_option()` reads `importlib.metadata`, which has no
  distribution until `pip install -e .`. After installing, both the
  `stormtrack` entry point and the module form work. The driver installs
  first for exactly this reason.
- **`export` ignores `--out`-less runs' location by design** — it writes
  to `~/Desktop/stormtrack-export-YYYYMMDD.csv`, falling back to `~` when
  there's no Desktop. The driver sets `HOME` to its temp dir so the file
  lands somewhere disposable; do the same if you don't want files in your
  real home.
- **`STORMTRACK_DB` is the isolation seam.** Any command (and even just
  importing `stormtrack.cli` paths that connect) will create/open the DB
  at that path. Always set it to a temp file in scripts.
- **Dates accept `today` / `yesterday` / `MM/DD` shorthand**, not just
  ISO — `--storm-date 05/15` resolves to the current year. Handy when
  driving `add`.

## Troubleshooting

- **`RuntimeError: 'stormtrack' is not installed. Try passing
  'package_name' instead.`**: the package isn't pip-installed. Run
  `pip install -e .` (the driver does this automatically).
- **`No module named pytest`**: `pip install pytest`, then re-run the
  Test command from the repo root.
- **`No module named stormtrack`** in direct-invocation one-liners: run
  them from inside `stormtrack/`, or `pip install -e .` first so the
  package is importable from anywhere.
