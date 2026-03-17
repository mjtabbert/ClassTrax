# ClassTrax Build Plan

This document is the working roadmap for turning ClassTrax into a teacher daily command center.

It is intentionally high signal and not overly detailed.
When you are ready for the next phase, copy the prompt for that phase and give it to Codex.

## Product Direction

ClassTrax should become:

- the teacher's daily schedule runner
- the classroom timer and bell system
- the school-only task and planning space
- the place where altered schedules, duties, meetings, and prep all live
- a tool that helps keep school work separate from personal life

## Current State

Already in place:

- Today screen with active block and next-up focus
- teacher-oriented landscape mode
- live timer and progress ring
- in-app warning overlays
- hold / extend / skip-bell runtime controls
- Live Activity support
- schedule builder tools
- profiles
- CSV import/export flow

## Recommended Build Order

1. Teacher Dashboard
2. Commitments Layer
3. Day Override Engine
4. School / Personal Separation
5. Teacher Task Upgrade
6. Fast Capture
7. Class / Student Context
8. Calendar / Reminder Integration

## Phase 1: Teacher Dashboard

Goal:
Make the app home screen feel like a real teacher command center, not just a timer.

Screens likely touched:

- `ClassTrax/Views/TodayView.swift`
- `ClassTrax/Views/RootTabView.swift`
- `ClassTrax/Views/NextUpSummaryCard.swift`
- `ClassTrax/Views/ActiveTimerCard.swift`
- possibly a new dashboard component file under `ClassTrax/Views/` or `ClassTrax/Components/`

Main outcomes:

- Today screen becomes the teacher home dashboard
- show current block, next block, and next 2-3 upcoming items
- add a clear "coming later today" strip
- surface today’s top tasks on the same screen
- add school-day context like duties / meetings / reminders once available

Prompt to start this phase:

`Build the Teacher Dashboard phase for ClassTrax. Keep Today as the main home screen, but evolve it into a teacher command center with current block, next block, upcoming items, and a clean area for today’s top tasks. Keep the existing timer strengths and do not regress landscape teacher mode.`

## Phase 2: Commitments Layer

Goal:
Support non-class obligations in the same daily flow.

Screens / files likely touched:

- `ClassTrax/Models/AlarmItem.swift` or a new model for commitments
- `ClassTrax/Views/TodayView.swift`
- `ClassTrax/Views/ScheduleView.swift`
- `ClassTrax/Views/TimelineRow.swift`
- possibly new views for editing commitments

Main outcomes:

- support meetings, duty, PLC, parent conferences, coverage, assemblies
- visually distinguish commitments from teaching blocks
- include them in Today and Schedule views
- allow adding and editing them from the schedule builder

Prompt to start this phase:

`Build the Commitments Layer for ClassTrax. Add support for meetings, duties, PLC, conferences, and other non-class events in the same day flow. They should appear in Today and Schedule, look visually distinct from class blocks, and be editable from the schedule-building experience.`

## Phase 3: Day Override Engine

Goal:
Make altered school days fast and obvious.

Screens / files likely touched:

- `ClassTrax/Models/DayOverride.swift`
- `ClassTrax/Views/DayOverridesView.swift`
- `ClassTrax/Views/TodayView.swift`
- `ClassTrax/Views/ScheduleView.swift`
- `ClassTrax/Views/SettingsView.swift`
- schedule calculation helpers / services

Main outcomes:

- support early release, late start, assembly day, testing day, minimum day
- easy override selection
- clear indication that an override is active
- override affects Today, Schedule, notifications, and Live Activity

Prompt to start this phase:

`Build the Day Override Engine for ClassTrax. I need altered day schedules like early release, late start, testing day, assembly day, and minimum day to be easy to activate and visually obvious. The active override should affect Today, Schedule, notifications, and the live classroom experience.`

## Phase 4: School / Personal Separation

Goal:
Help teachers keep school life from bleeding into personal life.

Screens / files likely touched:

