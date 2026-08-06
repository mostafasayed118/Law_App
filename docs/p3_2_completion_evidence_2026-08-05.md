# LegalHub — P3.2 Completion Verification & Evidence Record (2026-08-05)

> **Record type:** Slice P3.2 close-out evidence (plan
> `docs/p3_auth_org_ux_plan.md` §6 P3.2 + scope note
> `docs/p3_2_scope_2026-08-05.md`, ratified 2026-08-05 with D-P32.1 /
> D-P32.2) — records exactly what was **verified** about the membership
> hydration + active-org context delivery (commits `24d5ec3`..`6a8f567`,
> all on `main`, no push) and exactly what is **still pending**, with no
> claim beyond what was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-05 — implementation complete, full gate green
> on `main` (analyze clean, suite 752, ledger PASS 115).** The dated close
> decision for the P3 plan gate-table rows is recorded in this commit
> (plan §1 rows + roadmap status line), mirroring the P0C / P3.1 close.

---

## 1. What this record covers

Slice P3.2 = **membership hydration + active-org context** (plan §6 P3.2):
`Session.memberships` moves from the honest empty sync snapshot to
RLS-scoped hydrated data, and the active-org selection becomes
persisted-on-device context. Delivered against the ratified scope note
(`docs/p3_2_scope_2026-08-05.md`, D-P32.1 / D-P32.2), **client-only —
no schema/RLS/RPC change** (consumes the applied P2 SELECT surface as-is).

What was built, per task:

| Task | Artifact | Commit |
|---|---|---|
| Ratification D-P32.1/D-P32.2 | scope-note decisions closed (drop unknown-role rows; extend `ActiveOrgStore`) | `24d5ec3` |
| 2 — data seam | `SupabaseOrgApi.listMyMemberships()` RLS-scoped SELECT + `OrgTableCaller` injectable | `cf928fc` |
| 3–5 — repositories | `MembershipRepository` domain seam; `SupabaseMembershipRepository` mapper (D-T5, D-P32.1, null-name tolerance); `FakeMembershipRepository`; `organizationName` → `String?` | `42b71b1` |
| Review inputs recorded | failure/empty conflation + diagnostic-channel notes → Task 8 inputs | `2faa8cb` |
| 6 — persistence trio | `OrgSelectionStore` + SharedPreferences + in-memory impls (LocaleStore pattern) | `a3e4434` |
| 7 — DI wiring | `ActiveOrgStore` persistence (restore validated at seed, persist on select, D-08); env-gated `MembershipRepository` + `OrgSelectionStore` in the locator | `07d19f5` |
| 7 review fix | cold-start read race — late restore applied for the current user | `afb92ba` |
| 8 — hydration | typed `MembershipHydrationResult`; `AuthCubit` hydration step (loading held, AC-3 expiry first, honest empty, failure reported via `ErrorReporter`); `_toSession` stale comment fixed; demo-role reconciliation (client → partner) | `8a092c1`, `b5a8b5a` |
| 8 review fix | diagnostics never gate the authenticated emission | `2aa6709` |
| Ledger lockstep | README 716 → 732 → 741 → 743 → 748 → 749 | `284733a`, `8a4ea59`, `e455ba5`, `cd725f4`, `6a8f567` |

## 2. Verified (actually run this session, 2026-08-05)

### 2.1 Final gate on `main` (post-`6a8f567`)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **752 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 749 in lockstep) |

### 2.2 Test coverage added by the slice (+35 declarations, 716 → 749)

- `supabase_org_api_impl_test` — `listMyMemberships()` SELECT surface (+2).
- `supabase_membership_repository_test` — typed mapper: role/status mapping
  (D-T5), null org-name tolerance, D-P32.1 unknown-role/status drops,
  provider failure → `HydrationFailed` (typed kind, incl. denied) (+8).
- `fake_membership_repository_test` — fake hydration + reconciliation pin
  (+2, roles updated).
- `shared_preferences_org_selection_store_test` /
  `in_memory_org_selection_store_test` — the persistence trio (+7).
- `active_org_store_test` — select persists, validated restore (both
  orderings incl. the cold-start read race), single-application,
  sign-out preservation, read/write failure degradation (+10).
- `service_locator_test` — `MembershipRepository` env flip (real/fake),
  `OrgSelectionStore` seam, `ActiveOrgStore` wiring (+3).
- `auth_cubit_test` — hydration on success (repository called once for the
  caller id), provider-empty → honest `[]`, failure reported via
  `ErrorReporter` with the typed kind while the session stays
  authenticated, AC-3 expiry → reauth with zero repository calls,
  throwing-reporter never strands the session (+5).
- Constructor-ripple updates across ~13 test files (new third `AuthCubit`
  argument); role-label assertions reconciled to partner (EN/AR).

## 3. Pending (honestly NOT run — do not read as verified)

- **P3.3–P3.5 of the plan (org-management UX, invitation acceptance,
  owner admin) are ⏳ not started.**
- **Live dev-project hydration E2E** (a configured build signing in and
  reading the real RLS-scoped `memberships`/`organizations` surface) was
  **not** exercised. All verification above is the typed/fake-gateway test
  suite plus static review; a configured-build check remains **owner-side**
  (requires `.env`, which stays git-ignored), per D-45.1 Phase 2 and the
  P3.1 evidence §3 convention.
