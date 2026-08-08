# Scope: Partner Org-Audit Read Surface (2026-08-09)

> **Record type:** SPEC_KIT Template 1 (SPEC) + Template 2 (PLAN) for the
> **partner-facing org-audit UI** — the recorded follow-up of the fifth §14
> un-deferral (`docs/audit_surfacing_plan_2026-08-08.md` §3/§9 and
> `docs/audit_surfacing_completion_evidence_2026-08-08.md` §3: "a
> partner-facing org-audit screen is a recorded follow-up"). **Docs-only
> planning — zero dev-project effect**: nothing here changes the applied
> schema, RLS, RPCs, or the permission matrix (the §6 row already covers the
> partner cell; the dated §6 addendum this commit adds is a consummation
> note, not a grant).
>
> **Gate state (why this slice is now plannable):** `read_org_audit(p_organization_id)`
> is **already committed, rehearsed, and APPLIED to the dev project on
> 2026-08-01** and **partner-capable server-side** (its in-RPC gate denies
> non-partner/non-org actors with `permission denied` — the applied-engine
> test surface pinned it in the harness battery §1d). The platform-admin
> screen (`docs/audit_surfacing_plan_2026-08-08.md` T2–T5) already consumes
> it for the owner-side org selector; **this slice ships the same RPC's
> partner-facing surface** (`View.memberships`-scoped, active-org context per
> D-08). No schema change, no new RPC, no battery edit, no rehearsal, no
> apply — a client-only slice on the existing org seam pattern.
>
> **Status: DRAFT (2026-08-09).** Owner: Project Owner
> (github.com/mostafasayed118).
>
> **Governed by:** `docs/permission_matrix.md` §6 (audit rows, dated-addendum
> discipline §7) · `docs/audit_surfacing_plan_2026-08-08.md` (the recorded
> follow-up + D-AUD1 "read-only, no export") · `INSTRUCTIONS.md` §2.1/§3 (slice
> gate) · the P3.5 precedent (`docs/p3_5_completion_evidence_2026-08-05.md`,
> AC-7 denied-never-empty).

## Problem

`read_org_audit` is partner-capable but its only client surface is the
owner-only platform-admin screen. A partner (the org's overseeing role,
permission matrix §3) has no in-product view of their org's redacted audit
trail — the matrix's "Read the audit table — scope-checked per reader" row is
only half-consummated on the client (owner first surface; the recorded
partner follow-up is unimplemented).

## Goal

A partner-gated, read-only org-audit surface: the active org's redacted
audit trail (server-redacted fields only), with loading / loaded / empty /
**denied (never empty success)** / error+retry states, EN/AR/TR + RTL,
light/dark, and no export affordance.

## User story

As a partner, I want to view the audit trail of my active organization, so
that I can review attributable, redacted change records without leaving the
app — and see a distinct denial when my role is not permitted.

## In scope

- `OrganizationGateway.readOrgAudit({organizationId})` +
  `SupabaseOrgApi`/impl RPC call + fake mirror (partner-rows / denied /
  honest-empty for other org ids).
- `RoleCapability.canViewAudit` navigation hint: **partner only** (UX hint,
  not authorization — the RPC enforces).
- `OrgAuditCubit` (loading/loaded/empty/denied/error) + `OrgAuditScreen`
  (read-only rows: action, outcome, redacted summary, timestamp; no
  raw-`audit_events` SELECT anywhere).
- Hub entry ("Audit trail", partner-gated) + `/organizations/audit` route
  (org derived from `ActiveOrgStore` per D-08).
- l10n EN/AR/TR + RTL; light/dark.

## Out of scope

- Read: export, filters, pagination beyond one list, platform-wide audit,
  compliance-officer access, live refresh. Writes: nothing.
- Server/RPC/RLS/matrix changes — `read_org_audit` and the matrix row
  already exist; the §6 addendum merely records this surface's ship date.
- Moving `AuditEntry` out of `core/admin` (recorded as follow-up candidate).

## Acceptance criteria

1. GIVEN a partner of org-a, WHEN the org-audit screen loads, THEN the
   server-redacted trail renders (action/summary/outcome/timestamp; no
   content/credentials) WITHOUT any export affordance.
2. GIVEN the same partner, WHEN the trail is empty, THEN an honest empty
   state renders (distinct from denied).
3. GIVEN a non-partner (client/attorney/compliance officer) or a cross-org
   access attempt, WHEN the screen loads, THEN the **distinct denied state**
   renders — never empty-success (AC-7).
4. GIVEN a failed fetch, WHEN retry is tapped, THEN the load re-issues and
   the result replaces the error.
5. GIVEN any locale en/ar/tr, WHEN rendering, THEN strings resolve and the
   layout mirrors (RTL) — l10n resolution pins.
6. GIVEN a non-audit-capable role, WHEN on the org hub, THEN no audit entry
   is visible (nav hint; the server still denies.

## Test plan

- Gateway/impl mapping (RPC column shape, denied → `OrgFailureKind.denied`,
  empty, unavailable, unknown).
- Fake mirror: partner-of-org-a → rows; foreign/cross-org → denied;
  no-org → honest empty.
- Cubit `blocTest`: initial/loading/loaded/empty/denied/error + retry
  re-issue + duplicate-submit guard.
- Widget: listed rows (redacted-only pins), no-export pin, empty, denied
  message, error-retry, hub entry presence/absence per capability, RTL.
- l10n pins in `app_localizations_test.dart`.
- Router: `/organizations/audit` builds under the shell.

## Ledger hooks

README test-count + implemented-foundation lockstep after the code slices ·
roadmap §2 row for `read_org_audit` ("partner-org audit UI", if present)
reconciled · ledger PASS on every commit.