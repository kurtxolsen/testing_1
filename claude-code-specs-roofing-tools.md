# Claude Code Specs — AQE Roofing Consultant Toolkit
**Kurt Olsen | American Quality Exteriors | 2026**

Paste each spec into Claude Code as a single prompt. Each is written to be one-shot buildable: objective → stack → data model → features → acceptance criteria. Build order matters — Spec 1 is the foundation; Specs 2, 3, and 5 read from its database.

---

## SPEC 1 — `stormtrack`: Lead & Claim Pipeline CLI

### Objective
A fast, keyboard-driven CLI for managing storm-damage restoration leads from first knock to closed deal. Optimized for one-handed Terminal use between appointments. Zero friction — every command completes in under 3 seconds of typing.

### Tech Stack
- Python 3.11+, `click` for the CLI framework, `rich` for table output
- SQLite database at `~/.stormtrack/stormtrack.db` (auto-created on first run)
- Install as a global command via `pipx` or a setup.py entry point so `stormtrack` works from any directory

### Data Model
**Table: leads**
| Field | Type | Notes |
|---|---|---|
| id | INTEGER PK | auto-increment |
| name | TEXT | homeowner full name |
| address | TEXT | street address |
| phone | TEXT | |
| email | TEXT | optional |
| storm_date | DATE | date of the qualifying storm event |
| carrier | TEXT | insurance carrier name |
| claim_number | TEXT | optional, added once filed |
| deductible | REAL | optional |
| status | TEXT | see status enum below |
| source | TEXT | knock, referral, sign-call, canvass |
| notes | TEXT | freeform |
| created_at | TIMESTAMP | |
| last_touch | TIMESTAMP | updated on ANY interaction command |

**Table: touches** (interaction log)
| Field | Type |
|---|---|
| id | INTEGER PK |
| lead_id | FK → leads |
| touch_type | TEXT (call, text, door, email, adjuster-meeting) |
| note | TEXT |
| timestamp | TIMESTAMP |

### Status Enum (pipeline order)
`knocked → inspected → claim-filed → adjuster-scheduled → adjuster-met → approved → contract-signed → build-scheduled → built → closed`
Plus terminal states: `dead` and `denied` (denied leads can be reactivated for supplement/reinspection).

### Commands
1. `stormtrack add "Name" --address "..." --phone "..." --carrier "..." --storm-date 2026-05-15 --source knock`
   - Only name is required; everything else optional with prompts skippable via Enter.
2. `stormtrack status <id> <new-status>` — validates against the enum, warns (but allows) skipping stages, auto-logs a touch.
3. `stormtrack touch <id> call "left VM about adjuster date"` — logs interaction, bumps last_touch.
4. `stormtrack followups` — the money command. Lists leads breaching these staleness thresholds:
   - knocked: 2 days | inspected: 1 day | claim-filed: 3 days | adjuster-scheduled: day-of reminder | adjuster-met: 1 day | approved: 1 day | contract-signed: 5 days | build-scheduled: 7 days
   - Output: rich table sorted by days-overdue descending, color-coded (red = 2x threshold).
5. `stormtrack pipeline` — summary table: count + total estimated value per status, plus conversion % between adjacent stages.
6. `stormtrack show <id>` — full lead card with complete touch history.
7. `stormtrack search "elm"` — fuzzy match on name/address/carrier.
8. `stormtrack export --csv` — dump to `~/Desktop/stormtrack-export-YYYYMMDD.csv`.

### Edge Cases
- Duplicate detection: warn on add if name+address closely matches an existing lead.
- All dates accept `today`, `yesterday`, and `MM/DD` shorthand.
- `stormtrack status <id> dead --reason "..."` requires a reason.

### Acceptance Criteria
- `stormtrack followups` runs in <1s with 500 leads.
- Database survives version upgrades (use a schema_version table + migration function).
- Every command has `--help` with a usage example.
- Includes 10 seeded demo leads via `stormtrack demo` for testing.

---

## SPEC 2 — `newclient`: Client Folder + Reminder Automation (macOS)

