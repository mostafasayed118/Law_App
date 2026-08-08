# LegalHub — Audit Surfacing Completion Verification & Evidence Record (2026-08-08)

> **Record type:** Slice T5 close-out evidence (plan
> `docs/audit_surfacing_plan_2026-08-08.md`) — the **fifth §14 per-feature
> un-deferral**, records exactly what was **verified** about the audit
> surfacing path (client commits `7b7c1a8` → `b0f9022`, all on `main`, no
> push) and exactly what is **still pending**, with no claim beyond what was
> actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-08 — client surface complete, full gate green on
> `main` (analyze clean, suite 986 runtime / README 983 declaration, ledger
> PASS 115), unwired-RPC inventory now 18-of-18.** This slice was
> **client-only**: the two audit RPCs (`read_org_audit`,
> `read_platform_audit`) were already committed, rehearsed, **applied to the
> dev project on 2026-08-01** (P2-reviewed; backout `rpc/_down.sql`), and
> battery-pinned in the harness §1d RPC-EXECUTE list — so **no schema
> change, no new RPC, no battery edit, no rehearsal, no apply was needed or
> performed**. The dated close decision is recorded in §9, mirroring the
> P0C / P3.1–P3.5 / matters / documents / messages / storage close format.

---

## 1. What this record covers

The audit surfacing **client** path — the last two unwired RPCs gain their
first Flutter surface on the existing P3.5 platform-admin seam — delivered
as plan T1–T5:

| Stage | Artifact | Commit |
|---|---|---|
| T1 — dated matrix §6 addendum (§7 discipline) | `docs/permission_matrix.md` §6 — the "Read the audit table" row's client-surface widening (owner platform audit + per-org audit behind `read_platform_audit` / `read_org_audit`, redacted-only, never raw SELECT, D-P0C4 holds; partner org-audit UI a recorded follow-up) | `7b7c1a8` |
| T2 — seam + impl + gateway audit methods | `lib/data/admin/supabase_platform_admin_api.dart` (+`providerUnavailable` kind) + `supabase_platform_admin_api_impl.dart` (`read_platform_audit` no params / `read_org_audit` `p_organization_id`, defensive `on Object` → unavailable catch) + `supabase_platform_admin_gateway.dart` (guarded row→VO mapping + failure mapping on `OrgOutcome`) | `56414a6` |
| T3 — VO + fake | `lib/core/admin/audit_entry.dart` (new `AuditEntry` VO, redacted-only, contract §8) + `fake_platform_admin_gateway.dart` (deterministic non-PII 5-row platform + 3-row org trails; owner gate → rows, non-owner → denied never empty, foreign org → honest empty) | `56414a6` |
| T4 — Audit section UI | `platform_admin_cubit.dart` (section-local `loadAudit` + `selectAuditOrg`, denied → `PlatformAdminDenied` AC-7, inline error-retry) + `platform_admin_screen.dart` (third Audit section: org-scope dropdown + redacted rows, read-only) + l10n ×3 (`platformAdminAudit`/`platformAdminAuditPlatform`) | `b0f9022` |
| T5 — lockstep + evidence + close | README count lockstep (983), roadmap §14 fifth flip + §13 gate-table row + §2 unwired-RPC inventory → 18-of-18, this record, dated close decision | this commit |

The slice built directly on `main` (client-only — no feature branch was
needed; the four server-heavy slices' branch discipline exists for server
artifacts, which this slice has none of).

## 2. Verified (actually run, 2026-08-08)

### 2.1 Final gate on `main` (post-`b0f9022`, the last code commit; T5 is docs-only and re-swept the ledger)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **986 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 983 in lockstep) |
| `scripts/verify_policy_tests.sh --check` (static battery) | **PASS 331/0/0** (unchanged this slice — no battery edit; the audit RPCs were already pinned in the §1d RPC-EXECUTE list) |

### 2.2 Server-side verification (this slice's server work was ALREADY done — verified, not assumed)

