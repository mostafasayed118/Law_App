# LegalHub — P3.5 Completion Verification & Evidence Record (2026-08-05)

> **Record type:** Slice P3.5 close-out evidence (plan
> `docs/p3_auth_org_ux_plan.md` §6 P3.5) — records exactly what was
> **verified** about the platform-owner admin UX (commits `47f777b`..`06d78a7`,
> all on `main`, no push) and exactly what is **still pending**, with no
> claim beyond what was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-05 — implementation complete, full gate green
> on `main` (analyze clean, suite 827, ledger PASS 115).** The dated close
> decision for the P3 plan gate-table rows is recorded in this commit
> (plan §1 rows + roadmap status line + roadmap gate-table row), mirroring
> the P0C / P3.1 / P3.2 / P3.3 / P3.4 close. **P3.5 was the last open row
> of the P3 plan — the plan is now fully shipped.**

---

## 1. What this record covers

Slice P3.5 = **platform-owner admin UX** (plan §6 P3.5, permission matrix
§5): orgs list, members metadata list, platform suspend/reactivate, delete
demo account (never self), with owner-only RPCs denying non-owners
server-side → the client renders **denied, never empty-success** (AC-7).

Gap analysis (verified, not assumed): the five owner-only RPCs
(`list_organizations_metadata`, `list_members_metadata`,
`suspend_membership_platform`, `reactivate_membership_platform`,
`delete_demo_account`) were **REVIEWED & APPLIED** on the dev project
(2026-08-01) but had **zero client consumers** — unlike P3.3/P3.4, where the
UI was already shipped and the delta was handoffs, P3.5 was a **genuine
build** (the last open P3 row). Delivered in four gated slices with
decisions ratified by autonomy (D-P35.1..6):

| Slice | Artifact | Commit |
|---|---|---|
| A — data seam + fakes | `PlatformAdminGateway` domain seam **reusing the org vocabulary** — `OrganizationSummary`/`OrgMember` map 1:1 from the metadata RPC rows, failures reuse `OrgOutcome`/`OrgFailure`/`OrgFailureKind.denied`, **zero new models or failure kinds** (D-P35.2); the Supabase trio mirrors the org data layer (typed `SupabasePlatformAdminApi` + PostgREST impl with a narrow `denied`/`unknown` mapping incl. the never-self raise + mapping gateway with loud `FormatException`s on drift); `FakePlatformAdminGateway` derives from the **shared** `FakeOrganizationGateway` instance (D-P33.2 one-instance DI) via new metadata-only accessors (`allOrganizations()` / `allMembers()` — invited rows excluded, mirroring the profiles join — / `deleteAccount()`), mirrors `is_platform_owner()` via `demoIsPlatformOwner` (D-P35.4), refuses the demo identity on delete (never self) | `47f777b` |
| B — DI wiring | `PlatformAdminGateway` registered with the Batch 3.3 env flip (configured → `SupabasePlatformAdminGateway` via the `supabasePlatformAdminApiFactory` test seam; env-less → the fake bound to the **same** org-gateway instance, so created orgs reach the admin listing) | `4f44788` |
| C — cubit | `PlatformAdminCubit` loads both metadata lists in parallel; a `denied` response from **either** becomes the distinct `PlatformAdminDenied` — never empty-success (D-P35.6), while an honest owner-empty still renders loaded-empty; actions (suspend/reactivate/delete-demo) use the row-spinner pattern: reload both lists on success, restore last-good + typed kind on failure | `748e8f5` |
| D — screen + route + l10n | `PlatformAdminScreen` (self-provided cubit, org-hub precedent; orgs + members sections with role/status; suspend/reactivate toggle on active/suspended; delete-demo with an error-tinted confirm) + `/platform-admin` shell route (settings-surface anchor) + settings entry (a nav hint for any authenticated user — **the server gates**, D-P35.1; non-owner → the distinct locked `_DeniedState`, never empty success); 7 new l10n keys × EN/AR/TR + gen-l10n (reuses `actionSuspend`/`actionReactivate`/`memberStatus*`) | `864b569` |
| Review fix | Dead `_runAction` parameter removed (see §7); blank user id → honest `unknown`; fake last-partner divergence documented | `06d78a7` |
| Ledger lockstep | README 767 → **824** (incl. the regenerated `app_localizations_en.dart`) | `0ed5204`, `be218d8` |

