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

**Phase 4 (this build):** deep analytics + digital card + team scaffold —
Reports gains a conversion funnel (knocks → conversations → leads →
inspections → signed, with rates and knocks-per-lead), best-time-of-day
rankings, and best-streets rankings; a Digital Card (branded card face,
on-device QR that encodes a vCard for homeowner scanning, share sheet) with
an editable rep profile; and a Team leaderboard/goal screen whose row model
is Supabase-ready so teammates appear when sync lands.

**Phase 5 (this build):** Apple platform features — Siri Shortcuts / Action
Button support ("Log a knock in AQE Field", "Today's stats in AQE Field")
via App Intents; a Home Screen + Lock Screen widget showing today's knocks
vs. goal (30-minute timeline, reloaded on every save); and a shift Live
Activity with a Dynamic Island timer that starts on the first knock of the
day and updates with every logged door ("End Shift Timer" lives in More).
The store moved to an App Group container (`group.com.aqe.field`, with
silent fallback and one-time migration) so the widget extension can read
it. `AQEFieldWidgets/` is a second XcodeGen target embedded in the app.

**Phase 6 (this build):** Cloud Sync — a dependency-free Supabase client
(`CloudSync`) with email/password auth, token refresh, idempotent push of
all local data (upserts keyed on device UUIDs), and own-rows pull so a new
phone restores your history. Configure in More → Cloud Sync with the
Supabase Project URL + anon key from the "AQE Office Hub" Lovable project
(backend settings → API); the app also auto-syncs on launch when signed
in. The backend (tables: reps, knock_events, leads, property_intel,
storms; RLS: authenticated read-all, write-own via created_by) and the
office web dashboard live in that Lovable project.

**Phase 7 (this build):** the Team leaderboard goes live — when signed in
to Cloud Sync it ranks every rep on the Supabase project by today's
knocks/leads/signed (pull-to-refresh), with a combined team knock goal;
offline or signed out it falls back to local-only stats.

Still open: PDF imports into the Field Bible, Apple Wallet pass (needs a
signing certificate), Apple Watch.

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