- `ClassTrax/Views/SettingsView.swift`
- `ClassTrax/Views/TodayView.swift`
- `ClassTrax/Views/NotesView.swift`
- `ClassTrax/Views/TodoListView.swift`
- notification and reminder behavior

Main outcomes:

- school-only task and note organization
- after-hours quiet mode for school items
- dismissal wrap-up / tomorrow-prep summary
- clearer boundaries between school and personal workflows

Prompt to start this phase:

`Build the School / Personal Separation phase for ClassTrax. I want school tasks, notes, reminders, and notifications to feel intentionally separated from personal life, including after-hours quieting and a dismissal-style wrap-up for unfinished school work.`

## Phase 5: Teacher Task Upgrade

Goal:
Replace a generic todo list with a teacher workflow system.

Screens / files likely touched:

- `ClassTrax/Models/TodoItem.swift`
- `ClassTrax/Views/TodoListView.swift`
- `ClassTrax/Views/AddTodoView.swift`
- `ClassTrax/Views/TodayView.swift`

Main outcomes:

- support task categories like prep, grading, parent contact, copies, meeting follow-up
- support today / this week / later structure
- tie tasks to a class block or commitment when useful
- surface urgent tasks on Today

Prompt to start this phase:

`Build the Teacher Task Upgrade for ClassTrax. Evolve the current todo system into a teacher-specific task workflow with school-relevant categories, better organization for today and this week, and optional links to class blocks or commitments.`

## Phase 6: Fast Capture

Goal:
Let teachers capture things instantly during a busy day.

Screens / files likely touched:

- new quick-capture view(s)
- `ClassTrax/Views/TodayView.swift`
- `ClassTrax/Views/TodoListView.swift`
- `ClassTrax/Views/NotesView.swift`
- widgets / intents later if desired

Main outcomes:

- one-tap quick add
- save for later / remind after school
- optional voice-note capture path
- class-linked quick note entry

Prompt to start this phase:

`Build the Fast Capture phase for ClassTrax. I want extremely fast capture for tasks, reminders, and notes during the school day, including a simple quick-add flow and options like save for later or remind me after school.`

## Phase 7: Class / Student Context

Goal:
Add lightweight instructional context without becoming a full SIS or gradebook.

Screens / files likely touched:

- new models and views for class-linked notes
- `ClassTrax/Views/TodayView.swift`
- `ClassTrax/Views/ScheduleView.swift`
- `ClassTrax/Views/NotesView.swift`

Main outcomes:

- class-specific notes
- reminders tied to a block
- lightweight student/group notes
- accommodations or “remember this for class” prompts

Prompt to start this phase:

`Build the Class / Student Context phase for ClassTrax. I want lightweight class-linked notes and reminders that help with instruction and follow-up, but I do not want to turn the app into a full gradebook or SIS.`

## Phase 8: Calendar / Reminder Integration

Goal:
Connect ClassTrax to the rest of teacher workflow without losing focus.

Screens / files likely touched:

- integration service files
- permissions flow
- `ClassTrax/Views/SettingsView.swift`
- `ClassTrax/Views/TodayView.swift`

Main outcomes:

- optional import of school calendar commitments
- optional reminder sync for school tasks
- keep integration scoped so personal life is not mixed in by default

Prompt to start this phase:

`Build the Calendar / Reminder Integration phase for ClassTrax. Add optional school-focused calendar and reminder integration, but keep it clearly separated from personal life and do not make the app dependent on those integrations.`

## Product Rules

Use these to make decisions during future phases:

- prefer teacher time savings over feature count
- prefer reduced mental load over flashy complexity
- protect school / personal separation
- keep Today as the operational center
- do not turn ClassTrax into a full gradebook, LMS, or SIS

## Notes for Future Sessions

If asking Codex to implement the next phase, mention:

- preserve current teacher display mode
- preserve live timer / hold / extend / skip flow
- preserve schedule profiles and CSV import/export
- build incrementally and validate with project build