### Objective
One Terminal command spins up a complete, standardized client workspace: folder tree, metadata README, and an Apple Reminders follow-up. Eliminates the "where did I put those photos" problem forever.

### Tech Stack
- Bash script as the entry point (`newclient`), installed to `/usr/local/bin` or `~/bin`
- AppleScript (via `osascript`) for the Apple Reminders integration
- Optional: reads/writes lead data from stormtrack's SQLite DB if present (`--sync` flag)

### Usage
```
newclient "John Smith" "123 Elm St, Oklahoma City, OK" --carrier "State Farm" --claim "SF-2026-88431"
```
Only name + address required. Carrier and claim number optional.

### Folder Structure (created under `~/Documents/AQE Clients/`)
```
Smith, John — 123 Elm St/
├── 01 Photos/
│   ├── Inspection/
│   ├── Damage/
│   └── Completion/
├── 02 Insurance Docs/
├── 03 Contracts/
├── 04 Correspondence/
├── 05 Measurements & Scope/
└── README.md
```

### README.md Template (auto-populated)
```markdown
# {Name} — {Address}
- **Created:** {date}
- **Carrier:** {carrier or TBD}
- **Claim #:** {claim or TBD}
- **Phone:** {phone or TBD}
- **Status:** New
## Timeline
- {date}: Client folder created
## Notes
```

### Apple Reminders Integration
- Creates a reminder in a list called "AQE Follow-Ups" (creates the list if missing).
- Title: `Follow up: {Name} — {street}`
- Due: tomorrow 9:00 AM by default; override with `--remind "friday 2pm"` (parse natural language via `date -d` fallback logic or a small parser).
- Notes field of the reminder contains the folder path for one-tap navigation.

### Behavior Details
- Folder name format: `Lastname, Firstname — Street` (parse the name; if single word, use as-is).
- If folder already exists: abort with a warning, do NOT overwrite; offer `--force` only to add missing subfolders.
- `--open` flag opens the new folder in Finder immediately.
- Log every creation to `~/Documents/AQE Clients/.client-log.csv` (name, address, timestamp).

### Acceptance Criteria
- Full run completes in <2 seconds.
- Handles names/addresses with apostrophes and commas without breaking (proper shell quoting).
- Works on macOS Sonoma+ without disabling any security settings (uses standard osascript permissions; first run will trigger the Reminders permission dialog — document this in the script header).
- Idempotent: running twice never corrupts anything.

---

## SPEC 3 — `inspecto`: PDF Inspection Report Generator

### Objective
Turn a folder of damage photos + a notes file into a carrier-ready, AQE-branded PDF inspection report in one command. The report should read like it was assembled by a professional, not a script — because adjusters judge documentation quality before they judge damage.

