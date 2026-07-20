# AQE Field — iOS app

Field operating system for a roofing consultant walking neighborhoods.
Not a CRM: one-handed, one-tap, readable in bright sunlight.

**Phase 1:** navigation, dashboard command center, one-tap knock workflow,
live goal rings, working map pins, minimal-typing lead capture, follow-up
queue, offline-first local persistence.

**Phase 2 (this build):** the AQE Field Bible — a searchable, fully offline
knowledge base bundled into the app (scripts, objection handling ported from
`obj/`, insurance explanations, carrier intel ported from `adjprep/`, GAF
system + warranties, roof anatomy, damage ID, sales psychology, Never Split
the Difference notes, follow-up SOP). Reachable from the Dashboard quick
action and the More tab. Add/edit articles by dropping markdown files into
`AQEField/Resources/FieldBible/` and listing them in `manifest.json`.

**Phase 3 (this build):** neighborhood intelligence — Neighborhood Mode
(swipe left/right between houses with one-tap outcomes and a full intel
card), per-house Property Intel (value estimate, roof age, last hail date,
permit history, insurance notes — hand-entered now, provider-slotted for
Zillow/permit/NOAA APIs later), a Storm Log whose newest storm auto-tags
new leads and draws a radius overlay on the map, a GPS breadcrumb trail
recorder, and a heat view layer. Map gains a layers menu (trail / storm /
heat) and a Neighborhood Mode launcher.

Planned next: Phase 4 team + deep analytics (Supabase sync hooks in behind
`AppStore`).

## Build & run (on your Mac)

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
cd AQEField
xcodegen generate        # creates AQEField.xcodeproj from project.yml
open AQEField.xcodeproj  # then ⌘R onto a simulator or your iPhone
```

`project.yml` is the source of truth — the `.xcodeproj` is gitignored and
regenerated. Never hand-edit the project file; edit `project.yml` and re-run
`xcodegen generate`.

To run on your own iPhone with a free Apple ID: select the AQEField target →
Signing & Capabilities → check "Automatically manage signing" and pick your
Personal Team. (Free-account installs expire after 7 days; TestFlight/App
Store need the $99/yr Apple Developer Program.)

## Architecture

```
AQEField/
├── App/         AQEFieldApp (entry) · RootView (tabs + floating "+")
├── Theme/       AQETheme — navy/coral palette, status colors, big type
├── Models/      KnockOutcome · KnockEvent · Lead · DailyGoals · DayStats
├── Services/    AppStore (offline-first JSON persistence)
│                LocationService (GPS + reverse geocode)
│                WeatherService (Open-Meteo, no API key)
│                BibleStore (bundled Field Bible loader + search)
├── Resources/   FieldBible/ — manifest.json + markdown articles
└── Views/       Dashboard (stat cards, goal rings) · Knock · Map (pins,
                 trail, storm & heat layers) · Neighborhood (swipe cards,
                 intel editor, storm log) · Lead sheet · Reports ·
                 Bible (search, categories, article reader) · More
```

- Every knock outcome tap auto-captures timestamp + GPS + street address and
  immediately updates goals, streaks, the map, and reports.
- All data persists locally (`Application Support/AQEField/store.json`), so
  the app is fully functional with zero cell service.
- Weather degrades silently offline; GPS-denied knocks still log.