D-P35.1 (no client-owned owner claim — contract §5; `is_platform_owner()`
is server-side) and D-P35.3 (the platform boundary is a distinct seam, not
`OrganizationGateway` bloat) are recorded in the seam/screen docs.

## 2. Verified (actually run this session, 2026-08-05)

### 2.1 Final gate on `main` (post-`06d78a7`)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **827 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 824 in lockstep) |

### 2.2 Test coverage added by the slice (+57 declarations, 767 → 824; suite 770 → 827)

- `test/data/admin/` — the data trio (+33): the api impl pins the five RPC
  forwards (params exact) and the failure mapping (non-owner `permission
  denied` → `denied`; the never-self raise `cannot delete your own account`
  → `denied`; unspecified → `unknown` with the message preserved); the
  gateway pins the row→model mapping (org metadata, member metadata incl.
  display-name fallback and suspended status, loud `unknown` on drift:
  missing id/name, unknown role, missing user id) and the action forwards +
  denials + blank-id guard; the **fake** pins owner positive paths (seeded
  lists, live shared-state derivation — a created org joins the admin list,
  invited rows excluded, suspend/reactivate delegation, delete removes the
  target from every roster), **non-owner → denied, never empty** (every
  method returns `OrgFailureKind.denied`, never a value — AC-7), and
  **never-self** (the demo identity is refused and survives).
- `service_locator_test` (+3): wires to `FakePlatformAdminGateway`
  unconfigured; flips to `SupabasePlatformAdminGateway` under a configured
  env (via the `_FakeSupabasePlatformAdminApi` seam); the shared-instance
  pin proves a created org reaches the resolved admin listing (one org
  state per env-less run).
- `platform_admin_cubit_test` (+11): parallel load → both lists; a denial
  on either list → `PlatformAdminDenied` (not empty-success); honest
  owner-empty → loaded-empty; non-denial failure → typed `Failed` with the
  `platformAdmin.*` code; action success reloads both lists; action denial
  restores the lists + returns the kind; delete success reloads; never-self
  → denied; no-ops before load; the in-flight double-load guard.
- `platform_admin_screen_test` (+9): owner renders both metadata sections
  (org name + created date, member identity + org·status + the platform
  actions); suspend flips the row to SUSPENDED (reactivate appears);
  reactivate flips back; delete requires confirmation (cancel leaves the
  row, confirm removes it); never-self delete surfaces the localized denied
  message and the row survives; **non-owner renders the distinct denied
  state — no org/member names, no empty label, no section headers**; a
  failure shows the typed message and retry recovers; AR + TR pins (section
  headers + localized status chip).
- `router_test` (+1): the shell e2e pin drives settings → the platform-admin
  tile (scrolled into view) → `/platform-admin` renders its sections with
  the settings destination still highlighted.

## 3. Pending (honestly NOT run — do not read as verified)

- **The P3 plan is now fully shipped** — P3.5 was the last ⏳ row; there is
  no remaining unshipped P3 implementation work.
- **Live dev-project E2E** (a configured build exercising the owner-only
  RPCs against the real RLS/RPC surface with an actual owner identity —
  metadata lists, platform suspend/reactivate, delete demo) was **not**
  exercised. All verification above is the typed/fake-gateway test suite
  plus static review; the owner-positive paths need a configured build with
  the owner's `.env` (git-ignored), per D-45.1 Phase 2 and the
  P3.1–P3.4 evidence §3 convention.
- **Deep-link token entry** remains deferred to Phase 4 platform
  intent-filter work (D-P34.2, recorded) — not implemented in this slice.
- **No server change was made or needed** — P3.5 is client code only (plan
  §1 "code only — no schema/RLS changes"; it consumes the five applied
  owner-only RPCs as-is).

## 4. Acceptance-criteria status