### Tech Stack
- Python 3.11+, `reportlab` for PDF generation, `Pillow` for image handling/EXIF orientation correction
- Input: a client folder (compatible with Spec 2's structure) or any folder of images + `notes.txt`

### Usage
```
inspecto "~/Documents/AQE Clients/Smith, John — 123 Elm St" --inspector "Kurt Olsen"
```

### Input Format — notes.txt
Simple keyed format the script parses:
```
CLIENT: John Smith
ADDRESS: 123 Elm St, OKC, OK 73102
CARRIER: State Farm
CLAIM: SF-2026-88431
STORM DATE: 2026-05-15
ROOF TYPE: Architectural asphalt shingle, ~12 yrs
DAMAGE:
- North slope: hail bruising, 8+ hits per test square
- Soft metals: dented gutters, downspouts, AC fins
- Wind: creased shingles along west ridge
PHOTOS:
IMG_001.jpg: North slope test square — 9 hail impacts marked
IMG_002.jpg: Gutter denting, front elevation
```
Photo captions are optional; uncaptioned photos get "Documented damage — {filename}".

### PDF Structure
1. **Cover page**: AQE branded header (company name, tagline placeholder, contact block — define brand colors as constants at the top of the script: primary `#1B3A5C` navy, accent `#E8A020` gold, easily editable), client info block, inspection date, inspector name.
2. **Damage Summary** (1 page): narrative paragraph auto-assembled from the DAMAGE section using proper insurance terminology. Include a standardized terminology mapping so casual notes get upgraded — e.g., "dents" → "soft metal collateral damage," "hail hits" → "hail impact bruising with granular displacement," "creased" → "wind-lifted and creased shingles compromising seal integrity."
3. **Photo Documentation**: 2×2 grid per page, each photo with caption bar beneath, auto-rotated per EXIF, numbered sequentially (Photo 1 of N).
4. **Recommended Scope** (final page): checklist-style scope derived from damage types found — e.g., hail bruising present → "Full replacement of affected slopes per manufacturer guidelines"; soft metal damage → "Replace gutters, downspouts; comb AC condenser fins." Include an ITEL/matching note placeholder and a signature block.

### Behavior Details
- Compress images to max 1600px wide before embedding (keeps PDFs under ~10MB for email).
- Output: `{Client Folder}/02 Insurance Docs/Inspection Report — {date}.pdf`
- `--draft` flag adds a diagonal DRAFT watermark.
- Sort photos by filename; support jpg/jpeg/png/heic (convert HEIC via Pillow-heif if available, else warn and skip).

### Acceptance Criteria
- 20-photo report generates in <15 seconds.
- No photo ever appears sideways (EXIF handled).
- Terminology mapping table is a plain Python dict at the top of the file — trivially extendable.
- Zero crashes on missing optional fields; report generates with "Not documented" placeholders.

---

## SPEC 4 — `obj`: Objection-Handling Knowledge Base + Fuzzy Search CLI

### Objective
A markdown knowledge base of every objection I face at the door and with adjusters, plus a CLI that surfaces the exact word-for-word response in under 2 seconds. This is muscle-memory infrastructure — the tool that makes rehearsal and real-time recall the same motion.

### Tech Stack
- Knowledge base: plain markdown files in `~/objections/` (git-friendly, portable, editable in any app)
- CLI: Python 3.11+, `rapidfuzz` for fuzzy matching, `rich` for formatted output

### Knowledge Base Structure
One file per category:
```
~/objections/
├── price-and-deductible.md
├── insurance-skepticism.md
├── spouse-not-home.md
├── already-have-a-guy.md
├── storm-chaser-distrust.md
├── no-damage-denial.md
├── bad-timing.md
└── adjuster-pushback.md
```

### Entry Format (strict, parseable)
```markdown
## OBJECTION: "I can't afford my deductible right now"
**Tags:** price, deductible, money, afford
**Category:** Price & Deductible

### The Reframe
They're not saying no — they're revealing their real decision criterion. Shift from cost to timing and consequence.

### Word-for-Word Response
"I completely understand — and honestly, that's exactly why we should file now rather than later. Your deductible doesn't change whether we do this today or in six months. What does change is that unrepaired hail damage compounds — and if you wait past your carrier's filing window, that deductible becomes the full cost of a new roof. Let's at least get the inspection documented so the clock works for you instead of against you."

### The Psychology
Loss aversion (Kahneman): framing inaction as the costlier path. Deadline scarcity is legitimate here — carriers do enforce filing windows — so it's persuasion, not manipulation. The phrase "the clock works for you" converts a threat frame into an ally frame.

---
```

### Seed Content Requirement
Generate 4–5 complete entries per category (30+ total) covering storm-restoration-specific objections, written in a natural Oklahoma-homeowner-facing voice. Responses must be tight enough to actually deliver aloud — 4 sentences max.

### CLI Commands
1. `obj "deductible"` — fuzzy search across objection text, tags, and body; returns top match fully formatted (Reframe → Response → Psychology), plus a one-line list of the next 2 runners-up.
2. `obj -l` — list all categories with entry counts.
3. `obj -c price` — dump all entries in a category (for pre-knock review in the truck).
4. `obj -r` — random objection with the response hidden; press Enter to reveal (self-quizzing mode — say your answer aloud first, then compare).
5. `obj add` — interactive prompt to append a new entry to the correct file in proper format.

### Acceptance Criteria
- Search returns in <500ms across 100+ entries.
- Fuzzy matching handles typos: `obj "deductable"` still hits.
- `-r` quiz mode tracks nothing — deliberately stateless, so it's zero-friction.
- Markdown files remain human-editable; the parser tolerates extra whitespace and blank lines.

---

## SPEC 5 — `adjprep`: Adjuster Meeting Prep Sheet Generator

### Objective
Generate a one-page PDF battle card before every adjuster meeting: claim facts, documented damage checklist, likely scope line items, that specific carrier's known pushback patterns, and my counter-documentation strategy. Walk onto the roof knowing the argument before it happens.

### Tech Stack
- Python 3.11+, `reportlab` for the one-page PDF
- Reads lead data from stormtrack's SQLite DB (Spec 1) via `adjprep <lead-id>`, OR standalone via `adjprep --manual` interactive prompts
- Carrier intelligence stored in `~/.adjprep/carriers.yaml` — editable, growable

### carriers.yaml Structure (ship with seed data)
```yaml
state_farm:
  display_name: "State Farm"
  known_pushback:
    - "Frequently disputes hail size vs. NOAA reports — bring hail impact photos with a coin or gauge for scale"
    - "Pushes repair-over-replace on slopes with <8 hits per square"
    - "May argue mechanical damage on wind-creased shingles"
  counter_strategy:
    - "Document 10x10 test squares on EVERY slope, chalk-circle each impact"
    - "Photograph soft metal damage first — it corroborates hail size independently"
    - "Cite manufacturer repairability guidelines for brittle/aged shingles"
allstate: ...
farmers: ...
usaa: ...
travelers: ...
liberty_mutual: ...
```
Seed with realistic, publicly known industry patterns for the 6 carriers above. Mark the file clearly as user-maintained field intelligence.

### PDF Layout (single page, dense but scannable)
**Header bar:** Client name | Address | Meeting date/time | Claim #
**Column 1 — Claim Facts:** carrier, adjuster name/phone (prompted if unknown), storm date + NOAA event reference placeholder, deductible, policy type (RCV/ACV — prompt for it).
**Column 2 — Documented Damage Checklist:** checkbox list generated from lead notes/damage types: test squares per slope, soft metals, wind damage, interior leaks, code items (drip edge, ice & water).
**Column 3 — Likely Scope Items:** Xactimate-style line item names mapped from damage types (e.g., "RFG 240 — Laminated comp shingle removal & replace," "Drip edge," "R&R gutters — aluminum, 5in"). Plain-English names are fine; note in comments these are approximations, not licensed Xactimate codes.
**Bottom band — Carrier Intel:** that carrier's pushback points and my counters, pulled from carriers.yaml. If the carrier isn't in the file, print "No intel on file — add after meeting: adjprep learn {carrier}".
**Footer:** "Post-meeting: log outcome → stormtrack touch {id} adjuster-meeting"

### Additional Command
- `adjprep learn state_farm "New pushback pattern observed..."` — appends to the carrier's YAML entry so the intel file compounds with every meeting.

### Acceptance Criteria
- One command, one page, <5 seconds.
- Renders cleanly when data is sparse (new lead with only name/address).
- YAML file survives hand-editing (parser is forgiving; validation warns rather than crashes).
- Output saved to the client folder's `02 Insurance Docs/` if the folder exists (Spec 2 integration), else `~/Desktop`.

---

## Build Order & Integration Map
```
SPEC 1 (stormtrack) ──── the database everything else reads
    ├── SPEC 2 (newclient) — optional --sync writes back to DB
    ├── SPEC 5 (adjprep) — reads lead by ID, writes prep PDF to client folder
    └── SPEC 3 (inspecto) — reads client folder created by Spec 2
SPEC 4 (obj) — standalone; zero dependencies on the others
```

**Recommended sequence:** 1 → 2 → 4 → 5 → 3. Specs 1+2 are daily infrastructure. Spec 4 sharpens you. Specs 5+3 win claims.
