# Plan: Audit Surfacing — the fifth §14 per-feature un-deferral (2026-08-08)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> fifth slice under the roadmap §14 blanket-deferral, mirroring the
> **matters**, **documents**, **messages** and **storage** slices (plans
> `docs/{matters,documents,messages,storage}_real_data_plan_2026-08-08.md`,
> the first four un-deferrals) — the same per-feature discipline applied to
> **audit surfacing**: the last two unwired RPCs (`read_org_audit`,
> `read_platform_audit`) gain their first client surface. **Docs-only
> planning — zero dev-project effect**: nothing in this document applies
> anything to the dev Supabase project; every external step stays behind the
> owner's dated approval (INSTRUCTIONS.md §2.1/§5 hard gates).
>
> **Gate state (why this slice is now plannable — and why it is the
> LOWEST-risk remaining path):** the audit RPCs are **already committed,
> rehearsed, and APPLIED to the dev project on 2026-08-01** (P2-reviewed;
> backout `rpc/_down.sql`), and both are **already pinned in the harness
> battery's §1d RPC-EXECUTE list** (`read_org_audit(uuid)`,
> `read_platform_audit()` — `scripts/verify_policy_tests.sh` 1d, verified
> 2026-08-08). The §14 gate for this slice therefore collapses to: a dated
> matrix §6 addendum (§7 discipline, client-surface widening) + the
> env-gated client swap on the **existing P3.5 platform-admin seam**
> (`SupabasePlatformAdminApi`/`Gateway`/fake + `PlatformAdminScreen`) — the
> closest precedent is P3.5 itself (`docs/p3_5_completion_evidence_2026-08-05.md`),
> which shipped the owner-only RPCs' first consumer. **No schema change, no
> new RPC, no battery edit, no rehearsal, no apply** — the four server-heavy
> slices' T1–T5 machinery is already done for this one.
>
> **Why audit surfacing over the other three remaining paths (realtime,
> billing, AI) — the §14 reconciliation, 2026-08-08:** the remaining
> deferred list is **realtime, audit surfacing, billing, AI** (roadmap §14).
> - **Audit surfacing** — server side 100% done + applied + battery-pinned;
>   the only missing work is a client surface. **Picked.**
> - **Realtime** (message bodies / individual `messages` rows / live
>   delivery) — the forward pin narrowed to `('messages')` in the 4th slice;
>   needs a new `messages` table + RLS + battery + rehearsal + apply + a
>   thread-detail client surface (currently body-less by D-MSG1). Highest
>   value of the remainder but the largest remaining lift; natural follow-up
>   AFTER this slice (it reuses the same P3.5-adjacent messaging seam
>   discipline and the now-proven four-slice pipeline).
> - **Billing** — gated on D-09 (no live payment in MVP); external payment
>   provider decisions; not a read-metadata slice. Stays deferred.
> - **AI** — no matrix rows, no spec basis beyond the roadmap list; product
>   scope undefined. Stays deferred.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Give the **platform owner** (and, at the RPC level, a **partner of an org**)
a read-only **audit trail surface** behind the two already-applied,
battery-pinned audit RPCs — closing the unwired-RPC inventory from 16-of-18
to **18-of-18** (roadmap §2). "Done" = the `PlatformAdminScreen` (P3.5,
owner-only) gains an **Audit section** that renders the platform audit
(`read_platform_audit()`) and the per-org audit for the selected org
(`read_org_audit(org_id)`), each a redacted, metadata-only list (the RPCs
already return `redacted_summary` + correlation ids — no credentials or
content by contract §8); the env-less demo and the whole test suite still
run on the dev fake; non-owners and unauthenticated readers are denied with
a **distinct denied state** (P3.5 AC-7: never empty-success); the matrix §6
"Read the audit table" row gains its dated addendum (§7 discipline) before
the client surface ships.

## 2. Gap (verified)

- **Unwired-RPC inventory (roadmap §2, 2026-08-08):** 16 of 18 RPCs have a
  client surface. The 2 without one are exactly `read_org_audit` and
  `read_platform_audit`, each annotated "deferred (§14) — audit surfacing is
  P2-gated". Everything else (owner-only RPCs, member-facing RPCs) shipped a
  consumer in P3.5/Phase 2.