- **No server change was made or needed** — this slice consumed the applied
  P2 surface (`3704a1d`) exactly as rehearsed/applied.

## 4. Acceptance-criteria status

| Criterion (scope note §6 / plan §6 P3.2) | Status | Evidence |
|---|---|---|
| `MembershipRepository.loadMemberships({userId})` — domain boundary, no DTOs/tokens cross | **VERIFIED** — typed `MembershipHydrationResult`; identity hint only, not a widening filter | `supabase_membership_repository_test` + seam docs |
| `SupabaseOrgApi.listMyMemberships()` RLS-scoped SELECT, raw rows out | **VERIFIED** — impl test pins the table-caller surface | `supabase_org_api_impl_test` |
| Row mapping: D-T5 role/status, D-P32.1 unknown-role/status dropped loudly, null org-name tolerated (suspended/removed) | **VERIFIED** — mapper tests incl. negative rows | `supabase_membership_repository_test` |
| Hydration on sign-in/restore/demo: `Session` rebuilt with hydrated memberships; loading held until resolved (no flash) | **VERIFIED** — blocTest sequence `[loading, authenticated-with-hydrated]`; repository called exactly once for the caller id | `auth_cubit_test` |
| AC-3: expiry honored before hydration — expired session → reauth, never hydrates | **VERIFIED** — counting-repository blocTest (calls == 0) | `auth_cubit_test` |
| Provider-empty → honest `[]` | **VERIFIED** | `auth_cubit_test` |
| Hydration failure: session never invalidated; surfaced via `ErrorReporter` with typed kind | **VERIFIED** — incl. throwing-reporter pin (diagnostics never gate the emission) | `auth_cubit_test` |
| D-P32.2: active-org persisted via `OrgSelectionStore`; restore validated against the session's memberships; seed-guard unchanged | **VERIFIED** — persist/restore both orderings/sign-out/failure degradation | `active_org_store_test` |
| DI: env-gated `MembershipRepository` (real/fake) + prefs seam resolves | **VERIFIED** — flip pins in both env branches | `service_locator_test` |
| Demo-role reconciliation (client → partner) so hub/session/roster capability surfaces agree | **VERIFIED** — all three fakes agree; EN/AR label pins updated | `fake_membership_repository_test`, profile/settings tests |
| EN/AR/TR + RTL on P3.2 surfaces | **VERIFIED** — no new strings introduced by this slice; full suite (incl. RTL widget tests) green | §2.1 |
| Exit criteria (plan §11-P3): tests cover expiry, denial, capability maps stay UX hints | **VERIFIED** — suite green incl. expiry/denial; no new authorization claims (D-08 preserved) | §2.1 |

## 5. Exact commands (as run — reproducible)

```bash
cd <law_app main worktree>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash scripts/verify_ledger.sh
```

## 6. Ledger impact

README test count synced **716 → 749** in lockstep with the ledger's
declaration count across the slice (+35 tests, five README bumps). Final
state `scripts/verify_ledger.sh` **PASS 115/0/0** with README 749. No
schema/RLS/policy change — this slice is client code only.

## 7. Review findings — resolved (not papered over)

- **Task 7 — cold-start read race:** the constructor-fired
  `OrgSelectionStore.read()` usually resolves *after* the hub seeds during
  the same build pass, silently skipping the restore for the whole launch.
  Fixed by retaining the seeded session's memberships and applying a
  late-arriving restore when it is still a membership (D-08 validated);
  sign-out no longer discards a cached-but-unapplied restore. Pinned by two
  regression tests (`afb92ba`).
- **Task 8 — failure/empty conflation (scope-note review input 1):** the
  repository previously swallowed provider failures to `[]`. The seam now
  returns a typed `MembershipHydrationResult` (`HydrationSucceeded` /
  `HydrationFailed`) so the cubit distinguishes honest-empty from
  offline/denied (`8a092c1`).
- **Task 8 — diagnostic channel (scope-note review input 2):** hydration
  failures are reported through the `ErrorReporter` seam with the typed
  kind (repository debugPrint swallow removed) (`8a092c1`, `b5a8b5a`).
- **Task 8 — diagnostics gating the emission:** the `HydrationFailed` arm
  awaited the reporter before emitting authenticated, so a throwing
  reporter would strand the session in `loading`. The state is now emitted
  first and the report is best-effort (wrapped, loud via debug), pinned by
  a throwing-reporter blocTest (`2aa6709`).
- **Fake role divergence (scope-note review input):** demo identity
  reconciled to **partner** across `FakeAuthGateway`,
  `FakeMembershipRepository`, and the org gateway's roster seed (`8a092c1`).

## 8. Owner attention needed

- **Remaining plan work:** P3.3 (org-management UX), P3.4 (invitation
  acceptance + account deletion), P3.5 (platform-owner admin) are ⏳ not
  started.
- **Optional live E2E:** a configured-build sign-in → hydration smoke on
  the dev project (owner-side, needs `.env`) to confirm the RLS surface
  beyond the typed/fake suite — this is also D-45.1 Phase 2's controlled
  condition.
- **Known limitation (recorded in `auth_cubit.dart`):** no first-class
  `hydrate()` retry seam for an already-authenticated session; the next
  explicit auth op re-hydrates, and retry UI is a screen concern.
