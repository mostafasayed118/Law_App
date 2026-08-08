# Scope DRAFT: Pending Approvals Queue (v1, Read-Only) — 2026-08-09

> **Record type:** SPEC_KIT Template 1 (SPEC) draft for the **v1 queue item**
> `pending_approvals_queue` (`legalhub_specification.md` §6 row 160: marked
> "v1"). **Status: DRAFT — NOT owned, NOT scheduled.** No implementation;
> recording this draft merely makes the design line actionable. Owner:
> Governance (github.com/mostafasayed118).

## Problem
`pending_approvals_queue` is designed (v1) with **no definition of what it
approves**. The product contract (INSTRUCTIONS §4.4) requires human approval
paths for high-risk workflows (filings, waivers, ethical walls) — all of
those are individually DECLARED-deferred (D-06/D-03). The approvals queue
only has meaning once a workflow with a real approval state exists.

## Proposed scope (for owner decision-making)
- **Read-only queue of pending human-approval items**, per org
  (`ActiveOrgStore` context), with viewer/approver = the org's `partner`
  role pattern (server-denied otherwise).
- Item list: entity type + attribution + status; no content/credentials
  (redacted-only, §8 discipline).
- States: loading / loaded / empty / **denied (never empty-success)** /
  error+retry; EN/AR/TR + RTL.

## Out of scope (draft)
- Any write/approve action (the source workflows are deferred); no
  notifications; no non-reader roles; no export.

## Open questions (owner)
1. Approve-**of-what** source? (None exists until D-06 workflows unblock.)
2. Demo-data queue (universal fake) vs a real server table once source
   workflows ship?
3. Where it lives (org hub / platform admin) and which roles see the entry.

## Acceptance criteria (when approved)
- Distinct denied/loaded/empty/error states; redacted rows only; no actions.

## Note
**This is the lowest-priority v1 queue item** — it is definitionally dependent
on a currently-deferred workflow and may be Parkinson-safe to defer to lazy
planning; owner decision expected either way.