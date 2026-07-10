#!/usr/bin/env bash
#
# smoke.sh — drive the real stormtrack CLI end-to-end against a throwaway DB.
#
# This is the agent path for "run stormtrack". It exercises every command a
# user actually types (add / status / touch / followups / pipeline / search /
# show / export / demo) plus a direct-invocation check of the internal helpers
# (pipeline_stats, is_breaching) that recent PRs touch. Exit code 0 == all good.
#
# Runs from anywhere. Uses an isolated STORMTRACK_DB in a temp dir, so it never
# reads or writes the real ~/.stormtrack/stormtrack.db.
#
# Usage:  bash .claude/skills/run-stormtrack/smoke.sh
#
set -euo pipefail

# --- locate the package root (this script lives at <pkg>/.claude/skills/run-stormtrack/) ---
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(cd "$HERE/../../.." && pwd)"   # -> the stormtrack/ package dir (has pyproject.toml)

# --- isolated database + a real Desktop dir so `export` has somewhere to land ---
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export STORMTRACK_DB="$WORK/st.db"
export HOME="$WORK"                 # export writes to $HOME/Desktop or $HOME
mkdir -p "$WORK/Desktop"

# --- resolve the CLI ------------------------------------------------------
# Prefer the installed `stormtrack` entry point. If it's missing, install the
# package editable so the entry point AND its version metadata both exist —
# `stormtrack --version` uses importlib.metadata and fails under `python -m`
# on an uninstalled tree (see Gotchas in SKILL.md).
if ! command -v stormtrack >/dev/null 2>&1; then
  echo "stormtrack not on PATH — installing editable from $PKG"
  pip install -e "$PKG" >/dev/null
fi
ST=(stormtrack)

say() { printf '\n\033[1;36m# %s\033[0m\n' "$*"; }
run() { printf '\033[2m$ %s\033[0m\n' "${ST[*]} $*"; "${ST[@]}" "$@"; }

say "version + help (every command must expose --help)"
run --version
run followups --help >/dev/null && echo "  followups --help OK"

say "seed 10 demo leads"
run demo

say "add a lead (only name required)"
run add "Smoke Tester" --address "1 Test Ln, OKC" --carrier "State Farm" --value 15000

say "status change with a stage-skip warning + auto-logged touch"
run status 11 approved

say "log an interaction"
run touch 11 call "left VM about adjuster date"

say "the money command — who's overdue"
run followups

say "pipeline summary (counts, value, conversion %)"
run pipeline

say "fuzzy search"
run search edmond

say "full lead card + touch history"
run show 11

say "dead requires a --reason (this SHOULD fail with a non-zero exit)"
if "${ST[@]}" status 11 dead 2>/dev/null; then
  echo "  ERROR: 'status dead' without --reason should have failed" >&2
  exit 1
else
  echo "  correctly rejected 'dead' with no --reason"
fi
run status 11 dead --reason "homeowner sold the house"

say "export to CSV and confirm the file has rows"
run export
CSV="$(ls "$WORK"/Desktop/stormtrack-export-*.csv 2>/dev/null | head -1 || true)"
[ -z "$CSV" ] && CSV="$(ls "$WORK"/stormtrack-export-*.csv | head -1)"
LINES="$(wc -l < "$CSV")"
echo "  wrote $CSV ($LINES lines incl. header)"
[ "$LINES" -ge 2 ] || { echo "  ERROR: export produced no data rows" >&2; exit 1; }

say "direct invocation — the internal helpers PRs actually touch"
STORMTRACK_PKG="$PKG" python - <<'PY'
import os, sys
sys.path.insert(0, os.environ["STORMTRACK_PKG"])
from stormtrack.cli import pipeline_stats, is_breaching

# conversion math: 4 leads reached "knocked", 2 of them reached "inspected",
# 1 of those reached "claim-filed" -> 50% at each of the first two stages.
counts, values, conv = pipeline_stats(
    [{"status": "knocked", "estimated_value": 1000}] * 2
    + [{"status": "inspected", "estimated_value": 2000}]
    + [{"status": "claim-filed", "estimated_value": None}]
)
assert counts["knocked"] == 2 and values["knocked"] == 2000, (counts, values)
assert conv["knocked"] == 50.0, conv          # 2 of 4 reached inspected
assert conv["inspected"] == 50.0, conv        # 1 of 2 reached claim-filed
assert conv["closed"] is None                 # last stage: undefined
# threshold boundaries
assert not is_breaching("knocked", 2) and is_breaching("knocked", 3)
assert not is_breaching("adjuster-scheduled", 0) and is_breaching("adjuster-scheduled", 1)
assert not is_breaching("closed", 99)
print("  pipeline_stats + is_breaching: OK")
PY

printf '\n\033[1;32mALL SMOKE CHECKS PASSED\033[0m\n'
