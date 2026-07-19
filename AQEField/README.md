# AQE Field — iOS app

Field operating system for a roofing consultant walking neighborhoods.
Not a CRM: one-handed, one-tap, readable in bright sunlight.

**Phase 1 (this build):** navigation, dashboard command center, one-tap knock
workflow, live goal rings, working map pins, minimal-typing lead capture,
follow-up queue, offline-first local persistence.

Planned next: Phase 2 Field Bible · Phase 3 neighborhood intelligence ·
Phase 4 team + deep analytics (Supabase sync hooks in behind `AppStore`).

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
└── Views/       Dashboard (stat cards, goal rings) · Knock · Map ·
                 Lead sheet · Reports (follow-ups, 7-day trend) · More
```

- Every knock outcome tap auto-captures timestamp + GPS + street address and
  immediately updates goals, streaks, the map, and reports.
- All data persists locally (`Application Support/AQEField/store.json`), so
  the app is fully functional with zero cell service.
- Weather degrades silently offline; GPS-denied knocks still log.
