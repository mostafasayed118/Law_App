# SPEC_KIT.md — Flutter Spec-Driven Development Kit

A lightweight version of the spec-kit workflow (spec → plan → tasks → implement),
adapted for solo Flutter development with Claude as mentor/pair programmer.
There are no slash commands here — just copy the relevant template or prompt
into the chat and fill in the blanks.

**Why bother with this for a solo project:** it forces the same discipline
`INSTRUCTIONS.md` already asks for (explain before code, no silent decisions) —
these templates just give that discipline a fixed shape so nothing gets skipped
under time pressure.

---

## How the workflow fits together

1. **Specify** — describe *what* the feature does and for whom, no implementation talk. → `SPEC` template
2. **Plan** — turn the spec into an architecture plan: layers touched, state shape, data flow. → `PLAN` template
3. **Tasks** — break the plan into small, independently-committable steps. → `TASKS` template
4. **Implement** — work the task list one item at a time, each one following the Section A contract (explain → plan → approve → implement → walkthrough).

Skip straight to a prompt from the library below for anything smaller than a
full feature (a bug fix, a review, a single decision).

---

## Template 1 — SPEC (what & why, not how)

```markdown
# Spec: <feature name>

## Problem
What's broken or missing right now? Who hits this?

## Goal
What does "done" look like, in one or two sentences?

## User story
As a <user type>, I want <capability>, so that <outcome>.

## Acceptance criteria
- [ ] ...
- [ ] ...

## Out of scope
Explicitly list what this feature does NOT cover, to stop scope creep.

## Edge cases to handle
- Empty state:
- Error/offline state:
- Loading state:
```

## Template 2 — PLAN (architecture, before code)

```markdown
# Plan: <feature name>

## Layers touched
- Presentation:
- Domain:
- Data:

## New/changed files
| File | Layer | Responsibility |
|------|-------|-----------------|

## State shape (Cubit/State)
What does the state class look like? Loading/Success/Error/Empty variants?

## Data flow
User action → Cubit method → UseCase → Repository → DataSource → back up.
(One line per hop is enough — call out anything that breaks this flow and why.)

## Dependencies
Any new package? Justify: why now, alternatives considered, can it be deferred.

## Testing strategy
What gets a unit test, what gets a widget test, what's skipped and why.

## Risks / open questions
Anything genuinely uncertain — flag it here instead of guessing silently.
```

## Template 3 — TASKS (small, sequential, committable)

```markdown
# Tasks: <feature name>
Branch: `feat/<short-description>`

- [ ] 1. <task> — touches: <files> — done when: <verification>
- [ ] 2. ...
- [ ] 3. ...

Each task should be small enough to explain in one learning walkthrough.
```

---

## Prompt library (expert-level, ready to paste)

### New feature kickoff
```
I want to build: <one-line description>.
Walk me through Section A's process for this: problem, plan (files touched,
alternatives), then wait for my approval before implementing. Use the SPEC
and PLAN templates from SPEC_KIT.md to structure your answer.
```

### Code review
```
Review <file(s)/PR> against INSTRUCTIONS.md — specifically Clean Architecture
layer boundaries, widget discipline (Section D.7), and error handling
(Section D.4). Call out anything that violates a "YOU MUST FOLLOW" rule
separately from style nitpicks. Don't rewrite the code — tell me what's wrong
and why, then let me decide the fix.
```

### Bug investigation
```
Bug: <symptom, repro steps, expected vs actual>.
Find the root cause first — don't propose a fix yet. Once you're confident,
explain the cause, propose the smallest fix that addresses it (not a
refactor), and tell me what test would have caught this.
```

### Refactor proposal
```
I think <file/module> needs a refactor because <reason>. Before touching
anything: is this actually needed now, or is it premature (Section B.2 /
C.2 in INSTRUCTIONS.md)? If it's needed, propose the smallest version that
solves the real problem, and name the branch per Section D.2.
```

### Architecture decision (ADR-style)
```
Decision needed: <e.g. "GoRouter vs manual Navigator for X">.
Lay out 2-3 options, the tradeoffs of each against this project's stack and
scale, and your recommendation with reasoning — not just "best practice."
Flag if this is a "let's revisit later" decision vs a load-bearing one.
```

### PR description generator
```
Write a PR description for the changes in <branch/diff>: what changed, why,
how it was verified (tests run, manual check). Keep it short enough that
someone reviewing could actually read it, per Section F PR Discipline.
```

### Test suite for a Cubit/UseCase
```
Write tests for <Cubit/UseCase name> covering: initial state, each state
transition, and the error path. Use bloc_test/mocktail per Section E and
I-1. One behavior per test case — no combined "does everything" tests.
```

### Dependency evaluation
```
I'm considering adding <package> for <need>. Check Section G/D.3: is there
already a way to do this without a new dependency? If not, is <package>
latest-stable and well-maintained? What's the fallback if we don't add it?
```

### Pre-commit safety check
```
Before I commit: review the diff for anything that shouldn't go into a
public repo per Section F "Public Repo Safety" — secrets, local paths,
generated junk, `.env`/keystores. Flag anything suspicious before I push.
```

### Learning walkthrough (on demand, if I skipped it earlier)
```
Give me the learning walkthrough for the last change we made: problem
solved, data flow through the layers, Flutter/Dart concepts used, what each
file owns, what was tested, current limitations, and 3-5 self-check
questions.
```
