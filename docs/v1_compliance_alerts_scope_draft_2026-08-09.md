# Scope DRAFT: Compliance Alerts (v1, Read-Only) — 2026-08-09

> **Record type:** SPEC_KIT Template 1 (SPEC) draft for the **v1 queue**
> (spec §4 "v1 (after MVP)": compliance alerts, including `legalhub_specification.md`
> §6 row `compliance_alerts` — deferred to v1 read-only). **Status: DRAFT —
> NOT approved, NOT scheduled.** Deciding this record does not advance any
> §14 gate without a separate dated decision + the server surface existing.
> Owner: Project Owner (github.com/mostafasayed118).

## Problem
`compliance_alerts` is designed (spec §6 row 168: "Deferred → v1 read-only")
but has no implementation, no server dataset, no matrix row, and no owner
decision. Building it now would be a slide without a contract.

## Proposed scope (for owner ratification; NOT engineering approval)
- **Source of truth:** none today — the applied schema has no alerts table,
  RLS policy, or RPC. A read-only surface needs a server slice first
  (or an explicit "synthetic demo only" posture like the Phase 6–12
  fakes).
- **UI (if read over demo data):** list of compliance events with
  status + text/icon semantics (INSTRUCTIONS §4.5 — never color alone),
  EN/AR/TR + RTL, light/dark; no export, no actions (read-only).
- **Entry:** org hub or matter dashboard? — `ActiveOrgStore` context
  (D-08 discipline).

## Out of scope
- Writes, escalation, notifications, real compliance verification, any
  regulatory claim (INSTRUCTIONS §1.2/§4.4).

## Open questions (owner)
1. Demo-fake surface (Phase 6–12 pattern) vs server slice first?
2. Which roles see the entry (nav hint only)?
3. Where does the entry live (hub vs dashboard)?

## Acceptance criteria (whenever approved)
1. Read-only alerts render with text+icon status (no color-only).
2. Denied/empty/error states are distinct (AC-7 pattern).
3. EN/AR/TR + RTL, a11y, no export.

## Non-goals
- No real filing/verification/compliance claim; no write paths; no §14
  un-deferral without a separate dated gate.