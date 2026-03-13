# ClassCue Build Plan V2

This document updates the earlier build plan to reflect the product direction that has emerged in the app:

- a unified teacher workspace
- a teacher-first daily command center
- stronger class and student context
- support for different teaching personas without becoming a full SIS or LMS

## Product Direction

ClassCue should become a unified teacher workspace with specialized lenses for the teachers who need it most:

1. Elementary classroom teachers
2. Secondary "nomad" teachers
3. SPED specialists

The product should still stay grounded in the current strengths of the app:

- schedule and bell execution
- classroom timer and live day flow
- teacher tasks and quick capture
- class notes and student context
- school/personal boundaries

## We Have

These are already implemented or meaningfully underway.

- Teacher command center on Today
- Runtime classroom controls like hold, extend, and skip bell
- Schedule builder, profiles, and CSV import/export
- Teacher task workflow with categories, buckets, and linking
- Quick capture from key surfaces
- Notes broken into General, Class Notes, and Student
- Student directory with supports, contacts, class, grade, and graduation year
- Student support surfacing in Today, tasks, and capture flows
- Quiet-hours / school-boundary foundation

## We Need

These fit the current scope and represent the best next investments.

- Finish Day Override Engine
- Finish Teacher Task Upgrade
- Finish Fast Capture
- Finish Class / Student Context
- Student directory and roster polish
- Sub-plan toolkit
- Elementary student-facing classroom mode
- Secondary logistics tools
- Wellness guardrail expansion
- Offline-first behavior

## Out Of Scope

These do not fit the near-term scope or would turn ClassCue into the wrong product.

- Full SIS replacement
- Full LMS replacement
- Full gradebook
- Full parent messaging platform
- AI-written compliance documents as a core feature
- Behavioral heatmaps as a major analytics product
- Automatic geolocation room switching
- Direct dependency on a school SIS
- Photo-based parent story system as a current priority

## Persona Priority

The best-fit order for product depth is:

1. Elementary classroom teacher
2. Secondary nomad teacher
3. SPED specialist

Why:

- Elementary is the strongest fit for the current timer, routine, and classroom-flow DNA.
- Secondary is a strong extension once class filters, room context, and split planning mature.
- SPED is important, but it requires careful compliance-oriented depth after the data and context foundation is stronger.

## Current Feature Status

### 1. Day Override Engine

Status: Partial

In place:

- override model and management UI
- named override types
- active override resolution for today
- Today and Schedule reflecting active overrides
- stronger override status treatment
- current-day override notification behavior

Still needed:

- better preset workflows
- future-date override notification handling
- override-aware commitments
- smoother activate/edit/clear flow

### 2. School / Personal Separation

Status: Started

In place:

- quiet-hours settings
- some boundary messaging on Today
- task carryover to tomorrow
- basic end-of-day awareness

Still needed:

- deeper school-only separation for notes/tasks
- stronger dismissal wrap-up
- clearer "school day is done" mode
- more complete after-hours behavior

### 3. Teacher Task Upgrade

Status: Partial, but advanced

In place:

- teacher-specific categories
- buckets like Today, Tomorrow, This Week, Later
- stronger sorting and filtering
- class/commitment linking
- student/group and follow-up fields
- task surfacing on Today
- carryover support

Still needed:

- richer bulk actions
- stronger triage and resurfacing
- deeper grading / meeting / prep workflows
- more powerful task views

### 4. Fast Capture

Status: Partial

In place:

- quick capture from Today, To Do, and Notes
- current/next context prefill
- bucket selection
- note routing by type

Still needed:

- voice capture
- faster one-tap capture flows
- better reminder routing
- lock screen / widget capture paths

### 5. Class / Student Context

Status: Good foundation, still growing

In place:

- student directory with supports and contacts
- class notes and student notes
- class-linked and student-linked tasks
- structured follow-up notes
- class-based support surfacing on Today

Still needed:

- multi-class support matching
- stronger class-linked note workflows
- better student-by-class views
- accommodations surfacing more intelligently

### 6. Calendar / Reminder Integration

Status: Not started

Still needed:

- optional school calendar import
- optional reminder sync
- separation from personal accounts by default

## Phased Build Plan

### Phase 1. Finish Core Teacher Workflow

Goal:
Finish the teacher daily operating system before branching too widely.

Includes:

- complete Day Override Engine
- deepen Teacher Task Upgrade
- deepen Fast Capture
- expand school/personal boundary behavior

### Phase 2. Finish Class / Student Context

Goal:
Make class and student information genuinely operational during the school day.

Includes:

- multi-class student support matching
- stronger class-linked notes
- better student note workflows
- student-by-class views
- better accommodation surfacing in Today and tasks

### Phase 3. Student Directory / Roster Layer

Goal:
Turn the directory into a real roster and support layer.

Includes:

- roster import polish
- export polish
- class and grade organization tools
- duplicate detection / merge behavior

### Phase 4. Classroom Modes

Goal:
Support the live classroom environment more directly.

Includes:

- student-facing visual schedule mode
- stronger elementary routine tools
- interactive display mode

### Phase 5. Sub Plan Toolkit

Goal:
Make substitute prep dramatically easier.

Includes:

- one-tap substitute packet
- schedule + resources + supports bundle
- temporary share/export flow

### Phase 6. Secondary Logistics Layer

Goal:
Help teachers who manage many students, rooms, and grade bands.

Includes:

- split-grade planning
- room-aware quick toggle
- class-specific resource / announcement support
- context-switch tools

### Phase 7. Integrations

Goal:
Connect ClassCue to school systems without making it dependent on them.

Includes:

- school-focused calendar integration
- reminders integration
- scoped LMS/integration work where useful

### Phase 8. SPED-Specific Expansion

Goal:
Layer compliance-aware support on top of the stronger student-context foundation.

Includes:

- structured goal tracking
- data logging
- support for draft-assist workflows
- more specialized SPED surfaces

## Product Rules

Use these rules to protect product quality:

- prefer teacher time savings over feature count
- reduce context switching
- protect school/personal separation
- keep Today as the operational center
- do not turn ClassCue into a full gradebook, LMS, or SIS
- favor offline-capable/local-first workflows

## Best Next Step

The highest bang-for-buck next iteration remains:

- finish Core Teacher Workflow
- continue finishing Class / Student Context

Those two phases strengthen the existing product instead of scattering effort across too many ambitious surfaces at once.