- **The two audit RPCs are applied and battery-pinned** (the reason this
  slice collapses to client-only): `supabase/rpc/read_org_audit.sql`
  (org-scoped: `id, action, outcome, resource_type, resource_id,
  correlation_id, redacted_summary, server_timestamp` — "Partner of the org
  reads that org's audit rows only; the listing is itself audited") and
  `read_platform_audit.sql` (`platform_owner_admin`-only cross-org read:
  adds `actor_user_id`, `organization_id` — "the owner's own read is audited
  with the owner actor; owner is not audit-exempt"). Both **REVIEWED &
  APPLIED (dev project, 2026-08-01)**; backout `rpc/_down.sql`; both in the
  harness §1d `rpc_list` (authenticated EXECUTE pinned) — re-verified in the
  §2.1 static sweep.
- **Matrix addendum (`7b7c1a8`, §7 discipline)** — the "Read the audit
  table" row's dated client-surface widening, placed chronologically after
  the storage §6 addendum and before §7 Sign-off: records the first client
  surface behind the two applied + battery-pinned RPCs, owner-only first
  surface (partner org-audit UI a recorded follow-up), redacted-only
  (contract §8), **D-P0C4 holds (no raw SELECT on `audit_events` ever)**,
  non-owner → distinct denied (P3.5 AC-7, never empty-success), realtime row
  explicitly unchanged, "extends not replaces" per §7, and honest
  "in effect on the client surface ship (T2–T5)" language. Landed **before**
  the client swap (T1 `7b7c1a8` < T2–T4 `56414a6`/`b0f9022`).

### 2.3 Test coverage added by the client surface (+33 declarations, suite 953 → 986 runtime; README 950 → 983)

- `supabase_platform_admin_gateway_test` (+8): full row→VO mapping for both
  variants (id/action/outcome/resourceType/resourceId/correlationId/
  redactedSummary/serverTimestamp + the platform-variant actorUserId/
  organizationId); missing-column + non-int id + **wrong-typed nullable uuid
  drift** (the reviewer-flagged gap — a uuid column arriving non-string is a
  typed `FormatException` via the `_optionalString` guard, never a raw
  `TypeError`); denied / providerUnavailable / unknown `OrgFailureKind`
  mapping (both variants).
- `supabase_platform_admin_api_impl_test` (+4): both `_rpc` calls' exact
  params (`read_platform_audit` no params; `read_org_audit` with
  `p_organization_id`); denial / RLS-text / unknown PostgrestException
  mapping; non-Postgrest failure → `providerUnavailable`.
- `fake_platform_admin_gateway_test` (+4): deterministic non-PII platform
  trail; org trail scoped to the demo org; foreign org id → honest empty;
  non-owner → denied never empty-success (AC-7).
- `service_locator_test` (+1): the DI pin that the registered
  `PlatformAdminGateway` exposes the audit surface (5-row platform / 3-row
  org via the resolved fake).
- `platform_admin_cubit_test` (+11): audit load success → loaded trail;
  denied → `PlatformAdminDenied` (AC-7, never empty-success); non-denial
  failure → inline `auditError` preserving the loaded lists; org
  select/clear; no-op guards (before the lists load, both methods);
  **in-flight guards** (duplicate `loadAudit` / duplicate `selectAuditOrg`
  ignored while one is in flight); trail-survives-reload pin;
  **the auditLoading-carry race pin** (see §7).
- `platform_admin_screen_test` (+5): Audit section renders the platform
  trail; org-switch via the real dropdown; empty copy; denied flip
  never-empty; inline error + retry recovers (AR/TR header pins folded into
  the localization group).

  Per-file sums: 8 + 4 + 4 + 1 (T2–T3) + 11 + 5 (T4) = **33 declarations**
  — matching the ledger lockstep 950 → 983 (suite 953 → 986 runtime).

## 3. Pending (honestly NOT run — do not read as verified)

- **No live configured-build read on a device/emulator** — all client
  verification is the typed/fake test suite + DI pins (the D-45.1 Phase 2
  convention; needs `.env`, git-ignored). The real audit read path is inert
  until a configured build exists.
- **No partner-facing org-audit UI** — `read_org_audit` is partner-capable
  server-side, but the first surface is owner-only on the platform-admin
  screen; a partner-facing org-audit screen is a recorded follow-up behind
  the same methods (D-AUD non-decision).
- **No audit export / archive / delete / drill-through UX** — out of scope
  (D-AUD1: read-only, no export); flagged follow-up.
- **Realtime audit push / live delivery stays §14-deferred** — the forward
  pin still narrows to `('messages')`; realtime, billing, and AI remain the
  three deferred paths.
- **No push** — `main` is ahead of `origin`; push awaits owner approval.

## 4. Acceptance-criteria status (plan §8)

| Criterion | Status | Evidence |
|---|---|---|
| Platform audit + per-org audit render as a read-only, redacted, metadata-only list on the owner-only screen (third section after members) | **VERIFIED** | T4 widgets; suite 986; `platform_admin_screen_test` |
| Denied, never empty-success: non-owner → distinct `PlatformAdminDenied` | **VERIFIED** | fake owner gate + cubit denied test; AC-7 pinned |
| Redaction holds client-side: VO renders only the RPC's redacted fields; no raw SELECT anywhere | **VERIFIED** | `AuditEntry` field list (contract §8); D-P0C4; no `from`/`select` on audit in the client |
| Env-less runs and the full Flutter suite unchanged (fake); real path inert until a configured build | **VERIFIED** | DI pins; suite green on the fake |
| Dated matrix §6 addendum precedes the client swap; roadmap §14 fifth flip; §2 reads 18-of-18; README lockstep; ledger PASS | **VERIFIED** | `7b7c1a8` (T1) before `56414a6`/`b0f9022`; this commit; README 983; PASS 115 |
| Full gate on every client slice; nothing pushed | **VERIFIED** | §2.1; nothing pushed |

## 5. Exact commands (as run — reproducible)

```bash
cd <law_app main worktree>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash scripts/verify_ledger.sh
bash scripts/verify_policy_tests.sh --check   # static battery, no DB (unchanged this slice)
# No apply commands exist in this slice — the audit RPCs were applied 2026-08-01 and are battery-pinned.
```

## 6. Ledger impact

README test count **950 → 983** across the slice in lockstep with the
ledger's declaration count (suite 953 → 986 runtime; the 3-test spread is
the `blocTest<>` expansion convention). Final state
`scripts/verify_ledger.sh` **PASS 115/0/0**. The docs all sweep green with
the resolved commit refs; no SQL artifacts were added (client-only slice).

## 7. Review findings — resolved (not papered over)

- **T1 (matrix addendum):** reviewer pass clean on all five check areas
  (format mirror of the four prior §6/§4 addenda, single-row widening,
  §7/ordering consistency, and every factual claim — RPC headers confirm
  "REVIEWED & APPLIED — dev project, 2026-08-01", both RPCs confirmed in
  the battery §1d rpc_list, D-P0C4 phrasing matches the §5 addendum).
- **T2–T3 (data layer), two real flags, both fixed:**
  1. The gateway's own doc comment over-claimed "never a raw TypeError"
     while using `row['action'] as String?` — a non-null wrong-typed value
     would throw a raw `TypeError` across the boundary. Fixed with a
     `_optionalString` guard (null → null, String → itself, any other
     non-null → `FormatException`), now genuinely meeting the
     documents/messages T7 guarded-cast baseline, and pinned by a
     wrong-typed-uuid drift test (a uuid column arriving non-string).
  2. README line 95 misattributed the storage swap to this slice (stale
     trailing clause). Reworded to describe the audit data layer.
  Optional notes folded where cheap: `_rowsFrom` reuse and the
  defensive-catch asymmetry were accepted as out-of-scope (minimal blast
  radius, no over-claim added).
- **T4 (UI), one real race, fixed:** the reviewer caught that `load()`
  could carry an in-flight `auditLoading=true` forward across an action
  reload, stranding the remounted Audit section on a permanent spinner
  (the section re-triggers its own post-frame fetch after remount).
  **Fixed: `load()` never carries the in-flight flag forward** —
  `auditLoading: false` on the reloaded state — pinned by a dedicated
  cubit test. The reviewer's minor items were also folded: the duplicated
  `_orgNameFor` in the same library was unified, and in-flight guard tests
  were added (duplicate `loadAudit` while loading is ignored).

## 8. Owner attention needed

- **Push approval:** `main` is ahead of `origin`; the slice's commits
  (`ff0fa57` plan, `7b7c1a8` T1, `56414a6` T2–T3, `b0f9022` T4, this T5)
  await your push approval.
- **Partner org-audit UI (follow-up):** `read_org_audit` is partner-capable
  server-side; a partner-facing org-audit screen behind the same methods is
  the recorded next consumer if you want it.
- **Remaining §14 deferred paths:** realtime (message bodies / individual
  `messages` rows / live delivery — the largest remaining lift), billing
  (D-09), AI (no scope). Each keeps the same per-feature discipline.

## 9. Dated close decision

**Audit surfacing slice — CLOSED 2026-08-08.** T1–T4 met their gates: the
dated matrix §6 addendum (client-surface widening for the "Read the audit
table" row) landed before the client swap; the seam/impl/gateway audit
methods shipped with guarded row→VO mapping and denied/providerUnavailable/
unknown failure mapping; the `AuditEntry` VO (redacted-only, contract §8)
and the deterministic non-PII fake landed; and the platform-admin Audit
section (platform + per-org trails, org-scope selector, denied-never-empty
per AC-7, inline error-retry) shipped with l10n ×3 and the full gate green
on `main` (format clean · analyze clean · suite 986 runtime / README 983 ·
ledger PASS 115). The §14 audit row flips to per-feature SHIPPED (fifth
un-deferral) and the unwired-RPC inventory reads **18-of-18**. **Nothing
was applied to the dev project in this slice** — the audit RPCs were
already applied 2026-08-01 and battery-pinned; this slice was client +
docs only. Realtime, billing, and AI stay deferred each behind their own
future per-feature un-deferral. Nothing pushed.
