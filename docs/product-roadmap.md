# Product roadmap

Status: Strategic working draft  
Last reviewed: 2026-08-24

This roadmap orders market-facing capabilities, not engineering tickets or release dates. Priorities should change when user research or implementation risk changes.

## Roadmap principle

First make the distinctive loop understandable and dependable. Then remove the practical barriers to daily use. Only after those are strong should the product expand into intelligence, ecosystem breadth, or complex analytics.

## Phase 1: prove the core loop

Goal: a new user understands the spatial model, shapes a real day, and returns.

- Polish polar readability, overlap handling, labels, touch targets, and precision.
- Build a short sample-day onboarding that includes one drag or resize.
- Keep a precise list or linear timeline beside the radial view.
- Make create, edit, occurrence-only change, undo, and error recovery dependable.
- Validate 12-hour vs. 24-hour defaults with users.
- Establish accessible semantics, Dynamic Type behavior, non-color cues, screen-reader alternatives, and reduced motion.
- Instrument minimal privacy-respecting activation signals or create a structured beta-interview process.

Decision gate: users can explain the value in their own words, complete a spatial edit without help, and show credible second-day retention.

## Phase 2: become viable for everyday scheduling

Goal: users can rely on the app without maintaining a duplicate planning system.

- Import or subscribe to system calendars with clear read-only/read-write behavior.
- Add reliable local notifications and useful rescheduling actions.
- Implement backup, export, and import before users accumulate irreplaceable history.
- Finish share, rate, and support paths that are currently placeholders.
- Add widgets and Live Activities for the current and next task.
- Improve conflict communication between imported events and editable tasks.

Decision gate: retained users can use the product as their daily planning surface for several weeks without a critical workflow gap.

## Phase 3: earn Pro conversion

Goal: paid capabilities deepen an established habit rather than ransom the core experience.

- Multiple-calendar controls and advanced import behavior.
- Reusable day templates and stronger apply-forward planning.
- Advanced recurrence and batch editing with safe previews.
- Extended history and supportive pattern insights.
- Theme, clock, and icon customization built on the brand system.
- Cross-device sync if demand justifies the privacy and reliability cost.
- Watch experience focused on current context and quick recovery actions.

Decision gate: users can name a recurring high-value outcome delivered by Pro, and paid conversion occurs after that value is encountered.

## Phase 4: assist schedule recovery

Goal: make changing plans even easier without taking control away from the user.

Potential capabilities:

- Surface open time that can fit a displaced task.
- Preview a “shift the rest of the day” operation before applying it.
- Identify conflicts, insufficient buffers, or unrealistic duration totals.
- Learn common task durations locally and offer optional estimates.
- Suggest, rather than automatically impose, a recovery plan.

Any intelligence should be transparent, reversible, privacy-conscious, and expressed through the same direct spatial model.

## Capabilities to defer

- Full project-management hierarchies.
- Team collaboration and managerial reporting.
- Social feeds, competitive streaks, or public productivity scores.
- General-purpose AI chat disconnected from the visual planning loop.
- Heavy habit-tracker mechanics that compete with daily scheduling.
- Platform expansion before the primary experience is stable enough to reproduce well.

## Strategic dependencies

| Market claim | Product requirement |
| --- | --- |
| “See your whole day” | Legible overlap, labels, current-time state, and companion precision view |
| “Move the plan” | Reliable arc manipulation, quick actions, undo, and recurrence-safe edits |
| “Daily planner” | Calendar integration, notifications, backup, and robust creation/editing |
| “Private by design” | Clear data architecture, minimal analytics, and transparent sync choices |
| “ADHD-friendly” | Low-friction onboarding, accessibility, forgiving recovery, and user validation |
| “Your schedule stays on your device” | No undisclosed server transfer; revise claim if sync architecture changes |

## Research backlog

- Observe at least five target users planning and then repairing a disrupted day.
- Compare sample-first onboarding with calendar-import-first onboarding.
- Test whether miniature month rings communicate useful density or merely decoration.
- Measure the discoverability and error rate of endpoint dragging.
- Interview users who abandon the app after creating tasks but before returning.
- Determine which glanceable surface—widget, Live Activity, or watch—most improves daily reliance.

## Open decisions

- Initial launch platforms and the acceptable degree of platform asymmetry.
- Whether calendar events are editable objects, fixed constraints, or both.
- Whether platform cloud storage is sufficient for sync and lifetime economics.
- Which accessibility alternative best communicates overlaps outside the visual ring.
- What minimum feature set justifies charging for Pro.

