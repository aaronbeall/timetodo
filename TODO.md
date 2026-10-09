# Engineering TODO

Status: Living backlog  
Last updated: 2026-08-25

Strategy and market-facing order live in [docs/product-roadmap.md](docs/product-roadmap.md). This file is the **implementation gap list**: placeholders in the app, missing loop pieces, and quality holes. Strike items when they ship; add new gaps when they show up.

## Settings stubs (user-visible “Coming soon”)

These are wired in `flutter/lib/screens/settings_screen.dart` and currently toast only:

- [ ] Export data
- [ ] Import data
- [ ] Tip jar
- [ ] Share
- [ ] Rate

Related About copy already promises export/share as user-initiated (`flutter/lib/screens/about_screen.dart`).

## Core loop (roadmap phase 1)

- [ ] First-run onboarding with a sample day and one polar drag or resize (demo load in Settings is not onboarding)
- [ ] Polar accessibility: semantics for bands/overlaps, Dynamic Type, non-color cues, screen-reader alternative to the ring
- [ ] Honor reduced motion more completely (polar already snaps; other surfaces still animate)
- [ ] Privacy-respecting activation signals **or** a structured beta-interview process (no analytics today)
- [ ] Validate 12-hour vs 24-hour polar defaults with users
- [ ] Polar performance: Today rebuilds every second; animation rebuilds the whole clock subtree (quality is fine; cost is not tight)

## Everyday scheduling (roadmap phase 2)

- [ ] Local notifications and useful reschedule actions from the notification
- [ ] System calendar import/subscribe with explicit read-only vs read-write
- [ ] Conflict communication between imported events and editable tasks
- [ ] Backup (beyond JSON export) before history becomes irreplaceable
- [ ] Home-screen widgets / glanceable “now and next”
- [ ] iOS Live Activities (if iOS is in the first launch set)

## Calendar and polar (known incomplete)

- [ ] Month/year have no on-canvas prev/next (header chevrons were removed; swipe-only)
- [ ] Year view is a heat map, not polar — decide if that is enough
- [ ] Week/month miniature rings: still need a read on whether they communicate density or just decorate (roadmap research item)
- [ ] Polar move: apply-to-future / series vs occurrence is easy to miss; confirm the sheet always makes the scope obvious
- [x] Occurrence sheet: spatial polar + **Reshape** (was Move); long-press hint when reshape was not started from the clock
- [ ] Reshape/move on Week, Month, and Year (no large polar in the main view): open a polar chart in a popover, sheet, or inlay so the drag still works
- [ ] Search / jump-to-date in calendar
- [ ] Timezone and travel-day handling

## Tasks

- [ ] Optional **task icons** (curated set, not freeform emoji dump): pick on create/edit; show in list rows, occurrence sheet, and as a small mark on polar arcs / compact rings so color-only days are easier to scan. Persist on `Task` (not per occurrence). Keep polar uncluttered at small sizes (hide or shrink on week/month chips).

## Stats

- [ ] Radial histogram chart on the Stats tab (`reports_screen.dart`) — polar-aligned history, not a linear bar chart

## Product identity vs code

- [ ] App still brands as **TimeToDo**; strategy docs use candidate name **Diyal** — rename, store listing, and About copy when the name is cleared
- [ ] Trademark / App Store / domain / handle diligence for Diyal (called out in `docs/README.md`)
- [ ] Launch platform decision (docs: Android-first wedge; Flutter app is multi-platform)

## Quality

- [ ] Real test suite (only a smoke `widget_test.dart`; polar packing, eras, and occurrence edits are untested)
- [ ] Polar clock: `shouldRepaint` uses list identity; rebuilds more than needed
- [ ] Confirm empty-day / packed-day demos stay in sync with the current model (eras, 12h polar)

## Explicitly later (do not start unless a phase 1–2 item depends on it)

From the roadmap “defer” and Pro lists: project hierarchies, team features, streaks-as-social, **generic AI chat** (keep deferred; see intelligence below), habit-tracker mode, watch app, cross-device sync, day templates, advanced recurrence/batch edit, paid entitlements, extra themes/icons.

## Scheduling intelligence (later; not generic AI)

Roadmap phase 3 and [positioning](docs/positioning.md): suggestions that show on the polar clock, optional and undoable, on-device when possible. Do **not** add a chatbot.

- [ ] **Fit gaps:** when a task is displaced or unscheduled, highlight open arcs long enough to hold it; tap a gap to drop the task there
- [ ] **Shift the rest:** preview sliding later tasks along the ring after a drag/extend; apply only on confirm
- [ ] **Overfull / no-buffer cues:** mark overlaps, stacked duration past 24h, and missing travel/buffer between adjacent tasks without auto-reordering
- [ ] **Local duration hints:** from this device’s history, offer a typical duration when creating or extending a named task (no cloud model required)
- [ ] **Recovery layouts:** after skip/snooze/late start, offer 2–3 alternate day shapes (compact remaining work, protect a block, push to tomorrow) as polar previews
- [ ] **Parse into an arc:** one-shot “Walk 30 min after lunch” → draft start/duration on the clock, user commits (speech or a single field—not a conversation)

## Research (not tickets, but they unblock design)

See also `docs/product-roadmap.md` → Research backlog.

- Watch target users plan and then repair a disrupted day
- Sample-day onboarding vs calendar-import-first
- Endpoint-drag discoverability and error rate
- Which glanceable surface (widget, Live Activity, watch) actually increases daily use
