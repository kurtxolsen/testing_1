# AQE Roofing Consultant Toolkit

Field tools for storm-damage restoration sales — lead pipeline, client
workspaces, inspection reports, objection handling, and adjuster meeting prep.
Built from the specs in `claude-code-specs-roofing-tools` for Kurt Olsen /
American Quality Exteriors.

Also in this repo: [`performance-windows-app-review.md`](performance-windows-app-review.md),
a feature review of the Performance Windows field sales app.

## The tools

| Tool | What it does | Stack |
|---|---|---|
| [`stormtrack`](stormtrack/) | Lead & claim pipeline CLI — knock to closed deal, staleness follow-ups, pipeline conversion stats | Python, click, rich, SQLite |
| [`newclient`](newclient/) | One command creates a standardized client folder tree, README, creation log, and an Apple Reminders follow-up (macOS) | Bash + osascript |
| [`inspecto`](inspecto/) | Folder of photos + `notes.txt` → carrier-ready branded PDF inspection report with terminology upgrades | Python, reportlab, Pillow |
| [`obj`](obj/) | Objection-handling knowledge base (32 seeded entries) + fuzzy-search CLI with self-quiz mode | Python, rapidfuzz, rich |
| [`adjprep`](adjprep/) | One-page adjuster meeting battle card PDF with per-carrier pushback intel that compounds via `adjprep learn` | Python, reportlab, YAML |

## Install

Python tools (each installs a global command):

```bash
pipx install ./stormtrack ./obj ./adjprep ./inspecto   # or: pip install -e <dir>
```

The shell tool:

```bash
install -m 755 newclient/newclient ~/bin/newclient     # or /usr/local/bin
```

## Integration map

```
stormtrack ──── the SQLite database everything else reads (~/.stormtrack/stormtrack.db)
    ├── newclient --sync    writes new leads back to the DB
    ├── adjprep <lead-id>   reads the lead, drops the prep PDF into the client folder
    └── inspecto            reads the client folder newclient created
obj ── standalone; knowledge base lives in ~/objections/ as plain markdown
```

## Daily loop

```bash
stormtrack add "Jane Doe" --address "12 Elm St, OKC" --source knock
newclient "Jane Doe" "12 Elm St, OKC" --carrier "State Farm" --sync
inspecto "~/Documents/AQE Clients/Doe, Jane — 12 Elm St" --inspector "Kurt Olsen"
adjprep 1 --policy-type RCV --meeting "Fri 2:30 PM"
stormtrack followups        # who needs attention right now
obj "deductible"            # word-for-word response, in the truck, in 2 seconds
```

Environment overrides (all optional): `STORMTRACK_DB`, `AQE_CLIENTS_DIR`,
`OBJ_KB_DIR`, `ADJPREP_HOME`.

Every command has `--help` with a usage example. `stormtrack demo` seeds 10
test leads if you want to poke around safely.
