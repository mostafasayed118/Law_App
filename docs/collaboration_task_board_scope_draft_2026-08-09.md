# Scope DRAFT: Collaboration Task Board (v1) — 2026-08-09

> **Record type:** SPEC_KIT Template 1 (SPEC) draft for the **v1 queue item**
> (`legalhub_specification.md` §10 "v1 (after MVP): collaboration task board /
> shared workspace", row 160). **Status: DRAFT — NOT owned, NOT scheduled.**
> Listing it here does not advance it any row; a dated owner decision +
> server surface are required first. Owner: Governance
> (github.com/mostafasayed118).

## Problem
`collaboration_task_board` is designed (spec §6) but unstarted; the
"shared_case_workspace" MVP scope was satisfied by the Phase 10 per-matter
view (client-only), a task board is a new surface with an undefined
data contract (no tasks table, RPC, or RLS).

## Proposed scope (for owner decision-making)
- **Server:** needs a task/columns dataset (new slice — schema + RLS +
  matrix addendum + battery) OR explicit fake-only posture.
- **UI:** per-matter task board (matters + workspaces exist), columns/
  statuses, read-only first (read/write is a second slice); EN/AR/TR,
  empty/error/denied states.

## Out of scope (this draft)
- Notifications, real-time sync, deck dependencies, cross-org boards.

## Open questions (owner)
1. Fake-domain demo (Phase 6–12 pattern) vs real server table slice first?
2. Per-matter scope only (matter must exist — Phase 10 `matterRef` pattern)?
3. Capability hint / roles for entry (`canViewMatters` reuse)?

## Acceptance criteria (when approved)
- Statuses never color-only; loading/empty/error/denied distinct; EN/AR/TR.

## Non-goal
- No realtime/notifications until a separate §14-style gate + decision.