| Criterion (plan §6 P3.5 / §10 / §7) | Status | Evidence |
|---|---|---|
| Owner-only screens gated on the applied `list_organizations_metadata` / `list_members_metadata` responses and their typed denials | **VERIFIED** — the screen is reachable by any authenticated user (settings entry, D-P35.1) and the server gates: `permission denied` crosses the impl → gateway → cubit → screen intact | api impl + gateway + cubit + screen tests, §2.1 |
| Orgs list (metadata only) | **VERIFIED** — `OrganizationSummary` row mapping (id/name/createdAt) pinned; widget renders org names + localized created date | gateway + screen tests |
| Members metadata list (metadata only) | **VERIFIED** — `OrgMember` row mapping (identity + role/status/timestamps) pinned; invited rows excluded (profiles join) | gateway + fake tests |
| Platform suspend / reactivate (any org, metadata-level action) | **VERIFIED** — RPC forwards pinned; cubit action reloads both lists; screen toggles the row status with the localized status chip | api impl + cubit + screen tests |
| Delete demo account (never self) | **VERIFIED** — the never-self raise maps to `denied` and the fake refuses the demo identity; the screen confirm → denied snackbar pin; a blank id is rejected without calling the seam | api impl + fake + gateway + screen tests |
| Non-owner → denied, **never empty-success** (AC-7: "GIVEN a non-owner, THEN the denied state appears — not empty success") | **VERIFIED** — pinned at every layer: `denied` from either parallel RPC → distinct `PlatformAdminDenied`; the screen renders the locked `_DeniedState` with **no** org/member names, **no** empty label, **no** sections | cubit + screen tests (fake `demoIsPlatformOwner: false`) |
| Tests: owner positive paths, non-owner → denied (not empty), EN/AR/TR | **VERIFIED** — owner paths (lists, toggle, delete), non-owner denied-not-empty, AR/TR section-header + status-chip pins; full suite green | §2.1 / §2.2 |
| Localization/RTL on the new surface | **VERIFIED** — 7 new keys resolve in EN/AR/TR (gen-l10n + pins); full suite incl. RTL green | §2.1 / §2.2 |
| Exit criteria (plan §11-P3): suite green incl. denial; capability maps stay UX hints | **VERIFIED** — full suite green incl. the AC-7 denial; the settings entry is a navigation hint only — the client carries no owner claim and never over-renders (D-08 / D-P35.1 preserved) | §2.1 |

## 5. Exact commands (as run — reproducible)

```bash
cd <law_app main worktree>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash scripts/verify_ledger.sh
```

## 6. Ledger impact

README test count synced **767 → 824** in lockstep with the ledger's
declaration count across the slice (+57 tests). Final state
`scripts/verify_ledger.sh` **PASS 115/0/0** with README 824. No
schema/RLS/policy change — this slice is client code only (the seven new
l10n keys × EN/AR/TR are the only non-Dart additions, via the standard ARB
+ gen-l10n path).

## 7. Review findings — resolved (not papered over)

- **Dead `_runAction` parameter (Slice C review):** the empty-string
  `organizationId` in `deleteDemoAccount` was the symptom of a fully dead
  parameter — `_runAction` never read it (the success arm reloads both
  lists unconditionally; the pending-row marker uses only `userId`).
  Removed from `_runAction` and all three callers, eliminating the
  misleading `''` argument (`06d78a7`).
- **Blank user id mapped to `denied` (honesty nit):** a missing id is an
  input-validation failure, not a permission denial — now maps to
  `OrgFailureKind.unknown` (the org surface's blank-email convention), and
  the gateway test pins it (`06d78a7`).
- **Fake last-partner divergence (documented, not fixed):** the platform
  fake delegates suspend/reactivate to the org fake, which enforces the
  last-active-partner guard — `suspend_membership_platform` has **no** such
  guard server-side. Stricter than the server is safe for a dev seam (it
  never over-grants), so the divergence is documented in the fake's doc
  rather than fixed; a test pinning "platform may suspend the last partner"
  would need the real RPC.

## 8. Owner attention needed

- **The P3 plan is fully shipped (P3.1–P3.5).** Remaining follow-ups are
  outside the P3 rows.
- **Optional live E2E across P3.1–P3.5:** a configured-build smoke on the
  dev project (owner-side, needs `.env`) — sign-in → hydration → org
  management → accept → the **owner-only admin surface with a real owner
  identity** — to confirm the RLS/RPC surface beyond the typed/fake suite;
  also D-45.1 Phase 2's controlled condition.
- **Recorded forward hook (D-P34.2):** deep-link token entry joins the
  Phase 4 platform intent-filter work.
- **Phase 4 deep-link recovery (4.1)** — the platform intent-filter work
  that the D-P34.2 hook points at — is the natural next roadmap work.
