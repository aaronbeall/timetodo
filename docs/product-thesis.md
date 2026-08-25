# Product thesis

Status: Working draft  
Last reviewed: 2026-08-24

## The product in one sentence

Time To Do is a visual daily planner that maps tasks onto a polar clock so people can understand the shape of their day and adjust it directly as plans change.

## The essential insight

Most planners represent a day as a list of obligations or a vertical grid of appointments. Both are useful, but neither creates an immediate sense of the day as a finite whole.

The polar clock turns time into a bounded space. Duration becomes arc length, sequence becomes position, overlap becomes visible layering, and the remaining day can be felt at a glance. This is especially valuable for people who think visually, struggle to estimate time, or repeatedly rebuild their schedule during the day.

The product is therefore not “a to-do list with a circular skin.” Its core loop is:

1. See the whole day.
2. Recognize what is happening, what overlaps, and what still fits.
3. Move or resize tasks directly.
4. Recover the plan without rebuilding it.

The circle creates comprehension. Direct manipulation creates utility and retention.

## Target user and job to be done

The primary user is a visually oriented professional or student with a mixed, changeable day: meetings, focused work, routines, errands, and personal commitments competing for finite time.

Their job to be done is:

> When my day is full or changes unexpectedly, help me see what is realistic and reshape the plan quickly so I can keep moving without mentally reconstructing the entire schedule.

This naturally includes some people with ADHD or time blindness, but the product should solve a concrete planning problem rather than depend on a medical identity or medical claims.

Secondary audiences include caregivers, shift workers, freelancers, and people building time-based routines.

## What the current implementation proves

The Flutter implementation already expresses the distinctive interaction model:

- A Today view with a concentric polar clock for active, upcoming, completed, and all-day work.
- Direct arc editing: long-press to move, drag the task body, or adjust its endpoints.
- Five-minute snapping and haptic feedback for deliberate but fluid edits.
- One-day occurrence changes that preserve the underlying recurring series.
- Fast recovery actions such as Snooze 15, Extend 15, Do Now, Complete, Skip, and Undo.
- Recurrence modeled as a series plus dated occurrences, including daily, weekly, monthly, and custom patterns.
- Schedule, day, week, month, and year calendar views; month cells summarize days as miniature radial rings.
- Basic behavioral feedback through streaks, completion and skip rates, recent history, and task streaks.
- Local-first operation with no account, cloud dependency, or analytics in the current product.
- Configurable clock presentation, including 12/24-hour formats, origin, labels, tracks, and origin line.

Useful implementation references:

- `../flutter/lib/screens/today_screen.dart`
- `../flutter/lib/widgets/polar_clock.dart`
- `../flutter/lib/providers/task_provider.dart`
- `../flutter/lib/models/task.dart`
- `../flutter/lib/models/task_occurrence.dart`
- `../flutter/lib/screens/calendar_screen.dart`
- `../flutter/lib/screens/reports_screen.dart`

## Product principles

### The day is the primary object

Tasks matter in relation to finite time. The product should optimize for shaping today, not maintaining an elaborate project taxonomy.

### Changes should be spatial and reversible

Moving a task should feel like moving a task, not filling out a form. Edits should snap intelligently, provide feedback, and be easy to undo.

### Recurrence must tolerate real life

A routine is a pattern, not a prison. Changing today's occurrence without accidentally rewriting the whole series is a core promise.

### The polar view and precise view are complementary

Radial views are strong for gestalt but weaker for exact comparison. A controlled study of 24-hour displays found linear bar charts more accurate and efficient than radial designs for exact time reading; radial displays can still be effective for overall feel. The product should keep a list or linear timeline available rather than force every task through the circle. [Study](https://arxiv.org/abs/1907.13534)

### Calm comes from clarity, not decoration

The interface should use motion, color, and geometry to communicate state. Visual novelty that makes time harder to read works against the product.

### Privacy can be a product benefit

Local-first operation makes the app fast, dependable, and credible for personal schedule data. Future sync should not quietly erase this advantage.

## Why this can win

The polar clock alone is not defensible; several products already use one. The defensible experience is the combination of:

- Whole-day spatial comprehension.
- Task-native planning rather than passive calendar display.
- Exception-friendly recurrence and one-day edits.
- Fast schedule-recovery actions.
- A consistent “days as rings” language across Today and Calendar.
- Private, calm, local-first interaction.

The product should own **schedule recovery**: not only showing the intended plan, but making the inevitable change feel effortless.

## Principal risks

- The circle may initially look like a novelty or require explanation.
- Precision and accessibility can suffer if the radial view becomes the only interface.
- A direct competitor already offers a closely matched radial planner interaction.
- Missing calendar import, notifications, widgets, backup, and sync may block everyday adoption.
- Rich analytics or gamification could turn a calm planning tool into a source of judgment.
- Broad “productivity app” positioning would place the product against mature suites on their terms.

## Open questions

- Is the strongest first audience broadly “visual planners,” or the narrower time-blindness/ADHD-friendly market?
- Does a 12-hour dial communicate more clearly than a 24-hour dial for most new users?
- Which action creates the strongest activation signal: adding a timed task, dragging an arc, or changing one occurrence?
- Will users plan inside the app, import a calendar, or use a hybrid workflow?
- How much scheduling intelligence is useful before the product stops feeling direct and personal?