- **Server side is done (verified, not assumed):** `supabase/rpc/read_org_audit.sql`
  (org-scoped: `id, action, outcome, resource_type, resource_id,
  correlation_id, redacted_summary, server_timestamp` — "Partner of the org
  reads that org's audit rows only; the listing is itself audited") and
  `read_platform_audit.sql` (`platform_owner_admin`-only cross-org read: adds
  `actor_user_id`, `organization_id` — "the owner's own read is audited with
  the owner actor; owner is not audit-exempt"). Both REVIEWED & APPLIED
  (dev project, 2026-08-01); backout `rpc/_down.sql`; both in the battery §1d
  `rpc_list` (authenticated EXECUTE pinned).
- **No client surface exists for either RPC.** The P3.5 platform-admin seam
  (`lib/data/admin/supabase_platform_admin_api.dart` seam:
  `listOrganizations`, `listMembers`, `suspendMembership`, `reactivateMembership`,
  `deleteDemoAccount`; impl `_rpc` helper; `supabase_platform_admin_gateway.dart`;
  `fake_platform_admin_gateway.dart`; `PlatformAdminCubit`/`PlatformAdminScreen`
  with two metadata sections — organizations + members) has **no audit
  methods and no audit section**. The seam + screen are the natural host:
  owner-only route (`/platform-admin`), denied-state pattern already shipped.
- **Matrix row exists, ungranted-to-client:** matrix §6 "Read the audit
  table — Scope-checked per reader's role; audit table is never publicly
  readable, and `platform_owner_admin` reading it is itself an audited
  action". The RPCs are the enforcement (D-P0C4: audit-RPC-only, no raw
  SELECT). No dated addendum yet records a client surface — this slice ships
  that addendum (§7 discipline) **before** the client swap, per the four
  prior slices' ordering.
- **No other consumer pressure:** the platform-audit list has no existing
  screen slot; the Audit section is additive to the P3.5 screen (third
  metadata section), consistent with the D-W5 section pattern on
  `MatterDetailsScreen`.

## 3. Design decisions (D-AUD1…D-AUD6 — recommended path, ratified by autonomy 2026-08-08 per the pair-programming grant; each is a one-line-reasoned choice, owner may amend)

| # | Decision | Recommendation | Why / alternative |
|---|---|---|---|
| D-AUD1 | **Read scope** | **RPC-only, metadata-only, read-only**: the client renders `read_platform_audit()` rows (owner) + `read_org_audit(org)` rows for the selected org (owner-scoped at the surface; the RPC itself is partner-scoped server-side). Rows are `id/action/outcome/resource_type/resource_id/correlation_id/redacted_summary/server_timestamp` (+ `actor_user_id`, `organization_id` on the platform variant). **No raw `SELECT` on `audit_events` ever** (D-P0C4); no export, no delete, no drill-through | The RPCs are the only auditable read path (a raw SELECT policy cannot audit a read); redaction is server-enforced |
| D-AUD2 | **Client host** | **Extend the P3.5 platform-admin seam + screen** (`SupabasePlatformAdminApi` + impl + gateway + fake gain `readPlatformAudit()` + `readOrgAudit(orgId)`; `PlatformAdminScreen` gains an **Audit section** after Members). No new route, no new cubit — the existing `PlatformAdminCubit`/state machine gains an audit load | Consumer-attached, never a shelved headless layer (D-B7 lesson); owner-only route already gates it |
| D-AUD3 | **VO shape** | New `AuditEntry` VO in `lib/features/admin/domain/` (mirroring the RPC columns: `id` (int), `action`, `outcome`, `resourceType`, `resourceId` (String? — raw-id fallback), `correlationId` (String?), `redactedSummary`, `serverTimestamp` (DateTime); platform variant adds `actorUserId` (String?), `organizationId` (String?)). No PII field names, no content | Faithful to the RPC contract; guard every cast at the gateway (documents/messages T7 pattern) |
| D-AUD4 | **Failure mapping** | Reuse the `SupabasePlatformAdminException` kinds (`denied` / `providerUnavailable` / `unknown`) + `OrgOutcome` (`PlatformAdminGateway` return shape). A denied read renders the **existing `PlatformAdminDenied` state** (P3.5 AC-7: non-owner → distinct denied, never empty-success) | Symmetric with the shipped P3.5 mapping; the owner-only RPCs deny non-owners server-side |
| D-AUD5 | **Fake + demo** | `FakePlatformAdminGateway` gains deterministic synthetic non-PII audit rows (e.g. `member_invited`, `organization_created`, `role_changed` with redacted summaries + correlation ids; 5 platform + 3 per-org). Env-less runs and ALL tests keep the fake | Phase 8 fake pattern; the real path is inert until a configured build exists |
| D-AUD6 | **Matrix + docs ordering** | A **dated matrix §6 addendum** (client-surface widening per §7) is committed **before** the client swap; then the swap; then roadmap §14 flip + §13 gate-table row + evidence record + close (the four-slice T8 pattern). No push | Matches matters/documents/messages/storage ordering; ledger sweep on every docs commit |

**Non-decisions (flagged, not guessed):** realtime audit push / live
delivery (§14 realtime stays deferred — a future slice with a new
`messages` table + RLS + battery + apply); billing (D-09); AI (no scope);
audit **export/archive** UX; per-org audit UI for **non-owner partners**
(the RPC is partner-capable, but the first surface is owner-only on the
platform-admin screen — a partner-facing org-audit screen is a follow-up
behind the same methods).

## 4. Layers touched

- **Client (env-gated, extending P3.5):** `lib/data/admin/supabase_platform_admin_api.dart`
  (seam gains `Future<List<Map<String, dynamic>>> readPlatformAudit()` +
  `readOrgAudit(String organizationId)`), `supabase_platform_admin_api_impl.dart`
  (two `_rpc` calls), `supabase_platform_admin_gateway.dart` (guarded row→VO
  mapping + failure mapping on the existing `OrgOutcome`), `fake_platform_admin_gateway.dart`
  (deterministic non-PII audit rows), `lib/features/admin/domain/audit_entry.dart`
  (new VO), `lib/features/admin/presentation/platform_admin_cubit.dart` +
  `platform_admin_screen.dart` (Audit section — third metadata section),
  `lib/app/service_locator.dart` (no registration change — the seam already
  flips behind `env.isConfigured`; the new methods ride the existing
  registration), 3 `.arb` + generated l10n (`auditSectionTitle`,
  `platformAuditTitle`, `orgAuditTitle`, `auditEmpty`, `auditError` ×3
  locales).
- **Docs:** dated matrix §6 addendum (the "Read the audit table" row —
  client surface shipped behind the two RPCs, owner/partner scope,
  redacted-only, never raw SELECT), roadmap §14 fifth flip + §13 gate-table
  row, README lockstep, completion evidence `docs/audit_surfacing_completion_evidence_<date>.md`.
- **Not touched:** `supabase/` (no migration/policy/RPC/battery edits — the
  RPCs are applied and battery-pinned already), any other feature's VO or
  presentation.

## 5. State shape / data flow

- **State shape:** `PlatformAdminCubit` (existing) gains an audit load —
  either a third `OrgOutcome` in `PlatformAdminLoaded` or a parallel
  section-local fetch on the Audit section (decided at T4, mirroring the
  `MatterDetailsScreen` sections' per-section state). `PlatformAdminDenied`
  / `PlatformAdminFailed` reused verbatim.
- **Data flow (configured build):** `PlatformAdminScreen (owner) → Audit
  section → PlatformAdminGateway (Supabase impl) → rpc('read_platform_audit')
  / rpc('read_org_audit', {p_organization_id}) → rows → AuditEntry VO
  (guarded casts) → list`. One round-trip per list, no new surface; the
  server re-scopes each read (owner-only platform; org-scoped org audit).

## 6. Dependencies

- **Server:** the two audit RPCs (already applied 2026-08-01, battery-pinned
  1d). Nothing new to apply; no rehearsal/apply gate in this slice.
- **Client:** the P3.5 platform-admin seam + screen + fake (all shipped
  `47f777b`..`06d78a7`); `OrgOutcome` + `SupabasePlatformAdminException`
  already exist.
- **Infra:** none new — env-less runs and the full Flutter suite use the
  fake; the real path is inert until a configured build exists.

## 7. Testing strategy

- **Dart unit:** `SupabasePlatformAdminGateway` mapping for both audit
  methods (guarded casts on every column — id int, timestamps parse,
  nullable resourceId/correlationId/actorUserId/organizationId; malformed
  rows → typed FormatException, never a raw TypeError — the documents/messages
  T7 baseline); failure mapping incl. `denied` → `OrgOutcome.denied` (the
  AC-7 distinct-denied path) and `providerUnavailable`; impl columns-pin for
  both `_rpc` calls (`read_platform_audit` no params; `read_org_audit` with
  `p_organization_id`).
- **Fake determinism:** `FakePlatformAdminGateway` audit rows — fixed count,
  non-PII, correlation ids present, timestamps fixed.
- **Cubit/widget:** `PlatformAdminCubit` audit load emissions
  (loading → loaded/denied/failed); `PlatformAdminScreen` Audit section
  renders platform + org lists env-less, empty state, denied state
  (non-owner → `PlatformAdminDenied`, never empty-success), error-retry.
- **DI pins:** `service_locator_test` unchanged registration (the fake is
  still the env-less impl; the new methods ride the existing seam) — add a
  pin that the registered `PlatformAdminGateway` exposes the audit methods.
- **Not claimed:** no live dev-project read until a configured build exists;
  no realtime push (deferred); no partner-facing org-audit UI (follow-up).

## 8. Acceptance criteria

- [ ] The **platform audit** (`read_platform_audit()`) and **per-org audit**
      (`read_org_audit(org_id)` for the selected org) render as a read-only,
      redacted, metadata-only list on the owner-only platform-admin screen
      (audit section, third after members).
- [ ] **Denied, never empty-success:** a non-owner (or unauth) reader sees
      the distinct `PlatformAdminDenied` state — the server-side owner-only
      deny maps to a typed denial (P3.5 AC-7), not an empty list.
- [ ] **Redaction holds client-side:** the VO renders only the RPC's
      redacted fields (no credentials/content); no raw `SELECT` on
      `audit_events` anywhere in the client.
- [ ] Env-less runs and the full Flutter suite unchanged (fake); the real
      path is inert until a configured build exists.
- [ ] Dated matrix §6 addendum (client-surface widening, §7 discipline)
      precedes the client swap; roadmap §14 gains the fifth per-feature flip;
      §2 unwired-RPC inventory reads **18-of-18**; README count in lockstep;
      ledger PASS.
- [ ] Full gate on every client slice: format clean · analyze clean · suite
      green · ledger PASS — nothing pushed.

## 9. Risks / open questions

- **Scope creep guard:** the Audit section is additive to an existing
  owner-only screen — no new route/capability; the denied-state pattern is
  already shipped. Watch: don't pull in partner-facing org-audit UX or
  export into this slice (both flagged non-decisions).
- **Row-shape drift:** the RPC return columns are fixed and applied; the
  mapping guards every cast (nullable ids), so a future RPC amendment fails
  loudly in tests, not silently in the UI.
- **Redaction trust:** the client renders server-redacted fields only; if a
  future RPC adds a sensitive column, the gateway's explicit field list
  keeps it out by construction (no pass-through mapping).
- **Infra:** none — no rehearsal/apply host needed (the RPCs are already
  applied; this slice is client + docs only).

---

# Tasks: Audit Surfacing

Branch: `main` (client-only slice; no feature branch needed unless the owner
prefers one — the four prior slices used branches for the server-heavy T1–T6,
but this slice has no server artifacts).

Each task is independently committable with the stated verification; **no
owner-gated server step exists in this slice** (the RPCs are applied) — the
only dated gate is the matrix §6 addendum ordering (T1) and the final push.

- [x] **1. Dated matrix §6 addendum** — touches: `docs/permission_matrix.md`
  — adds the client-surface widening for the "Read the audit table" row
  (owner platform audit + per-org audit behind `read_platform_audit` /
  `read_org_audit`, redacted-only, never raw SELECT, D-P0C4 holds; partner
  org-audit UI stays a follow-up) — done when: addendum committed with the
  §7 date/place discipline, ledger sweep green. — **DONE (this commit)** —
  placed chronologically after the storage §6 addendum; records the two
  applied + battery-pinned RPCs as the row's enforcement, owner-only first
  surface, redacted-only + D-P0C4 + non-owner-denied (AC-7); widens no
  other row.
- [x] **2. Seam + impl + gateway audit methods** — touches:
  `lib/data/admin/supabase_platform_admin_api.dart` +
  `supabase_platform_admin_api_impl.dart` + `supabase_platform_admin_gateway.dart`
  — done when: both methods exist with guarded row→VO mapping + failure
  mapping on `OrgOutcome` (denied/providerUnavailable/unknown), mapping +
  impl-columns tests green. — **DONE (this commit)** — seam gains
  `readPlatformAudit()`/`readOrgAudit(orgId)` + `providerUnavailable` kind;
  impl calls `read_platform_audit` (no params) / `read_org_audit`
  (`p_organization_id`) with the defensive `on Object` → unavailable catch
  (auth/storage precedent); gateway maps rows → [AuditEntry] with every cast
  guarded (FormatException, never a raw TypeError) and maps
  denied/providerUnavailable/unknown onto `OrgFailureKind`.
- [x] **3. VO + fake** — touches: `lib/core/admin/audit_entry.dart` (next to
  the gateway it feeds — the plan sketch's `features/admin/domain/` path was
  corrected to keep core→core layering) + `fake_platform_admin_gateway.dart`
  — done when: VO props-pin + fake determinism/non-PII tests green.
  — **DONE (this commit)** — 5-row platform + 3-row org deterministic
  non-PII trails (`audit-*` correlation ids, fixed UTC timestamps,
  metadata-only summaries); owner gate → rows, non-owner → denied
  (never empty), foreign org id → honest empty trail.
- [x] **4. Audit section UI** — touches: `platform_admin_cubit.dart` +
  `platform_admin_screen.dart` + 3 `.arb` + generated l10n — done when:
  widget/cubit tests (platform + org lists, empty, denied-never-empty,
  error-retry) + l10n pins green. — **DONE (this commit)** — the Audit
  section renders the platform trail on mount (section-local `loadAudit`,
  the matter-sections pattern hosted on the existing cubit per D-AUD2),
  an org selector drives `selectAuditOrg` for the per-org trail; a denied
  read flips the whole surface to `PlatformAdminDenied` (AC-7, never
  empty-success), a non-denial failure renders inline with retry so the
  loaded lists survive; rows are redacted metadata only (contract §8),
  read-only; `platformAdminAudit`/`platformAdminAuditPlatform` ×3
  locales. — suite 986 runtime / 983 declared, ledger PASS 115 (reviewer
  finding: load() never carries an in-flight audit flag forward — the
  remounted section re-triggers its own fetch).
- [x] **5. Lockstep + evidence + close** — touches: README test count,
  roadmap §14 fifth flip + §13 gate-table row + §2 unwired-RPC inventory
  → 18-of-18, completion evidence `docs/audit_surfacing_completion_evidence_2026-08-08.md`,
  dated close decision — done when: all docs sweep green, full gate re-run
  on the committed state, close decision recorded. — **DONE (this
  commit)** — README 983 in lockstep; roadmap §14 flip note (fifth
  un-deferral, client-only, RPCs already applied 2026-08-01) + §13
  gate-table row + §2 inventory now reads **18-of-18** (both audit rows
  ❌ → ✅ with `readOrgAudit`/`readPlatformAudit`); evidence record
  (`docs/audit_surfacing_completion_evidence_2026-08-08.md`) captures the
  gate (analyze clean, suite 986 runtime / 983 declared, ledger PASS 115)
  and the reviewer-finding resolutions incl. the auditLoading-carry race;
  dated close decision recorded in the evidence §9.
