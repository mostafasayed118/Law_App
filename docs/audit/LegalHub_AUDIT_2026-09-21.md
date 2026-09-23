# LegalHub — Comprehensive Code Quality Audit

> **Record type:** consolidated five-dimension code-quality audit.
> **Date:** 2026-09-21 · **Audited revision:** working tree at `ec4eb73` + 15 modified files + 1 untracked file
> **Method:** five parallel `general-purpose` subagents (one per dimension), then independent re-verification of every CRITICAL/HIGH claim against the source by the consolidating agent.
> **Raw per-dimension findings:** `docs/audit/_raw/01-maintainability.md`, `02-architecture.md`, `03-code-quality.md`, `04-security.md`, `05-performance.md`

---

## 1. Executive summary

| Dimension | Score | Weight | Weighted |
|---|---|---|---|
| 1. Maintainability | **6.0** / 10 | 20% | 1.20 |
| 2. Clean architecture | **8.0** / 10 | 20% | 1.60 |
| 3. Code quality | **6.5** / 10 | 20% | 1.30 |
| 4. Security | **7.5** / 10 | 25% | 1.875 |
| 5. Performance | **6.5** / 10 | 15% | 0.975 |
| **Overall weighted** | | | **6.95 ≈ 7.0 / 10** |

Weights reflect a multi-tenant legal-tech product: security carries the most, performance the least (demo-scoped, synthetic data, no production traffic).

**Counts by severity (verified):** 1 CRITICAL · 8 HIGH · ~20 MEDIUM · ~25 LOW.

### The three things that are broken *right now*

1. **The working tree does not compile.** `flutter analyze` → 1 error; `flutter test` → **0 of 1356 tests can run**. CI (`format + analyze + test`) would fail on its second gate. One 5-line fix.
2. **The same in-flight slice contains a silent data-loss bug**: capped message reads return the 200 **oldest** messages of a thread, dropping the newest. It would ship the instant #1 is fixed.
3. **That slice's core logic has zero tests** — which is precisely why #1 and #2 were able to exist simultaneously.

### The through-line

> **This repository has an exceptional gate regime for committed work and no gate at all for work in progress — and the single cheapest check is the one that was skipped.**

The project's investment in catching problems is genuinely unusual: 1356 tests, a CI pipeline, a governance-ledger script that re-resolves every cited commit hash, 81 SQL files including positive+negative RLS policy batteries, an 891-line DI test, and a `tracked_deviations.md` ledger whose entries carry owning commits and regression guards. HEAD is clean; every recorded gate passes at `ec4eb73`.

But the uncommitted perf-hardening slice (untracked `lib/data/list_query_guards.dart` + 7 modified `supabase_*_api_impl.dart` + 4 screens + `view_state_list.dart`) has **never been evaluated by any gate** — because it is untracked, CI never saw it, and no local gate was run before leaving it. All five subagents read that file and none flagged it, because *a compile error is invisible to static reading*. `flutter analyze` — 15 seconds, already wired into CI, already passing on HEAD — catches it immediately.

The same absence explains the second and third findings: the guard's ordering table was written from reasoning rather than from a test, so the inverted `ascending` flag survived review; and nothing pins the cap, the column, or the direction.

**The fix is not three bugs. It is one missing habit: run `flutter analyze` and `flutter test` before leaving a slice — and `git add` the new file so CI can see it.** Everything else in this report is a longer-term improvement; these three are minutes of work.

---

## 2. Scope and method

**Audited:** `lib/` (274 hand-written Dart files, 27,283 LOC), `test/` (155 files, ~33,500 LOC), `supabase/` (81 SQL files), `android/`, `ios/`, `scripts/`, `.github/`, and the 171 files in `docs/`.

**Excluded:** `lib/l10n/app_localizations*.dart` (~5,950 generated lines), `build/`, `.dart_tool/`, platform scaffolding beyond the security-relevant manifests, `stitch_legalhub_mobile_app/` (94 design mockups), `.agents/`, `.cluster/`, `.openclaw/`, `.opencode/`.

**Prior audits read first and *not* re-reported:** `docs/phase2_refactor_audit_2026-08-11.md` (the E1–E10 / C1–C2 duplication program, fully executed), `docs/tracked_deviations.md` (the accepted-deviation ledger), `docs/adr/0001`–`0008`, `docs/p4_threat_model_2026-08-09.md`, `docs/security_review_gate_record_2026-08-09.md`, `docs/p4_findings_register_2026-08-09.md`, `docs/auth_tenant_authorization_contract.md`, `docs/permission_matrix.md`, `docs/p2_schema_rls_design.md`, `docs/refactor_close_out_*.md`.

**Verification performed by the consolidating agent** (this is where the CRITICAL came from — see §9 for the corrections log):

| Command | Result |
|---|---|
| `flutter analyze` | **1 error** — `lib/data/list_query_guards.dart:64:13` `invalid_assignment` |
| `flutter test test/core/roles/user_role_test.dart` (control, unrelated to the modified files) | **Compilation failed** — same error |
| `flutter test test/data/documents/supabase_document_api_impl_test.dart` | **Compilation failed** — same error |
| `grep -rn "boundedTableSelect\|kSupabaseListRowCap\|kSupabaseListOrderings" test/` | **0 hits** |
| `grep -rn "await serviceLocator<" lib/features` | **exactly 4 sites** |
| `grep -rn "_kindFor" lib/` | **9 definitions across 9 files** (32 total hits) |
| `grep -rn "BlocBuilder<" lib/` / `buildWhen` / `BlocSelector` / `context.select` | **36 / 2 / 0 / 0** |
| `grep -rn "ListView(" lib/features` vs `ListView.builder\|separated` | **21 vs 3** |
| `grep -niE "limit\|order by"` on the three admin RPCs | ORDER BY present, **LIMIT absent in all three** |
| `grep -rn "ResponsiveBreakpoint\|isCompact\|responsiveHorizontalPadding" lib/ test/` (excluding the definition) | **0 hits — dead** |
| `grep -rn "SampleService" lib/ test/` | registered in DI, pinned by tests, **docstring declares it intentional** |
| AndroidManifest / `initializeSupabase` | `allowBackup` **absent** (defaults true); **no `localStorage`** override |

---

## 3. Dimension 1 — Maintainability · **6.0 / 10**

> Strongest: testability seams + governance discipline (every production adapter has a stub-seam test; 94.4% class-level dartdoc; a ledger script that re-resolves commit hashes). Weakest: the feature slice is not self-contained and the state/cubit layer was never refactored — production adapters live in a parallel `lib/data/<feature>/` tree under three undocumented conventions, and the list-surface state skeleton is reproduced verbatim across 6–8 features.

### HIGH

**H-1 · The in-flight row cap silently truncates chat transcripts to the 200 *oldest* messages**
`lib/data/list_query_guards.dart:36` + `:61-66`, consumed at `lib/data/messaging/supabase_message_api_impl.dart:42-47`

`'messages': ('sent_at', false)` → `descending == false` → `query.order(orderColumn, ascending: !descending)` issues **`ORDER BY sent_at ASC LIMIT 200`**. It is the only ascending entry in the table; the other six are descending, where "first 200" correctly means "newest 200". For `messages` it means the **200 oldest**, dropped at the seam before the gateway maps rows to value objects. The detail screen renders the result as the whole transcript with no indicator.

**Impact:** silent data loss on a legal conversation's read path, in the worst direction — the missing rows are the newest, the ones a user scrolls for. No error, no empty state, no paging.
**Fix:** `'messages': ('sent_at', true)`, then reverse the mapped list in the gateway before emitting (the live-append path at `supabase_message_api_impl.dart:219-225` needs chronological order, so fetch descending and reverse). At minimum surface the cap in the UI.

**H-2 · A feature's production adapter does not live in the feature slice — three conventions coexist**
`lib/data/documents/supabase_document_gateway.dart:4` imports `../../features/documents/domain/document_gateway.dart`; the sibling fake lives at `lib/features/documents/data/fake_document_gateway.dart:3`. Same split for matters, messaging, storage, billing, notifications. But orgs/admin keep *both* in `lib/data/*`, and auth is split **within itself** (`lib/data/auth/fake_auth_gateway.dart` vs `lib/features/auth/data/fake_sign_up_gateway.dart`).

Verified counts: **13 fakes in `lib/features/*/data/`**, **4 fakes in `lib/data/*/`**, all real adapters in `lib/data/*/`.

**Impact:** the `data/domain/presentation` triad is only two-thirds true; `grep -rn "lib/data" docs/*.md INSTRUCTIONS.md` → **zero hits**, so the rule is nowhere documented. A maintainer adding a Supabase-backed feature must guess between two homes; both compile and both pass tests, so the choice is unreviewable.
**Fix:** write the rule down — *feature-owned seam ⇒ `lib/features/<name>/data/`; core-owned seam ⇒ `lib/data/<name>/`* — and add a header comment per `lib/data/*` directory. The undocumented-ness is the actual defect.

**H-3 · The list-surface state + cubit skeleton is duplicated across ≥6 features**
`approvals_cubit.dart:19-56`, `task_board_cubit.dart:16-46`, `document_cubit.dart:32-57`; states at `approvals_state.dart:11-25`, `task_board_state.dart:7-20`, `document_state.dart:13-25`. A normalised-signature scan of the 12 cubits with `load()` found **6 with a byte-identical normalised body** + 2 in a second shape — 8 of 12 in 2 shapes, ~35 lines each. **20 screens** carry the same `addPostFrameCallback(load)` preamble.

Not a re-report: the phase-2/close-out program was scoped to *shared UI widgets* only, and `refactor_close_out_phase2_2026-08-11.md` §7 declares "no further duplication clusters exist" — falsifiable at the layer it never scanned.

**Impact:** ~200 lines of copy-paste of *control flow with an error path* — the highest-risk kind. Any change to the load contract (a stale-request guard, an `isClosed` fix, a new arm) must land 6–8 times; a miss fails silently as "one screen behaves differently".
**Fix:** (a) one generic `ListState<T>` replaces 3+ files with no gateway change; (b) then a `ListCubit<T>` over a fetch closure, with filtered cubits inheriting `load()` and keeping their extras.

### MEDIUM

- **M-1 · Two of six `ViewState` variants have zero producers.** `ViewOffline`/`ViewUnauthorized` are declared, rendered by all three shells, and constructed **nowhere in `lib/`** — only in widget tests. Every consumer folds them into the empty arm. The typed signal that should feed them exists one layer down (`supabase_message_api_impl.dart:162-169` maps `'permission denied'` → `denied`) but no cubit branches on it. *Impact:* two variants are dead in production and untested at feature level, so edits to those arms cannot fail a test; the vocabulary choice silently decides whether denial is representable. *Fix:* delete both (vocabulary → 4) or give them producers via a typed discriminator on `AppError`.
- **M-2 · Sealed states have no `copyWith`** — `PlatformAdminLoaded` has 8 fields and **10** hand-written reconstructions (`platform_admin_cubit.dart:182,218,237,261,271,294,321,379,400`) plus **6** `OrgRosterLoaded(...)` in `org_cubit.dart`. A missed field silently reverts to its default — exactly the bug class the carry-forward comment at `:143-155` exists to prevent.
- **M-3 · `RoleCapability` is a 14-flag × 6-role literal table** (`user_role.dart:125-225`) — 84 hand-written booleans, of which only 12 bits vary; 9 lookups unwrap with `!` (`router.dart:201,213,224,251,285,303,315,412`, `home_screen.dart:63`). Totality *is* pinned by a test, so this is ergonomics + coupling rather than silent breakage. *Fix:* an exhaustive `switch` (new flag becomes a compile error) + a base-with-deltas table.
- **M-4 · `docs/screen_completeness_matrix_2026-08-09.md` is factually stale** — `:56` still reads `legal_research_ai_assistant … | no screen |`, but the AI research slice shipped 2026-09-02 (`235003f`); the summary claims 30 screens / suite 1127 vs the tree's 33 / 1356. *Fix:* a dated addendum (the pattern `permission_matrix.md` already uses); do not edit the historical rows.
- **M-5 · Adding one feature means lockstep edits in 6–8 files** — `service_locator.dart` is **559 lines** (largest non-generated file), built from ~40 near-identical blocks with the env-flip body appearing **12 times verbatim**; `home_screen.dart:134-214` is **11 repetitions** of the same 4-line pattern, a hand-maintained parallel registry to `router.dart:151-343`.

### LOW

- 4 of 19 state classes declared inside their cubit file (3 are defensible sealed hierarchies; `NotificationPrefsState` is not).
- Enum→label helpers use three naming conventions across six files.
- `buildWhen`/`listenWhen` at 2 of 38 `BlocBuilder` sites; `context.select`/`BlocSelector` unused anywhere (see Performance L-1 for the calibrated reading).
- ARB `@` metadata is 3% populated (11 of 367) — all three ARBs are **key-complete** (367 keys each, zero diff).
- `AuthCubit` and `ViewStateView` lack class-level dartdoc (coverage is otherwise 94.4%).
- Five ratified-but-inert home affordances; the ratification lives in a scope doc rather than the deviations ledger.
- ADR-0004's barrel "Consequences" fixes six exports; there are now 22 — **all 22 re-verified to have ≥2 non-`shared/` consumers**, so no export violates the ADR's rule.

### What's done well

1. **Every production Supabase adapter is tested against stub seams** — `test/data/` holds 33 files, a `supabase_*_gateway_test.dart` + `supabase_*_api_impl_test.dart` pair per feature; all 11 adapters appear in ≥2 test files. The `_table`/`_rpc` callable seams are genuinely good testability design.
2. **`docs/` is an asset, not a liability** — a scan of all 171 files for backtick-quoted `lib/**/*.dart` references found **4 broken paths total**, all in explicitly dated records. `scripts/verify_ledger.sh:10-39` enforces this mechanically.
3. **`tracked_deviations.md` + the ADR log are a working decision ledger** with the right boundary; entries cite owning commits and regression guards.
4. **Class-level dartdoc coverage 94.4%**, and comments carry *decisions* rather than restating code.
5. **The l10n pipeline is in lockstep** — three ARBs at exactly 367 keys, zero missing/extra, correct `@@locale`.
6. **The shared barrel obeys its own ADR-0004 rule, re-verified** — all 22 exports have ≥2 consumers.

---

## 4. Dimension 2 — Clean Architecture · **8.0 / 10**

> Strongest: the dependency rule is not decoration — provider containment is exception-free, 39/39 domain files are widget- and data-free, `core/` and `shared/` never reach into `features/`, and the auth seam strips tokens and GoTrue DTOs at two layers with the mapping code to prove it. Weakest: the rule holds for *imports* but breaks for *orchestration*.

### Measured import-graph evidence (not asserted)

| Check | Result |
|---|---|
| `supabase_flutter` imports under `lib/` | **12 sites, all in `lib/data/`, 0 elsewhere** (other mentions are comments) |
| `features/**` → `data/**` | **3** — 2 are `features/auth/data/*` importing the provider-free interface (fine), **1 is a violation** |
| `domain/` → Flutter widgets | **0** |
| `domain/` → `data/` | **0** |
| `core/` → `features/` | **0** |
| `shared/` → `features/` | **0** |
| `GetIt.I` in `presentation/` | **0** |

### HIGH

**H-4 · Four presentation widgets call `OrganizationGateway` directly and orchestrate with local `setState`**

`grep -rn "await serviceLocator<" lib/features` returns **exactly four lines** (verified):
- `lib/features/profile/presentation/profile_screen.dart:131` — `deleteMyAccount`
- `lib/features/orgs/presentation/accept_invitation_screen.dart:72` — `acceptInvitation` (then `auth.hydrate()` + `ActiveOrgStore.select()`)
- `lib/features/orgs/presentation/invite_member_sheet.dart:204` — `inviteMember`
- `lib/features/matters/presentation/matter_create_screen.dart:106` — `listMembers`

Each is a `StatefulWidget` owning the whole flow: in-flight flag, `await`, `switch` on the outcome, `setState`. `INSTRUCTIONS.md:239` forbids presentation calling business helpers directly; `:335` states "no direct data access from widgets/Cubits". **`profile_screen.dart`'s own class doc at `:20-21` claims *"It never calls a gateway"* — falsified by `:131` in the same file.**

**Impact:** four flows have no cubit, so the project's own `bloc_test` doctrine cannot apply; duplicate-submission guards are hand-rolled three times; the same `OrgFailureKind` maps to three different affordances (SnackBar / `errorText` / inline Text) because no orchestration layer owns it. The precedent is self-propagating.
**Fix:** extend `OrgCubit` (already owns roster writes) with `acceptInvitation`/`inviteMember`; add a `ProfileCubit` or `AuthCubit.deleteAccount()`; move `_members` into `MatterCreateCubit`. Screens keep only `BlocBuilder`/`BlocListener`.

**H-5 · `AuthGateway.startDemoSession()` can never succeed on a real build, but the UI exposes it unconditionally**

`lib/core/auth/auth_gateway.dart:40` declares it; `FakeAuthGateway:87` mints the session; `SupabaseAuthGateway:119-128` **always** returns `AuthFailureKind.membershipDenied` — verified in source, including the comment *"Deny rather than fabricate an authority."* `sign_in_screen.dart:110-140` renders "Continue as demo" with no gate, and `env.isConfigured` appears **nowhere in `lib/features/`**.

**Impact:** a primary-looking affordance that cannot work ships on the real build. Security-wise this is a *verified negative* (the demo path cannot grant real access) — the harm is UX and demo credibility, against the project's own "no false assurance" contract.
**Fix:** add `bool get supportsDemoSession` to `AuthGateway` (true in the fake, false in the real) and render the button only when true — keeping the decision in the seam rather than duplicating `env.isConfigured` into presentation.

### MEDIUM

- **M-6 · `ActiveOrgStore` is an app-scoped persisted store living in `presentation/`** — `lib/features/orgs/presentation/active_org_store.dart:6` imports `../../../data/local/org_selection_store.dart` and is registered app-scoped at `service_locator.dart:348-356`. It is the codebase's only presentation→data import and encodes the D-08 session-authority rule. *Fix:* move to `lib/core/organizations/`, update 4 import sites, no behaviour change.
- **M-7 · `PlatformAdminLoaded` fuses two concerns into one 8-field state** (`platform_admin_cubit.dart:43-88`) forcing manual field re-threading at 7 emit sites; the comment at `:137-142` documents a past bug from exactly this. *Fix:* split into `PlatformAdminCubit` + `PlatformAuditCubit`, or add `copyWith`.
- **M-8 · Feature-slice shape: verdict — principled in five of six cases.** `admin`, `orgs`, `search`, `home`, `onboarding` are all correct (their contracts genuinely live in `core/`; materialising empty `domain/` folders would be ceremony-only abstraction). The drift is narrower: `profile` and the write half of `orgs` perform writes with **no presentation-layer orchestration unit to own them** — which is causally why H-4 exists. *Fix:* fix H-4, then write the rule down.
- **M-9 · `lib/core/use_cases/use_case.dart` is a declared architectural layer with zero consumers** — named in `INSTRUCTIONS.md:227`, referenced only by its own test file which defines its own implementations. This is the one place the architecture description and the code disagree. *Fix:* delete it and correct the `INSTRUCTIONS.md` comment, or convert one real flow into a use case.

### LOW

- App-scoped cubits watched with no selector (`home_screen.dart:56`, `settings_screen.dart:32-34`, `member_roster_screen.dart:55`, `organization_hub_screen.dart:67`, `profile_screen.dart:31`).
- A hardcoded English display-name fallback invented in the data layer — `supabase_auth_gateway.dart:148` `displayName: snapshot.displayName ?? 'User'` — the data-layer twin of D-T3, which localized the same fallback in presentation but not here. AR/TR users see "User" as their own name.

### What's done well

1. **Provider containment is absolute** — 12/12 `supabase_flutter` imports in `lib/data/`, 0 elsewhere; the in-flight `list_query_guards.dart` was placed there *because* it touches `Supabase.instance`, so the rule survived an unrelated change.
2. **The auth seam is token-free at two independent layers, enforced by types** — the api exposes only a token-free snapshot and a DTO-free failure enum; the impl is the sole holder of `GoTrueClient` and maps `AuthException` below the seam.
3. **`domain/` is a real, import-clean layer** — 39/39 files, 0 Flutter imports, 0 `data/` imports.
4. **The demo/real flip is inverted correctly and the anon-key guard sits on the registration path**, not a UI path (`service_locator.dart:150`).
5. **State consumption is overwhelmingly sanctioned** — 34 `BlocBuilder` + 32 `BlocProvider` + 5 `BlocListener`, per-screen cubits via `BlocProvider(create:)`, app-scoped singletons with explicit `dispose:`, one shared `ViewState<T>` vocabulary with one renderer.
6. **The in-flight `ViewStateList` API change was applied to all three call sites** — no half-migrated consumer.

---

## 5. Dimension 3 — Code Quality · **6.5 / 10**

> Strongest: the error/observability design and its enforcement — a typed `Result`/`AppError` seam, a redacting reporter, per-domain failure kinds, `strict-casts`/`strict-inference`/`strict-raw-types`, and a behavioural suite that uses real fakes rather than mock theatre. Weakest: the data layer's structural copy-paste sitting right beside that excellent error contract.

### HIGH

**H-6 · The new bounded-read guard has zero test coverage**
`lib/data/list_query_guards.dart` (67 lines, untracked)

`grep -rn "boundedTableSelect\|kSupabaseListRowCap\|kSupabaseListOrderings" test/` → **0 hits** (verified). Every `supabase_*_api_impl_test.dart` injects a stub `TableCaller`, so the real `_boundTable` → `boundedTableSelect` path is never executed. The cap value, the per-table ordering column, and the ascending/descending flags are all unpinned — **which is exactly how H-1 shipped.**

**Fix:** extract the pure decision (`orderingFor(String table)` + the cap constant) and unit-test all 7 mapped tables plus an unmapped one; assert `kSupabaseListRowCap == 200`; add an explicit "long thread keeps the newest rows" test.

**H-7 · Data-layer seam scaffolding duplicated 9× — ~548 lines**
`_kindFor(PostgrestException)`: **9 definitions across 9 files** (verified: admin, billing, documents, matters, matter_write, messaging, notifications, orgs, storage). `_mapFailure(...)`: 9 copies. Plus **10** `enum Supabase*FailureKind` and **9** `class Supabase*Exception` pairs.

**Impact:** the RLS-denial rule (`'permission denied'`/`'row-level security'` → `denied`) is copy-pasted 9×; a provider denial-text change needs 9 coordinated edits, and one miss silently degrades a denial to `unknown`. This is the data-layer analogue of the E1–E10 widget extractions and is **not** covered by the prior (widget-scoped) audit.
**Fix:** shared `classifyPostgrest(PostgrestException)` + `mapSeamFailure(kind, codePrefix, noun)`; keep genuinely domain-specific kinds.

### MEDIUM

- **M-10 · Cubit-scoped list-surface skeleton repeated across ~7 screens** — `approvals_screen.dart:21-87`, `compliance_alerts_screen.dart:19-84`, `task_board_screen.dart:17-82`, `billing_invoices_screen.dart:23-83`, `notification_feed_screen.dart:33-96`, `document_list_screen.dart:44-95`, `message_list_screen.dart:44-95`; **20 files** pair `BlocProvider` with `addPostFrameCallback`. Three pairs are byte-identical. *Fix:* extract `CubitListSurface<TState, TItem>` — the shape `WorkspaceSection<T>` already proved extractable.
- **M-11 · `_AlertTile` hand-rolls `AppTile` exactly — an E8 miss.** `compliance_alerts_screen.dart:108-146` (39 lines) vs `lib/shared/widgets/app_tile.dart:73-119`. Its siblings already delegate (5-line `AppTile` calls in approvals and tasks). *Fix:* replace with an `AppTile` call; 39 lines → ~6.
- **M-12 · Three parallel `Result`-style sealed types** — `core/errors/result.dart:4-31`, `core/organizations/organization_models.dart:182-212`, `core/auth/auth_outcome.dart:47-77`: ~90 lines of identical machinery. The enum-vs-`code` distinction is already erased at the boundary (four cubits flatten failures into `AppError`). *Fix:* collapse the transport onto one `Result<T, F>`.
- **M-13 · Two logging paths** — the `ErrorReporter` seam vs raw `debugPrint` at 7 sites (`supabase_membership_repository.dart:66,76,84`, `auth_cubit.dart:289`, `active_org_store.dart:81,172`). Those diagnostics are not redacted by `Redactor` and not reportable when a real reporter is wired; `dropping row without organization id` is a data-integrity event a Sentry integration would want.
- **M-14 · `home_screen.dart`: a 243-line `build` with 11 near-identical blocks and 5 dead affordances.** Lines 134–214 are eleven copies of `if (capabilities.canX) ...[SizedBox(spaceMd), XEntryCard(onTap: …)]`. The notifications bell (`:97`, `onPressed: () {}` — verified) and all four `PracticeAreaCard`s are tappable but do nothing. These are the **only** no-op handlers in `lib/`.
- **M-15 · Dead code: ~76 lines across 3 units** (verified individually):
  - `lib/shared/responsive/responsive_breakpoints.dart` (46 lines) — `ResponsiveBreakpoint`, `isCompact`, `responsiveHorizontalPadding` have **0 references** in `lib/` or `test/`. Exported by a barrel whose only consumer uses `ResponsiveContent` only. **Confirmed dead.**
  - `lib/core/use_cases/use_case.dart` (11 lines) — zero production consumers; the only test defines its own implementations. **Confirmed dead.**
  - `lib/core/sample_service.dart` (19 lines) — registered in DI and pinned by tests, but its docstring declares it intentional B3 scaffolding. **Not dead code; a LOW hygiene nit** (it does ship a registration into production DI for no reason). *This corrects the code-quality subagent, which listed it as deletable — see §9.*
- **M-16 · Duplicated widget-test scaffolding; no shared pump harness** — 19 files each declare a local `pumpX` helper; `localizationsDelegates: AppLocalizations.localizationsDelegates` appears **76 times**; `configureDependencies()` 111 times; there is no `test/support/`. *Fix:* add `test/support/pump_app.dart` — the complete version already exists at `test/responsive/responsive_smoke_test.dart:51-76`.

### LOW

- `_appError(OrgFailure)` declared 3× with only a code prefix differing.
- The only `catch (_)` in `lib/` is at `forgot_password_reset_screen.dart:66-73` — documented and safe, but the exception object is discarded.
- Three `blocTest`s wrapped in immediately-invoked local closures (`org_audit_cubit_test.dart:43-64,74-98,100-130`) — the only such occurrence in the suite.
- 4 dated docs unreferenced by any index (167 of 171 are linked).

### What's done well

1. **A real error-handling contract applied consistently at the seam** — typed per-domain failure kinds, `Result<T>`/`AppError` boundaries, a `Redactor` stripping emails/bearer tokens/sensitive keys before any diagnostic is stored, with tests. The api impls catch `on PostgrestException` and `on Object` separately so transport failures become typed `providerUnavailable`, never raw exceptions.
2. **Lint discipline above the framework default** — `strict-casts`/`strict-inference`/`strict-raw-types` plus 11 opt-in lints, with only **4 `// ignore:` in all of `lib/`** (3 generated). `strict-raw-types` is why `dynamic` is confined to row shapes.
3. **Tests assert behaviour, not implementation** — 33,483 test LOC vs 27,283 lib LOC; only **32** `isNotNull` fillers and only **5** `verify(...)` calls across the whole suite. The suite drives real `fake_*_gateway` doubles instead of mocks.
4. **SQL is factored, not copy-pasted** — shared `write_audit` + `has_org_role`/`is_platform_owner`/`active_membership` helpers; the `*_platform` RPCs were diffed and are genuine variants, confirming the prior audit's "structurally different" call.
5. **The in-flight perf slice is coherent in design** — `ViewStateList` re-generified with a lazy `ListView.builder`, and the composer dropped per-keystroke `setState` for a scoped `ValueListenableBuilder`. *(Its execution is another matter — see §1.)*

---

## 6. Dimension 4 — Security · **7.5 / 10**

> **No CRITICAL. No exposed secret, no client-reachable authorization bypass, no injection sink with a live data path.** Server-side authorization is excellent; the weak spot is client-side secret-at-rest hygiene.

### MEDIUM

**M-17 · Supabase session (access + refresh token) persisted in plaintext `SharedPreferences`, with Android Auto Backup enabled**

`lib/data/auth/supabase_auth_api_impl.dart:26-33` passes `FlutterAuthClientOptions(authFlowType: pkce, detectSessionInUri: true)` with **no `localStorage`** (verified). supabase_flutter 2.16.0 then defaults to `SharedPreferencesLocalStorage` (key `sb-<ref>-auth-token`) and writes the whole serialized `Session` — access token, **refresh token**, provider token — in plaintext. Separately, `<application>` at `android/app/src/main/AndroidManifest.xml:5` sets **no `allowBackup`**, **no `fullBackupContent`**, **no `dataExtractionRules`** (verified), so the platform default `allowBackup=true` puts the `shared_prefs` XML in Auto Backup / device-transfer scope. `Info.plist` has no backup exclusion either.

**Impact:** a long-lived refresh token is recoverable from app-private storage (root/jailbreak, ADB backup on a debug build, forensic image, or Auto Backup extraction), letting an attacker mint access tokens and read whatever RLS grants the victim. Preconditions: physical or logical access to the device — **not remotely exploitable**, hence MEDIUM rather than CRITICAL. **This is the single item that must be resolved before the app may point at production.**
**Fix:** (1) route session persistence through an encrypted store (`AuthClientOptions(localStorage:)` over Keystore/Keychain); (2) `android:allowBackup="false"` plus `dataExtractionRules`/`fullBackupContent` excluding `shared_prefs`, and an iCloud backup exclusion on iOS. The app's own stores hold only locale/theme/active-org-id/notification-prefs — no PII, no tokens — so this touches only the provider-owned key.

### LOW

- **L-2 · The anon-key guard is runtime-only** — `ensureAnonKey` (`supabase_env.dart:63-74`) does exactly what its docstring claims (decodes segment 2, requires `role == 'anon'`, throws otherwise; pinned by `supabase_env_test.dart:62-67`). But the value arrives via `String.fromEnvironment` (a **compile-time constant**), so a service-role key is baked into the release binary *before* rejection. The guard prevents **use**, not **embedding**. *Fix:* add a build/CI assertion; keep the runtime guard as the second layer.
- **L-3 · Inconsistent defensive parsing of PostgREST rows** — `SupabaseStorageGateway._fileFromRow:55-94` guards every field and raises a typed `FormatException` mapped to a redaction-safe `AppError` (the correct pattern); sibling gateways use bare casts (`row['role'] as String?`, `DateTime.parse(row['created_at'] as String)`) which can throw outside their `on …` clauses. Enum/status parsing *is* defensive, so the gap is narrow, and no client-controlled path reaches a malformed payload. *Fix:* adopt the storage-gateway pattern.
- **L-4 · "Continue as demo" renders on a configured build where it always fails** — see H-5 (architecture).
- **L-5 · One-time invitation tokens copied to the system clipboard** — `invite_member_sheet.dart:222,240`, `member_roster_screen.dart:292`. Same class as documented F-06 (token in a deep-link URL) but a **different channel**. Mitigated: single-use, sha-256 at rest, 7-day expiry, JWT-email match required.
- **L-6 · CI actions tag-pinned, not SHA-pinned** — `ci.yml:42,72`, `ledger-selftest.yml:41`. Kept LOW because both workflows declare `permissions: contents: read`, reference **no secrets**, and contain no build/deploy/sign step. *(Related: `pubspec.yaml`'s Flutter constraint was loosened to a range in-flight while CI still pins 3.44.4 — reproducibility drift; `pubspec.lock` is committed, which is good.)*

### Accepted risks / documented deferrals (not findings)

MFA/SSO deferred (D-07, F-02 **ACCEPTED**) · no throttling beyond GoTrue defaults (F-07 **ACCEPTED**) · invite emails absent, token out-of-band (F-05 **ACCEPTED**) · signed-URL TTL window (F-03 / D-STR4 **ACCEPTED**) · denied RPC attempts not audited, deliberate (F-08 **ACCEPTED**) · demo clients hold no memberships (F-09 **ACCEPTED**) · self-scoped helpers exposed as `/rpc/` (F-11 **ACCEPTED**) · owner-deny as operational invariant (F-01 **CLOSED**) · Realtime delivery proven by RLS proxy (F-04 OPEN — verification gap, not a defect) · no backend package before P0 closes (`adr/0007`).

### Verified negatives (hypotheses opened and refuted)

Client cannot self-grant role/org/owner flag · no RPC trusts a client-supplied `org_id`/`role` (`create_matter.sql:11-38` re-derives inside the body) · **all 20 client-EXECUTE RPCs carry in-body gates**, and trigger-only definer helpers are EXECUTE-revoked from `public, anon, authenticated` · **13 tables ↔ 13 `enable row level security`**, zero `using (true)` · no PostgREST/RPC filter interpolation and no dynamic `EXECUTE`/`format()` in `supabase/` · storage traversal blocked by the path-segment policy · no deep-link redirect param · sign-out removes the persisted session · no PII in the app's own prefs · `Equatable.toString()` returns only the type name, so `InviteResult{email,token}` and `Message{body}` do not leak · auth error text is localized and non-enumerating.

**Secrets:** no JWT/`service_role`/private key/non-placeholder credential in tree **or full history** (`git log --all -S"eyJ"` → 0 commits; `.env` never tracked). `.gitignore:48-55` covers `.env`/`.env.*`/`*.env`.

**Dependencies:** lockfile committed, 116 packages. One advisory checked and cleared — `dart_jsonwebtoken` 3.4.1 (transitive) is past the fix for AIKIDO-2024-10308. **No dependency finding.**

**OWASP Mobile:** M1 low · M2 low · **M3 strong** · M4 low · **M5 clean/N-A** (no cleartext, no ATS exception, no WebView) · M6 low–medium · M7 expected gap (no obfuscation/`FLAG_SECURE` — appropriately deferred for a synthetic-data demo) · M8 low · **M9 weakest** · M10 N/A.

### What's done well

1. **Default-deny RLS + a real positive+negative battery** — 13 tables / 13 RLS, zero `using (true)`, every content policy carrying the load-bearing org-equality clause, exercised by `supabase/tests/01…16` with structural pins in `verify_policy_tests.sh`.
2. **Server-side authorization is genuinely server-side** — all 20 client-EXECUTE RPCs re-derive from `auth.uid()` in the definer body; `write_audit` is client-unreachable so audit rows cannot be forged.
3. **The anon-key guard is real and fail-fast**, wired on the registration path, and honest about being a config guard rather than a boundary.
4. **A disciplined privacy seam** — one provider-importing file that drops tokens/GoTrue exceptions; a `Redactor` masking credential/PII keys and scrubbing emails + `Bearer` from free text; `toRedactedMap` on all three PII request VOs per ADR-0003.
5. **A destructive-test guard on the shared dev project** — `verify_policy_tests.sh:696-713` hard-refuses if the test DB URL points at the known dev ref.
6. **Least-privilege CI with no secrets** — `contents: read`, no `secrets.*`, no deploy step, plus a nightly `--selftest` proving the gates still have teeth.

---

## 7. Dimension 5 — Performance · **6.5 / 10**

> Strongest: the data-access seam — every *table* read is bounded and ordered through one guard, and the in-flight pass added a reusable lazy-list primitive plus a real fix to the only per-keystroke rebuild. Weakest: the two places that discipline wasn't carried — the platform-admin **RPCs** still return unbounded result sets rendered eagerly, and most list screens still expand rows into a `Column` inside a non-lazy `ListView`.

### HIGH

**H-8 · Platform-admin reads bypass the bounded-query guard: unbounded RPCs, eager render, O(members × orgs) join**

`lib/data/admin/supabase_platform_admin_api_impl.dart:47-84,111-151`; `supabase/rpc/list_members_metadata.sql:40`; `supabase/rpc/read_platform_audit.sql:41`; `lib/features/admin/presentation/platform_admin_lists.dart:29,45,66,100-107`

Verified: all three admin RPCs carry `ORDER BY` and **no `LIMIT`**. `list_members_metadata()` returns `memberships JOIN profiles` for every membership; `read_platform_audit()` returns the **entire `audit_events` table** — and it calls `write_audit('platform:read_audit',…)` *before* reading, so **each read appends to the table it just read in full**. The client then renders these in a non-lazy `ListView(children: [...organizations.map(…), ...members.map(…)]` (verified at `:29`), and resolves each member's org name via `_orgNameFor` — a **linear scan of `organizations` per member** (verified at `:100-107`) → O(members × orgs) per build over two unbounded collections.

`list_query_guards.dart` bounds every **table** SELECT, but the admin surface uses four **RPCs**, which bypass it.

**Impact:** the one path meeting the "unbounded query that will grow without limit" definition — and self-amplifying. Held at HIGH rather than CRITICAL only because it is gated to the single `platform_owner_admin` role in a demo; **raise to CRITICAL if the surface ships to real tenants.** It is the known unfinished half of the in-flight slice, whose own comment says paging "remains a separate slice".
**Fix:** add `p_limit`/`p_offset` (or a literal `limit 200`) to all four RPCs; build `Map<String,String> orgNameById` once before the members loop; move the success arm to `ListView.builder`.

### MEDIUM

- **M-18 · N+1 on the hottest read path** — `supabase_matter_gateway.dart:79-91` loops distinct org ids and `await`s `_orgGateway.listMembers()` **serially** (verified). A `grep` for `await` inside `for` across all of `lib/data` + `lib/features` returns exactly this one site — the app's only N+1. Deduped by `.toSet()`, so O(distinct orgs), but `fetchMatters()` costs `1 + N` sequential round-trips and is the hottest read (matter list, matter details, document vault, message list, and **every debounced search**). *Fix:* `await Future.wait(orgIds.map(…))`; better, cache the roster per org and invalidate on `hydrate()`.
- **M-19 · No caching layer anywhere** — 20 `addPostFrameCallback(load)` sites; each list cubit is created per route entry and loads from `initState`, so navigating away and back re-issues the identical read. Search amplifies it: each debounced query re-fetches **all four** lists. *Fix:* a short-TTL in-memory cache in each gateway, invalidated on the known mutation paths.
- **M-20 · Most list surfaces still build every row eagerly** — `ListView(` appears **21 times** in `lib/features` vs **3** `ListView.builder/separated` (verified). Each success arm is a `Column` whose children are `for (final X x in list) ...<Widget>[tile, SizedBox]` nested in a non-lazy `ListView`, so `SliverChildBuilderDelegate` culling never applies. The in-flight pass fixed exactly this on four surfaces via the now-lazy `ViewStateList` but did not convert the rest. *Fix:* route them through `ViewStateList` + `tileBuilder` — the same mechanical change already applied to approvals/compliance/tasks.
- **M-21 · `visibleMatters` recomputes the filtered projection twice per build** — `matter_state.dart:23-34` is a getter allocating a fresh list on **every access**; `matter_list_screen.dart:137` and `:141` both read it in one build (verified). *Fix:* bind it to a local once.
- **M-22 · Startup blocks the first frame on a network round-trip** — `main.dart` awaits `SharedPreferences.getInstance()` (`:36`), `localeCubit.load()` (`:39`), `themeCubit.load()` (`:43`), `authCubit.restore()` (`:49`) — all **before `runApp` at `:63`** (verified). The restore path resolves a persisted session through `_membershipRepository.loadMemberships(...)` → a PostgREST read. With a persisted session the app awaits a network round-trip with **no first frame rendered**. *Fix:* `runApp` first and let the router render `AuthStatus.restoring` (the status already exists), or race hydration against a short timeout.
- **M-23 · Realtime: one channel for the app lifetime, never re-pointed at the open thread** — `watchMessages(threadId)` opens a channel only when `_threadId == null` (verified at `supabase_message_realtime_api_impl.dart:34-40`), pinning name and filter to the **first** thread; a second thread returns the same stream, still filtered to the first. The cubit's `unsubscribe()` cancels only its stream subscription, never the channel. **Good news:** because the api impl is a shared singleton there is **no per-navigation channel leak**, and filtering is server-side. *Fix:* close and re-open on switch; have the cubit release the channel on dispose.

### LOW

- **L-7 · O(n²) matter resolution inside document/thread list builds** — `resolveMatterByTitle` is a linear scan called once per row inside build (`document_list_screen.dart:195`, `message_list_screen.dart:200`). Sub-millisecond at the 200-row cap, but the complexity class is wrong. *Fix:* build a `Map<String, Matter>` once per build.
- **L-8 · 34 of 36 `BlocBuilder`s lack `buildWhen`; no high-frequency emitter drives them** (verified 36/2/0/0). The honest reading: **no cubit emits at keystroke frequency** — search is 300 ms-debounced, and the composer's per-keystroke `setState` was removed in-flight. Two instances still worth tightening: the transcript (rebuilds on `sending`/`sendError`) and `search_screen.dart:141`, which wraps the `TextField` inside the `BlocBuilder`. *"34 of 36" reads worse than its consequence.*
- **L-9 · Three redundant JSON decodes per notification-feed load** — `notification_cubit.dart:64-68,93-115` decodes the same small payload three times. *Fix:* read once, derive the set.
- **L-10 · `DateFormat` constructed per row per build** — `date_formatting.dart:14`, called from `document_list_screen.dart:226` and `notification_feed_screen.dart:150`. *Fix:* memoize one per locale.
- **L-11 · ~2.3 MB of unused italic font shipped** — all three families are genuinely used, but `NotoSans-Italic-Variable.ttf` is declared at `pubspec.yaml:43-44` and `grep "FontStyle.italic" lib/` returns **zero hits**, so nothing can select it. It is ~46% of the ~5.0 MB font payload. *Fix:* remove the asset entry (and file).
- **L-12 · `Opacity` per roster row forces a per-row layer** — `member_roster_screen.dart:373`, `Opacity(opacity: inactive ? 0.55 : 1, …)` pushes a `saveLayer` per visible dimmed row. The only such op in `lib/`; there are no `Image.*` widgets at all. *Fix:* dim via colour alpha.

### What's done well

1. **Every table read is bounded and deterministically ordered through one audited guard** — `.order()` per table + a hard `.limit(200)`, consumed by all seven Supabase table api impls. `grep "\.select(" lib/` returns only the guard itself. **The highest-value change in the tree** (its correctness and tests are another matter — see H-1/H-6).
2. **A principled lazy-list primitive exists and is being adopted** — `view_state_list.dart` makes the success arm a `ListView.builder` while preserving the tile/gap/note rhythm. Already used by approvals, compliance, tasks, and the transcript.
3. **Controller/subscription lifecycle hygiene is complete** — all 20 `TextEditingController`s disposed including the generated OTP row and the composer's `FocusNode`; `search_screen.dart:126-131` cancels its `Timer` *and* disposes its controller; `AuthCubit.close()` cancels its session subscription. No undisposed `AnimationController`, no unpaired listener.
4. **`addPostFrameCallback` never repeat-fires** — all 20 sites are in `initState`, guarded by `mounted` plus a state predicate.
5. **DI is entirely lazy** — `registerLazySingleton` for every registration, nothing constructed speculatively. Pre-`runApp` cost is the awaited `load()`/`restore()` calls, not DI.
6. **Local persistence is off the hot path and payloads are small** — the nine `lib/data/local/*` stores plus `ActiveOrgStore` read/write a single scalar or one tiny JSON object, never in `build()`.
7. **Generated l10n is correctly wired for tree-shaking** — both `localizationsDelegates` and `supportedLocales` are passed to `MaterialApp.router`, so unused locale bundles are stripped.

---

## 8. Overall score, top 5, and roadmap

### Weighted overall: **6.95 ≈ 7.0 / 10**

| Dimension | Score | Weight | Weighted |
|---|---|---|---|
| Security | 7.5 | 25% | 1.875 |
| Clean architecture | 8.0 | 20% | 1.600 |
| Code quality | 6.5 | 20% | 1.300 |
| Maintainability | 6.0 | 20% | 1.200 |
| Performance | 6.5 | 15% | 0.975 |
| **Total** | | **100%** | **6.95** |

**How to read a 7.0.** This is a well-above-average codebase with a below-average *current working tree*. The architecture, the security posture, the error contract, and the governance regime are all stronger than the typical production Flutter app — the 8.0 for clean architecture is earned by measurement, not aspiration. What drags the composite down is that the two structural layers the refactor program never reached (the data-layer seam plumbing and the cubit/state skeleton) are the ones carrying the most copy-paste, and that the in-flight slice is currently non-compiling and untested.

The committed revision (`ec4eb73`) is materially better than the tree: it analyzes clean and its suite passes. **A score of 7.5 would be defensible for HEAD alone.**

### Top 5 most critical issues, ranked by priority

> **Note on the ranking:** severity ranks the *defect*; priority ranks the *action*. Item 5 is MEDIUM as a defect (the app is demo-scoped) but is the single item that must be resolved before the app may point at production, which makes it P1 by priority. Nothing below is hidden — item 6 is called out explicitly.

---

**1 · P0 — The working tree does not compile; all 1356 tests are blocked**
`lib/data/list_query_guards.dart:64` · *Effort: ~5 lines*

```
error - A value of type 'PostgrestTransformBuilder<List<Map<String, dynamic>>>'
can't be assigned to a variable of type 'PostgrestFilterBuilder<List<Map<String, dynamic>>>'
- lib/data/list_query_guards.dart:64:13 - invalid_assignment
```

Verified three ways: `flutter analyze` → 1 error; `flutter test` on a *documents* test → compilation failed; `flutter test` on the **unrelated** `test/core/roles/user_role_test.dart` → **same compilation failure**. Because `flutter test` compiles the whole `lib/` bundle, **not one of the 1356 tests can run**, and CI's second gate (`analyze`) would fail. In postgrest 2.8.0, `.order()` returns `PostgrestTransformBuilder`, not `PostgrestFilterBuilder`.

**Fix** — filter on a `PostgrestFilterBuilder`, then order on a transform-typed variable:

```dart
PostgrestFilterBuilder<List<Map<String, dynamic>>> filtered =
    Supabase.instance.client.from(table).select(columns);
if (filterColumn != null && filterValue != null) {
  filtered = filtered.eq(filterColumn, filterValue);
}
final (String orderColumn, bool descending) =
    kSupabaseListOrderings[table] ?? ('', false);
PostgrestTransformBuilder<List<Map<String, dynamic>>> query = filtered;
if (orderColumn.isNotEmpty) {
  query = query.order(orderColumn, ascending: !descending);
}
return query.limit(kSupabaseListRowCap);
```

Then `git add lib/data/list_query_guards.dart` — it is **untracked**, which is why CI never saw it.

---

**2 · P0 — Capped message reads return the 200 *oldest* messages (silent data loss)**
`lib/data/list_query_guards.dart:36` + `:61-66` → `lib/data/messaging/supabase_message_api_impl.dart:42-47` · *Effort: ~3 lines + 1 test*

`'messages': ('sent_at', false)` is the only ascending entry, so `boundedTableSelect` issues `ORDER BY sent_at ASC LIMIT 200` — the **200 oldest**. The newest messages vanish from any thread over 200 rows, with no error and no indicator. This is the worst possible direction for a legal conversation: the missing rows are the ones a user scrolls for. It would ship the instant item 1 is fixed.

**Fix:** `'messages': ('sent_at', true)`, then reverse the mapped list in the gateway before emitting (the live-append path needs chronological order, so fetch descending and reverse). At minimum, surface the cap in the UI.

---

**3 · P0 — The new bounded-read guard has zero tests**
`lib/data/list_query_guards.dart` (untracked, 67 lines) · *Effort: one test file, ~40 lines*

`grep -rn "boundedTableSelect\|kSupabaseListRowCap\|kSupabaseListOrderings" test/` → **0 hits** (verified). Every api-impl test injects a stub `TableCaller`, so the real path never executes and the cap, the columns, and the direction flags are all unpinned. **This is the reason items 1 and 2 could exist at the same time.**

**Fix:** extract the pure decision (`orderingFor(String table)` + the cap constant) and unit-test all 7 mapped tables plus an unmapped one; assert `kSupabaseListRowCap == 200`; add an explicit "a long thread keeps the newest rows" test. This test would have caught item 2 on the day it was written.

---

**4 · P1 — Four presentation widgets call gateways directly, bypassing the cubit layer for consequential writes**
`profile_screen.dart:131` (account deletion) · `accept_invitation_screen.dart:72` · `invite_member_sheet.dart:204` · `matter_create_screen.dart:106` · *Effort: medium (one to two slices)*

Verified: exactly four `await serviceLocator<…>` calls exist under `lib/features`. Each is a `StatefulWidget` owning the whole flow with hand-rolled `setState`. This contradicts `INSTRUCTIONS.md:239` and `:335`, and **`profile_screen.dart`'s own class docstring at `:20-21` claims "It never calls a gateway" — falsified at `:131` in the same file.** These are the highest-consequence writes in the app (account deletion, invitation acceptance and minting).

**Fix:** extend `OrgCubit` (already owns roster writes) with `acceptInvitation`/`inviteMember`; add a `ProfileCubit` or `AuthCubit.deleteAccount()`; move `_members` into `MatterCreateCubit`. Screens keep only `BlocBuilder`/`BlocListener`. Then write the slice-shape rule into `INSTRUCTIONS.md` so the precedent stops propagating.

---

**5 · P1 — Session tokens persisted in plaintext, with Android Auto Backup enabled**
`supabase_auth_api_impl.dart:26-33` + `AndroidManifest.xml:5` · *Effort: small, but touches auth* · **production gate**

Verified: `initializeSupabase` passes no `localStorage`, so supabase_flutter 2.16.0 writes the full session — including a **long-lived refresh token** — to plaintext `SharedPreferences`. The manifest sets no `allowBackup`, so the platform default puts that XML in Auto Backup scope. A refresh token recovered from app storage lets an attacker mint access tokens and read whatever RLS grants the victim.

MEDIUM as a defect (requires device access; not remotely exploitable; demo-scoped) but the clear priority for production: for a legal-privileged-communications product this is the difference between a demo and something you can ship.

**Fix:** route session persistence through an encrypted store (`AuthClientOptions(localStorage:)` over Keystore/Keychain) and set `android:allowBackup="false"` plus `dataExtractionRules`/`fullBackupContent` excluding `shared_prefs`.

---

**Close behind — 6 · P1 — Platform-admin unbounded RPCs + eager render + O(members × orgs)**
`read_platform_audit.sql:41` (no LIMIT — reads the whole `audit_events` table, and *writes* an audit row before reading it, so it self-amplifies), `list_members_metadata.sql:40`, `platform_admin_lists.dart:29`, `_orgNameFor:100-107`. HIGH by severity, but role-gated to a single `platform_owner_admin` account in a demo, which is why it sits here rather than in the top 5. **Add `p_limit`/`p_offset`, build the org-name map once, use `ListView.builder`.**

### Prioritized roadmap

**P0 — broken or trivially wrong now**

| # | Item | Effort | Context to act on standalone |
|---|---|---|---|
| P0.1 | Fix the compile error in `list_query_guards.dart:64` | ~5 lines | Retype the query variable (snippet above). Unblocks 1356 tests + CI. |
| P0.2 | `git add lib/data/list_query_guards.dart` | seconds | It is untracked; CI cannot see it. |
| P0.3 | Flip `'messages'` to `('sent_at', true)` + reverse at the gateway | ~3 lines | See item 2. |
| P0.4 | Add the guard test file | ~40 lines | See item 3. Would have caught P0.3. |
| P0.5 | Run `flutter analyze` + `flutter test` before leaving any slice | process | The habit, not a task. Add it to the definition-of-done checklist if it isn't already there. |

**P1 — this sprint**

| # | Item | Effort |
|---|---|---|
| P1.1 | Move the 4 gateway calls behind cubits (item 4) | medium |
| P1.2 | Encrypted session storage + `allowBackup="false"` (item 5) | small |
| P1.3 | Bound the 4 admin RPCs; `ListView.builder`; org-name map (item 6) | medium |
| P1.4 | Extract the shared `classifyPostgrest` / `mapSeamFailure` (H-7, ~548 lines) | medium |
| P1.5 | Fix the N+1 in `_displayNamesFor` (`Future.wait`) (M-18) | small |
| P1.6 | Gate "Continue as demo" behind `supportsDemoSession` (H-5) | small |
| P1.7 | Delete or give producers to `ViewOffline`/`ViewUnauthorized` (M-1) | small |
| P1.8 | Move `ActiveOrgStore` to `lib/core/organizations/` (M-6) | small |
| P1.9 | Extract `CubitListSurface` + route remaining lists through `ViewStateList` (M-10, M-20) | medium |
| P1.10 | Add `copyWith` to the sealed loaded states (M-2, M-7) | small |

**P2 — next sprint**

| # | Item | Effort |
|---|---|---|
| P2.1 | Generic `ListState<T>` + `ListCubit<T>` (H-3) | medium |
| P2.2 | Document the adapter-placement rule; add `lib/data/*` header comments (H-2) | small |
| P2.3 | Extract `_registerFlip<T>`; split `configureDependencies`; table-drive home entries (M-5, M-14) | medium |
| P2.4 | Delete `responsive_breakpoints.dart` + `use_cases/use_case.dart`; record or delete `sample_service.dart` (M-15) | small |
| P2.5 | Unify the three `Result` types (M-12) | medium |
| P2.6 | Add `test/support/pump_app.dart`; migrate 19 local helpers (M-16) | small |
| P2.7 | Adopt `AppTile` in `_AlertTile` (M-11) | tiny |
| P2.8 | Route the 7 raw `debugPrint` sites through `ErrorReporter` (M-13) | small |
| P2.9 | Caching layer for list reads (M-19) | medium |
| P2.10 | `runApp` before auth hydration; short timeout race (M-22) | small |
| P2.11 | Re-point the realtime channel per thread (M-23) | small |
| P2.12 | Replace `RoleCapability` table with an exhaustive switch (M-3) | small |
| P2.13 | Add a dated addendum to `screen_completeness_matrix_2026-08-09.md` (M-4) | tiny |
| P2.14 | Remove the unused italic font (~2.3 MB) (L-11) | tiny |

---

## 9. Verification notes and corrections

The audit's method explicitly requires re-opening the source for every CRITICAL/HIGH claim. What that step changed:

**The CRITICAL was found only by verification.** All five subagents were instructed not to run `flutter analyze` (to keep them fast), so **none of them noticed that the in-flight file does not compile.** Static reading cannot detect a type error. The consolidating agent's analyzer run is the single highest-value output of this audit, and the control-test experiment (`user_role_test.dart`, unrelated to the modified files, failing with the same error) is what proved the failure is a `lib/` compile error blocking the entire suite rather than a flaky `flutter_tester` WebSocket issue — which is what the first test run appeared to show.

**Confirmed as reported:** the messages ordering inversion (H-1, independently found by two agents and verified against the flag arithmetic); the 9× `_kindFor`/`_mapFailure` duplication (verified: 9 definitions across 9 files, 10 enums, 9 exception classes, ~548 lines); the four direct-gateway widgets (verified: exactly 4 grep hits); `startDemoSession` hard-denying (read the source); the unbounded admin RPCs (verified: `ORDER BY` present, `LIMIT` absent in all three); the missing `allowBackup` (verified absent from the manifest); the 20 `addPostFrameCallback` screens; the 36/2/0/0 `BlocBuilder`/`buildWhen`/`BlocSelector`/`context.select` counts; 21 vs 3 `ListView(` vs `ListView.builder`; the N+1 serial `await` (the only one in the codebase); the zero test coverage of the guard.

**Corrected:**

1. **`lib/core/sample_service.dart` is not dead code.** The code-quality subagent listed it as deletable. Its own docstring (`:1-7`) declares it intentional B3 bootstrap scaffolding ("intentionally non-functional"), it is registered at `service_locator.dart:143-144`, and `service_locator_test.dart:315-354` pins it as the DI-resolution proof. Downgraded to a LOW hygiene nit — a bootstrap artifact that arguably should not still ship a production DI registration. *(The architecture subagent had this right and explicitly declined to flag it.)*
2. **The two "duplicated skeleton" findings are distinct, not one finding double-counted.** Maintainability H-3 is about the **cubit `load()` bodies** (6 byte-identical normalised); code-quality M-10 is about the **screen scaffolding** (7 near-identical `Scaffold`+`BlocProvider`+surface shells). Both verified; they are two layers of the same structural gap and are reported separately for that reason.
3. **Feature count corrected.** The audit brief said 25 features under `lib/features/`; the tree has **19** (the extra directory entries were empty parent folders). Similarly, `lib/` holds **274 hand-written** Dart files / 27,283 LOC once the 4 generated l10n files are excluded — the headline "278 files / 33,236 LOC" includes generated code.
4. **`ResponsiveBreakpoint` confirmed dead** (0 references in `lib/` or `test/` excluding its own definition) — this one stands as reported.
5. **The in-flight slice is not "unexplained churn."** The 15 modified files are a coherent perf-hardening pass (`boundedTableSelect`, lazy `ViewStateList`, scoped `buildWhen`, lazy transcript). Two subagents independently identified it and both correctly credited it as in-flight work rather than flagging it as drift. Its *design* is sound; its *execution* is the subject of items 1–3.

---

## 10. Appendix — verification steps before shipping

The commands that would have caught each P0, and that should gate the slice that fixes them:

```bash
# P0.1 / P0.2 — the compile error and the untracked file
git status --porcelain | grep list_query_guards   # expect: ?? (untracked)
flutter analyze                                   # expect: No issues found
dart format --set-exit-if-changed lib test        # CI gate 1

# P0.3 — the whole suite, and specifically the guard
flutter test                                      # expect: all tests pass
grep -rn "boundedTableSelect" test/               # expect: >=1 hit (currently 0)

# P0.4 — a targeted regression test for the truncation
#   Assert: a thread with >200 rows returns the NEWEST rows, not the oldest.
flutter test test/data/messaging/ --name "long thread"

# The project's own gates, unchanged
bash scripts/verify_ledger.sh                     # README/test-count lockstep
bash scripts/verify_policy_tests.sh --check       # RLS battery structural check

# P1.2 — security
grep -rn "allowBackup" android/app/src/main/AndroidManifest.xml   # expect: a value
grep -rn "localStorage" lib/                                      # expect: a non-default store
```

**The one-line lesson.** `flutter analyze` runs in 15 seconds and is already wired into CI. It caught a total build failure that five static-reading agents, 1356 tests, an 891-line DI test, a ledger verifier, and 81 SQL policy batteries did not — because none of them had ever been pointed at the uncommitted file. Run it before you leave a slice, and `git add` new files so the gates that already exist can see them.

---

## 11. Execution close-out (2026-09-21, same day)

The P0 roadmap (§8) was executed immediately after the audit. All gates green.

| # | Change | Files |
|---|---|---|
| P0.1 | Fixed the `invalid_assignment` compile error — filter chain built on `PostgrestFilterBuilder`, then widened once to `PostgrestTransformBuilder` for `.order()`/`.limit()` (postgrest 2.8.0 declares those on the **supertype**, so the old variable type failed at the ordered re-assignment) | `lib/data/list_query_guards.dart` |
| P0.3 | `'messages'` flipped to `('sent_at', true)` (newest-first cap read) + the gateway reverses the mapped list to chronological, restoring the detail screen's render contract and the live-append path; both doc comments updated to match | `lib/data/list_query_guards.dart`, `lib/data/messaging/supabase_message_gateway.dart`, `lib/data/messaging/supabase_message_api_impl.dart` |
| P0.4 | New unit tests for the guard's pure decision: cap constant, all 7 mapped orderings, unmapped-table fallback, and the **"every mapped table is fetched DESCENDING"** invariant that fails the moment any cap is paired with an ascending order again | `test/data/list_query_guards_test.dart` (new) |
| P0.3 | Regression test pinning the reversal: newest-first rows in → chronological VOs out | `test/data/messaging/supabase_message_gateway_test.dart` |
| — | Two pre-existing failures in the in-flight `ViewStateList` rework repaired: the harness now installs the l10n delegates (the rework's error arm reads `AppLocalizations.of(context)` — 76 other widget tests already do this), and the lazy-success test asserts the footer **absent** before scrolling (it is the builder's last row; finding it immediately would prove the arm still eager) | `test/shared/widgets/view_state_list_test.dart` |
| P0.2 | New files staged (`git add`) — untracked files are invisible to `git grep`, which is how the ledger gate and CI would have missed them | staged: `list_query_guards.dart` + its test + the gateway |

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1368 All tests passed** (1356 → 1368) · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0** · README lockstep updated (1353/1353/1356 → 1365/1365/1368).

**Environment note for this machine:** `HTTP_PROXY` is set with an empty `NO_PROXY`, which routes the flutter_tester's localhost WebSocket through the proxy — every `flutter test` fails with `Unable to connect to flutter_tester process: WebSocketException`. Run tests with `NO_PROXY="localhost,127.0.0.1" flutter test …`. A compile error surfaces as `Compilation failed for testPath=…`; the WebSocket error means compilation already succeeded.

**Ledger-gate discovery:** `verify_ledger.sh` counts declarations via `git grep` (tracked files only) and requires the README to match in two forms. The gate was **already failing before this fix slice** — the in-flight `ViewStateList` rework had shifted the count and the README had drifted; it now passes again.

**Not done (owner-gated per `INSTRUCTIONS.md`):** nothing committed or pushed. Staged files await review; the P1+ roadmap (§8) is untouched.

### 11.1 P1 execution (2026-09-21, same session)

Three P1 items landed after the P0 slice, chosen as small/mechanical and **disjoint from the in-flight working set**; the medium refactors (P1.4's 548-line seam dedup, P1.1's cubit extraction, P1.3's admin-RPC SQL) stay owner-gated because they touch in-flight files or require SQL apply gates.

| # | Item | Change |
|---|---|---|
| P1.2 | Android backup hygiene | `android:allowBackup="false"` on the application tag — the plaintext `sb-<ref>-auth-token` shared pref leaves Auto Backup / device-transfer scope. **iOS half remains open**: it requires the `flutter_secure_storage` (Keychain) dependency decision, which is an owner-gated package addition per the repo's dependency policy. |
| P1.5 | The codebase's only N+1 | `_displayNamesFor` now fans the per-org roster reads out with `Future.wait` over the deduped ids (`1 + N` sequential round-trips → `N` concurrent) on the hottest read path (matter list / details / document vault / message list / every debounced search). Per-org failure tolerance preserved — `listMembers` resolves to a typed `OrgOutcome`, so `Future.wait` cannot short-circuit. Behaviour-invariant; the existing outcome tests pin it. |
| P1.6 | Demo-shortcut seam gate | New `AuthGateway.supportsDemoSession` (fake → true, real provider → false); surfaced on `AuthCubit` next to the `recoveryPending` precedent; the sign-in screen renders the demo button + notice only when true. A configured build no longer ships a primary-looking control whose `startDemoSession` can only ever deny. Pinned by an unsupported-posture test (gateway) and a hidden-shortcut test (screen); the interface change swept all 11 test `AuthGateway` fakes (mechanical `=> true`). |

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1370 All tests passed** (1368 → 1370) · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0** · README lockstep 1365/1365/1368 → 1367/1367/1370.

**Landed as** `86f6241` — `fix(data,ui,auth): audit 2026-09-21 P0/P1 — …` (32 entries; two renames detected: the store and its test).

**Still open from the P1 list (owner-gated):** P1.1 (four widgets → cubits — **planned, awaiting owner sign-off on the owner-mapping: see `docs/p1_1_gateway_call_migration_plan_2026-09-22.md`**), P1.3 (admin RPC `LIMIT` + eager render — SQL apply slice), P1.4 (seam-classification dedup, ~548 lines across 18 files), P1.7 (`ViewOffline`/`ViewUnauthorized` delete-or-produce decision + ledger entry), P1.8 (`ActiveOrgStore` move), P1.9 (`CubitListSurface`), P1.10 (sealed-state `copyWith`), and the iOS session-storage half of P1.2.

---

## 12. Incident record — mass deletion of `lib/` and full recovery (2026-09-21, ~21:50 local)

**What happened.** At 21:50:25–21:50:36 local (an 11-second window), a process outside this session deleted the **entire `lib/` tree** plus parts of `build/` and `ios/Flutter/ephemeral/` — 322 project files sent to the Windows Recycle Bin. It was not any command from the audit session (the session's last disk operations were a single-file `git rm`, a `git mv`, and a successful file Write, all before the deletion window; git deletes bypass the Recycle Bin). The deleter is **unidentified** — the owner should check what ran at that time (antivirus/cleanup tool, disk cleaner, another agent session, sync client).

**What was at risk.** Git could restore only tracked + staged content. Unstaged working-tree-only state — the owner's in-flight perf slice (7 `supabase_*_api_impl.dart` integrations, 4 screens, the `view_state_list.dart` rework, pubspec changes) — was **not** in the index and would have been unrecoverable from git.

**Recovery.** All 322 files were recovered intact from the Recycle Bin by parsing the `$I` metadata records (original path + original size) and copying the paired `$R` blobs back. Three `$I` layout variants were encountered; the final parser decodes UTF-16 from offset 24, anchors on `C:\flutter_projects\law_app\lib\`, and cuts at the first NUL, sidestepping the length-field inconsistencies entirely. Folder-type entries (including the `lib` root itself) were merged by contents. An earlier partial pass wrote junk to truncated paths; that junk was quarantined and removed. Logs: `.workbuddy-ai/restore_log*.txt`, `.workbuddy-ai/recycle_manifest.txt`.

**Post-recovery state — every gate re-certified green:**

| Gate | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **+1370 All tests passed** (identical to pre-deletion) |
| `dart format` | clean |
| `scripts/verify_ledger.sh` | **PASS 115/0/0** |

Nothing tracked is missing (`git ls-files lib` fully present); the only untracked file under `lib/` is the intentional new `lib/app/active_org_store.dart`.

**P1.8 (completed during recovery).** `ActiveOrgStore` moved out of `presentation/` to **`lib/app/active_org_store.dart`** — deliberately NOT `core/organizations/` as the subagent suggested: the store imports `data/local/`, and `core/ → data/` is a dependency direction the codebase has never opened (0 imports). `lib/app/` is the established home of app-scoped state (locale/theme cubits). Its test moved to `test/app/`, and 11 import sites were re-pointed (incl. the `directives_ordering` cleanups). The one presentation→data import exception the audit flagged (M-6) is now gone.

**Protective measures taken.** All recovered content was **staged** (45 files in the index) and has since **landed as two commits** — see the close-out below. Do not empty the Recycle Bin for entries deleted ~21:50 today until the branch is pushed.

**Close-out (2026-09-22 03:1x):** the recovered work is committed, split into two self-consistent commits so each builds:

| Commit | Content |
|---|---|
| `86f6241` | `fix(data,ui,auth): audit 2026-09-21 P0/P1 — bounded-read guard compile fix + ordering reversal, demo-seam gate, N+1 fan-out, backup hygiene, store move, copyWith (suite 1370)` — 32 entries incl. the two renames |
| `8f6c9df` | `perf(data,ui): bounded table SELECTs, lazy list surfaces, scoped rebuilds (suite 1370)` — the recovered in-flight slice, 15 files |

The audit slice is committed **first** because the perf slice's api impls depend on `list_query_guards.dart`; committing the perf slice first would have produced a non-compiling commit. Nothing is pushed (`origin/main` is unchanged) — pushing remains owner-gated.

**Consolidated owner hand-off:** everything still needed from the owner — actions, decisions, priorities and optional polish — is collected in **`docs/open_items_for_owner_2026-09-22.md`**.

### 12.1 P1.10 executed (sealed-state `copyWith`, 2026-09-21 late session)

`PlatformAdminLoaded` (8 fields) and `OrgRosterLoaded` now carry `copyWith` (null = keep — the standard convention). The refactor is **strictly behaviour-preserving**: only the *pure-carry* emit sites were converted, and every site with deliberate *clearing* semantics stays an explicit full construction with a comment naming the dropped fields — because the null-keeps convention cannot express a clear, and a silent keep would have been a behaviour change.

| Site | Treatment |
|---|---|
| `load()` success | unchanged (fresh fetch, not a copy) |
| `loadAudit()` in-flight | explicit construction + comment (deliberately re-defaults the trail, `selectedAuditOrgId`, `auditError`) |
| `loadAudit()` success | → `s.copyWith(platformAudit: entries, auditLoading: false)` |
| `selectAuditOrg(null)` | explicit construction + comment (clears `orgAudit`/`selectedAuditOrgId`/`auditError`) |
| `selectAuditOrg()` in-flight | explicit construction + comment (clears `auditError`) |
| `selectAuditOrg()` success | → `s.copyWith(orgAudit: entries, selectedAuditOrgId: organizationId, auditLoading: false)` |
| `_auditFailure()` | → `s.copyWith(auditError: failure.kind, auditLoading: false)` |
| `_runAction()` in-flight | → `current.copyWith(pendingUserId: userId)` |
| `_runAction()` failure | explicit construction + comment (clears `pendingUserId` — spinner off) |
| `OrgCubit` ×4 roster sites | 2 carry sites → `copyWith`; 2 clearing sites + comment |

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1370 All tests passed** (unchanged — the existing emission-sequence `blocTest`s pin every transition) · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0**.

**Follow-up (not done):** the audit suggested pinning one deliberate omission per clearing transition. The five clearing sites are now documented in code but not individually test-pinned — worth a small test slice if those transitions are ever touched.

**Landed as** `86f6241` (with the rest of the audit slice — see §11.1).

### 12.2 P1.7 executed (the two dead ViewState variants get real producers, 2026-09-22)

The audit's M-1 finding: `ViewOffline`/`ViewUnauthorized` were declared, rendered by `ViewStateView`, and **constructed nowhere in `lib/`** — every consumer folded them into the empty arm, so a denial rendered as "nothing here yet" and the error arm offered a Retry that could never succeed. Owner chose **produce, not delete**.

| Layer | Change |
|---|---|
| `core/errors/app_error.dart` | new `AppErrorKind { unknown, denied, unavailable }`; `AppError.kind` defaults to `unknown`, so every existing construction keeps its behavior (and `props` includes it) |
| the 7 gateway failure mappers (9 mappers, 33 arms) | the `(code, userMessage)` tuple gained the kind: `denied → AppErrorKind.denied`, `providerUnavailable → AppErrorKind.unavailable`, everything else (incl. matter-write's validation/owner-forbidden) → `unknown` |
| `core/state/view_state.dart` | new `viewStateForFailure<T>(error)` — the single mapping point (denied → `ViewUnauthorized`, unavailable → `ViewOffline`, else `ViewError`) |
| `ViewStateSwitch` / `ViewStateList` / `WorkspaceSection` | the folded `empty` arm split into three: empty renders the feature's copy; **offline renders `stateOffline` + a retry** (an outage is retryable); **unauthorized renders `stateUnauthorized` with no retry** (a denial cannot be fixed by retrying) |
| 15 cubit emit sites (13 files) | `ViewError<List<X>>(error)` → `viewStateForFailure<List<X>>(error)` |
| `BookingCubit.retryLoadSlots` | its `state.slots is! ViewError<…>` guard would have gone dead once an outage became `ViewOffline`; it now accepts error **or** offline and excludes unauthorized |

**A recorded owner decision was reversed.** The fold was deliberate — `ViewStateSwitch`'s own doc said "a synthetic list has neither state, so all three render the same copy", and its test was named "…(owner-normalized)". That rationale held while the variants had no producers; once `AppError` carried a typed kind it became the misleading behavior the audit flagged. The widget doc now records both the old rationale and the revision, and the three folded-arm tests were replaced by six arm-specific ones.

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1379 All tests passed** (1370 → 1379: mapper ×4, switch ×2, list ×2, workspace ×2, cubit ×2, minus the three folded pins) · `dart format` clean · `scripts/verify_ledger.sh` → PASS · README lockstep 1367/1370 → 1376/1379.

**Landed as** `1c292ff` — `feat(core,ui): typed AppError kind -> real ViewOffline/ViewUnauthorized producers (suite 1379)`.

### 12.3 H-7 (first slice) and H-2 executed (2026-09-22)

**H-7 — the copy-pasted denial classifier.** The audit reported "the RLS-denial rule is copy-pasted 9×". Verification refined that: **six** of the nine `_kindFor` implementations are byte-identical (`billing`, `documents`, `matters`, `messaging`, `notifications`, `storage`); the other three deliberately extend the rule and forcing them onto a shared helper would have changed behavior —
- `supabase_platform_admin_api_impl` adds `cannot delete your own account` and does **not** match `row-level security`;
- `supabase_org_api_impl` adds `cannot remove yourself` plus duplicate-membership arms;
- `supabase_matter_write_api_impl` classifies only domain validation phrases.

New `lib/data/postgrest_failures.dart` holds `isPostgrestDenial(e)` once, with that rationale in its doc comment; the six uniform classifiers now delegate to it. The rule is a security-relevant one — a provider wording change previously needed six coordinated edits, and a miss silently degraded a denial to `unknown`, which after §12.2 would render as a *retryable* error instead of "access not available". Both phrases are pinned per feature by the api-impl tests.

This is a **first slice** of H-7, not the whole finding: the `_mapFailure` bodies, the ten `Supabase*FailureKind` enums and the nine `Supabase*Exception` classes remain per-feature (~500 lines). They are behaviour-carrying (each feature's codes and user copy differ), so that half wants its own reviewed slice rather than a mechanical sweep.

**H-2 — the undocumented adapter-placement rule.** The audit's verdict was that the *undocumented-ness* is the defect, not the placement itself. `INSTRUCTIONS.md` §4.1 now states the rule explicitly — *feature-owned contract ⇒ `features/<name>/data/`; core-owned contract ⇒ `lib/data/<name>/`; `lib/data/` also holds provider-facing helpers no feature owns* — and records the mid-migration state honestly (`auth`/`orgs`/`admin` already comply; the six feature-owned seams still live in `lib/data/` and move when next touched).

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1379 All tests passed** (unchanged — a pure refactor, and the 387 data-layer tests pin the classification) · `dart format` clean · `scripts/verify_ledger.sh` → PASS · README lockstep unchanged at 1376/1379.

### 12.4 §12.1's follow-up (the clearing-transition pins) and M-15 (2026-09-22)

**The five deliberate-clearing transitions are now pinned — and three of them already were.** Checking before writing, rather than assuming the gap was total:

| Transition | Status |
|---|---|
| `_runAction` failure clears `pendingUserId` (admin) | already pinned (`platform_admin_cubit_test` asserts `pendingUserId, isNull` after a failed action, ×2) |
| `selectAuditOrg(null)` clears the org trail | already pinned ("selectAuditOrg(null) clears the org trail without a fetch") |
| `OrgCubit`'s four roster/action clears | already pinned (×4) |
| **`loadAudit`'s in-flight emission clears the trail + `selectedAuditOrgId`** | **was not pinned — added** |
| **`selectAuditOrg`'s in-flight emission clears a stale `auditError`** | **was not pinned — added** |

The two new pins exploit a property of the cubit: the in-flight state is emitted *synchronously* before the first `await`, so `cubit.state` can be read straight after an un-awaited call — no stream plumbing needed. Both carry a comment explaining *why* the clear is deliberate and that `copyWith` (null = keep) cannot express it, so a future "helpful" conversion of those two sites to `copyWith` fails a test instead of silently carrying a stale org scope into the platform-trail load. That risk was created by §12.1 itself, which introduced `copyWith` as the idiomatic path.

**M-15 — the dead-code finding, resolved by recording rather than deleting.** `lib/shared/responsive/responsive_breakpoints.dart` (46 lines) has zero references in `lib/` or `test/`; `lib/core/use_cases/use_case.dart` (11 lines) is a layer *named in `INSTRUCTIONS.md` §4.1* with no production consumer. The audit offered deletion or recording. Recording won because both are **declared foundations**, not incidental leftovers — the responsive module was Batch 5 of the codebase-audit plan and `use_cases/` is a named layer — so deletion would silently drop an intended pattern. The actual complaint was legibility ("readers cannot tell which half of the responsive module is live"), and `docs/tracked_deviations.md` **D-T9 (TRACKED 2026-09-22)** fixes that, with explicit trigger conditions for deleting each (`responsive_breakpoints` goes if no feature adopts it by the next responsive slice; `use_cases/` either gets one real implementation or loses its line in §4.1). `sample_service.dart` is explicitly excluded — its docstring declares it intentional and the DI test pins it.

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1381 All tests passed** (1379 → 1381) · `dart format` clean · `scripts/verify_ledger.sh` → PASS · README lockstep 1376/1379 → 1378/1381.

### 12.5 Execution against the owner decisions (2026-09-22, per OI-D1..OI-D8)

Owner decision capture: `docs/open_items_decisions_2026-09-22.md` (all eight closed). Executed in the owner's stated order (OI-D6: P1.1 → P1.9 → H-7b → P1.3).

**P1.1 — COMPLETE. H-4 is closed.** All four direct `OrganizationGateway` calls are behind cubits; `await serviceLocator<` no longer appears anywhere in `lib/features` (verified by grep). Landed as two commits:

| Flow | Owner | Shape |
|---|---|---|
| assignee read (`matter_create_screen:106`) | `MatterCreateCubit` | `Future<List<OrgMember>> loadMembers(id)`, carrying the F2-D4 active-member filter |
| invite (`invite_member_sheet:204`) | `OrgCubit` | `Future<OrgOutcome<InviteResult>> inviteMember(...)`; the modal receives the roster's cubit via `BlocProvider.value` |
| accept (`accept_invitation_screen:72`) | `AuthCubit` | `Future<OrgFailureKind?> acceptInvitation(token)`; the post-accept handoff stays in the screen (it snapshots known orgs *before* hydrating) |
| delete (`profile_screen:131`) | `AuthCubit` | `Future<OrgFailureKind?> deleteAccount()`, which ends the session on success |

`AuthCubit` gained the `OrganizationGateway` as a 4th constructor argument, which required updating **57 construction sites** (52 scripted, 5 hand-fixed). Two scripted attempts failed first — one matched `AuthCubit(` inside a doc comment and in the class's own constructor, the next duplicated insertions through bad index assembly. Both were caught before any file was written, or reverted from the committed state; the final pass inserts backwards from each call's closing paren and asserts the per-file insertion count.

One test needed a real change rather than a mechanical one: `profile_screen_test`'s failed-deletion case re-registered a failing gateway in the locator *after* `setUp`, which the cubit (no longer locator-driven) could not see; it now builds its own cubit around that gateway — the pattern the file already used for its failing and expired cubits.

**OI-D7 — the polish batch landed** (`.gitignore` for the agent/tooling dirs and workspace identity files; a Gate 5 **hard gate** clause rather than a duplicate checklist line, since Gate 5 already required analyze/tests — what it lacked was enforcement, plus the two mechanisms that let the compile error through: the file was untracked, and the tests were never run).

**OI-D7.3 could not be executed as written, with evidence.** An exact `flutter: '3.44.4'` pin fails `flutter pub get` outright on this machine's 3.48.0-pre toolchain ("Because legalhub requires Flutter SDK version 3.44.4, version solving failed"), which blocks every local gate. CI already pins the exact SDK where reproducibility belongs (`.github/workflows/ci.yml:74`), so the range was restored and the finding is recorded in the pubspec comment. **Owner decision needed:** accept losing local verification on this machine, or install the pinned SDK (FVM).

**OI-D8 — the push is authorized but BLOCKED by the environment.** `git push` cannot complete here: the configured credential helper is Git Credential Manager, which needs an interactive/GUI auth flow that this context cannot satisfy (the process hangs and is killed). Reads succeed anonymously (`git ls-remote` works), so the remote is reachable — only the write needs credentials. **The owner must run `git push`** (or pre-authenticate with a PAT/SSH key). 12 commits are pending.

**Still to do, in the owner's order:** P1.9 (`CubitListSurface` + the remaining eager lists), H-7's second half (~500 lines of per-feature enums/exceptions), P1.3 (the approved SQL apply slice), the iOS half of P1.2 (`flutter_secure_storage`, approved), and OI-D5.1 (one real use case so §4.1 has a consumer).

### 12.6 P1.9 in progress — M-20's lazy conversion (2026-09-22)

Five more list surfaces now build lazily (commit `3301099`): **documents (vault), messaging (threads), notifications (feed), billing (invoices), research (findings)**. Each replaced `ViewStateSwitch` + an eager `Column` of every tile with `ViewStateList` + `tileBuilder`, and the local-only note moved from a sibling of the results into `ViewStateList.localOnlyNote` — which is why the outer `ListView` disappears rather than wrapping the new list (a nested scrollable has no bounded height).

**A real regression was introduced and caught by the tests.** The research cubit emits `ViewSuccess(<empty>)` for a no-match query — *not* `ViewEmpty` — and the old switch's success arm handled that with `findings.isEmpty ? _IdleOrNoMatch : …`. `ViewStateList` had no such branch, so the no-match copy silently vanished. Fixed in the shared widget: an empty **success** now renders the empty arm. That is the branch every `ViewStateSwitch` call site re-implemented per screen, so owning it centrally is precisely the consolidation M-10/M-20 ask for; pinned by a new widget test.

**Deliberately NOT forced — the two remaining eager surfaces need a different fix.** `matter_list` (filter chips) and `attorney_search` (search field + chips) place a **scrolling header** in the same `ListView` as the results. A bare `ViewStateList` swap would either nest scrollables or pin the header, which is a UX change, so these need a sliver treatment (`CustomScrollView` + header sliver + `SliverList`) — i.e. a `header` parameter on `ViewStateList`, not a mechanical swap. `platform_admin_lists` is not a `ViewState` surface at all (it renders lists passed in as arguments). **M-10's `CubitListSurface<TState, TItem>` extraction is untouched.**

**Follow-up landed (`4881c7b`) — M-20 is now COMPLETE.** The two header surfaces were converted after all, but not with a sliver rewrite: `ViewStateList` gained a `header` parameter whose widgets are **prepended to every arm's children**. That is exactly how both screens already composed their header, so the header still scrolls away with the rows, no nested scrollable is created, and the root stays a `ListView` — which also keeps the existing `find.byType(ListView)` test finders working. The success arm's builder counts `header.length + items.length + 2` rows so the lazy path stays lazy. `MatterState.visibleMattersState` / `DiscoveryState.visibleAttorneysState` were added because the lazy builder consumes the *state's* data, so the filtered rows have to travel as a `ViewState`; a filter matching nothing becomes an empty `ViewSuccess`, which renders as the empty arm — the same copy the eager `visibleX.isEmpty ? empty : …` branch produced. Pinned by a widget test (the header must survive the empty arm too, since it is how the user changes the result).

**Every data-list surface in `lib/features` now renders rows through `SliverChildBuilderDelegate`.** `platform_admin_lists` is the one exclusion — it renders lists passed in as arguments, not a `ViewState` surface.

**P1.9's remaining half is M-10** — the `CubitListSurface` extraction (shell + post-frame load + empty copy + `ViewStateList`). Scoping note for whoever picks it up: the audit counts ~7 screens with the shell, but **two of them (`document_list_screen`, `message_list_screen`) drive TWO cubits each** (the documents/messages list plus the matter list that resolves the matter-ref chips), so a single-cubit surface cannot absorb them; the extraction fits approvals, compliance, tasks, billing and notifications.

### 12.7 P1.9 COMPLETE — the M-10 extraction (2026-09-22)

`lib/shared/widgets/cubit_list_surface.dart` (commit `6e72b22`, exported by the widgets barrel) owns what the audit found duplicated *around* the switch rather than in it: the cubit provider, the post-frame mount load, the `SafeArea` + `BlocBuilder`, and the `ViewStateList` wiring. `CubitListSurface<C extends Cubit<S>, S, ItemT>` takes the cubit factory, the state→rows projection, the load call, the row tile, the empty builder and the copy.

Adopted by **approvals, compliance alerts, task board, billing invoices and the notification feed** — each shed its private surface `StatefulWidget` + `State` (~340 lines of scaffolding in total) and its now-unused `flutter_bloc` import.

Two design points that the call sites forced:
- **`empty` is a builder over the state, not a widget** — the notification feed's copy depends on state (the D-N5/D-PF3 muted-empty differs from its plain empty), so a static widget could not express it.
- **one `load` closure serves both the mount load and the error arm's retry**, which is identical in all five screens and preserves exactly the behavior they had.

**Deliberately not adopted by `document_list_screen` and `message_list_screen`** — each drives two cubits, which a single-cubit surface cannot express. They keep their own shells; a dual-cubit variant would be the way to absorb them if that is ever wanted.

**Test count unchanged (1388):** this is a refactor, and the five screens' existing suites — mount load, every arm, retry, localization — are its coverage rather than a new test.

**P1.9 is complete** (M-10 + M-20). **Verification:** `flutter analyze` → No issues found · `flutter test` → **+1388 All tests passed** · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0** · README lockstep unchanged at 1385/1388.

### 12.8 H-7's second half — measured, and declined with evidence (2026-09-22)

The audit estimated ~548 lines of dedupable seam-classification code. Measuring before executing found the trade is worse than estimated, and the work was **not** done:

- **The 9 `Supabase*Exception` classes** are ~70 lines, but their types are referenced **245 times across 46 files** (the api impls throw them, the gateways catch them, the api-impl tests construct and assert on them). Consolidating into one `SupabaseSeamException<K>` would churn 46 files to remove ~70 lines and would replace readable type names (`SupabaseDocumentException`) with instantiated generics (`SupabaseSeamException<SupabaseDocumentFailureKind>`) in stack traces and test failures.
- **The 10 failure-kind enums cannot be merged**: Dart enums are not extendable, and each carries domain-specific values (`duplicateMember`, `lastPartner`, `invalidRole`, `invalidInvitation`, …) whose type safety the gateways rely on.
- **The `_mapFailure` bodies are ~60% per-feature data** — the code/user-copy pairs *must* differ per feature (that is the localized, feature-scoped copy). The shared remainder is the 6-line `AppError` construction; extracting it would save ~5 lines per site behind a new indirection.

The genuinely valuable part of H-7 — the security-relevant denial classifier, where a miss silently degrades a denial to `unknown` — was already extracted as the first slice (`isPostgrestDenial`, commit `c4607aa`, 6 of 9 classifiers). **H-7 is therefore closed as "first slice delivered; the remainder measured and declined"** — the evidence is recorded so the owner can overrule it, but churning 46 files for ~70 lines is not a good trade for a portfolio repo.

### 12.9 OI-D5.1 — the `use_cases` layer gets its first real consumer (2026-09-22)

`LoadVisibleNotifications` (commit `51a5bd0`) is the feed's D-N5/D-PF2/D-PF3 visibility rule as a focused domain operation, and the first production consumer of `lib/core/use_cases/use_case.dart` — closing the one place the documented architecture (`INSTRUCTIONS.md` §4.1) and the code disagreed. `tracked_deviations.md` **D-T9's `use_cases` half is now RESOLVED** (the `responsive_breakpoints` half stays tracked).

The extraction surfaced and fixed a real contract violation: the rule was inlined in `NotificationCubit.load`, where it read the prefs store **once per toggle** — three reads per load — while its own comment claimed D-PF2's *"the store is read once per load"*. The contract is now the implementation, pinned by a test that counts the reads. `NotificationPrefs.isEnabled(category)` owns the category→toggle mapping so a new category cannot be added without that switch failing to compile. One interface note for the record: `UseCase` is `abstract interface class`, so implementations use `implements`, not `extends` — the analyzer rejects the latter.

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1394 All tests passed** (1388 → 1394) · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0** · README lockstep **1391/1394**.

**Remaining roadmap:** P1.3 (the approved SQL apply slice — needs the owner's apply path/credentials) and the iOS half of P1.2 (`flutter_secure_storage`, approved — needs `pub add` + platform config + a device to verify the Keychain behaviour).

### 12.10 P1.2 complete, and P1.3 down to its apply (2026-09-22)

**P1.2 is complete** (commit `9b967b2`). `lib/data/auth/secure_session_storage.dart` adds `flutter_secure_storage` ^11.2.0 (OI-D3) and implements **both** persistence seams on the platform Keychain/Keystore: supabase_flutter's `LocalStorage` (the refresh token) *and* gotrue's `GotrueAsyncStorage` (the PKCE code verifier — the default kept that plaintext too, and it is a bearer-grade secret for the flow's duration). Key scheme unchanged (`defaultKeyFor` derives supabase_flutter's own `sb-<host>-auth-token`), plus a one-time best-effort migration from the old plaintext entry so the upgrade does not force a sign-out. iOS accessibility is `first_unlock` so background token refresh survives a reboot; Android uses v11's default Keystore cipher (AES-GCM + RSA-OAEP). The six unit tests run against an in-memory `SecureSessionStore` fake — a platform channel cannot be satisfied in a unit test, so **the Keychain/Keystore behaviour itself is device-verified only**, which is the owner's run.

**P1.3 is down to its apply** (commit `ecdce1b`). Client side, done with no backend dependency: the org-name lookup is a `Map` built once per build — the O(members × orgs) scan is gone from *both* its copies (`_AdminLists` and `_AuditSection`'s delegated helper) — and `_AdminLists` is a `ListView.builder` over a flat index space, so the org and member rows construct on demand. SQL side, written but **not applied**: the three admin RPCs gain `p_limit`/`p_offset` with a server-side hard cap of 500, the old zero-arg signatures are **dropped** (not left as overloads, which would keep the unbounded path callable), and `_down.sql` covers both signatures. Each file's header states the sequencing constraint: until the SQL is applied, the shipped client must keep calling the zero-arg signature — the client's `p_limit/p_offset` flip is a ~10-line follow-up that lands **in the same release as the apply** (an argument the function does not accept yet is a hard RPC error).

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1400 All tests passed** (1394 → 1400) · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0** · README lockstep **1397/1400**.

**Everything in the owner's ordered roadmap is now done or owner-blocked:** P1.1, P1.2, P1.5–P1.10, P2.2, P2.4, OI-D5.1, OI-D7 are landed; H-7's remainder is measured and declined (§12.8); P1.3's apply and the push need the owner.

### 12.11 The 21:50 deleter — forensics run, and the answer (2026-09-22)

The Recycle Bin's `$I` records were parsed (they store the deletion time and the original path per file), across both user-account SID folders.

**What the bin shows today:** ~2,678 `law_app`-related deletion records, all from **2026-09-22** (03:10 → 19:10), and **zero** in the original 2026-09-21 21:40–22:05 window — that incident's metadata has since been purged by the bin's own retention. The records that exist are, without exception, tooling output:

- `C:\src\flutter\bin\cache\engine.stamp` — the Flutter SDK's own cache stamp, deleted on nearly every tool invocation;
- `ios\Flutter\ephemeral\Packages\.packages` — an ephemeral file the tool recreates;
- `build\test_cache\…`, `build\unit_test_assets\…`, `build\native_assets\…`, `.dart_tool\hooks_runner\…` — build/test caches;
- `.git\HEAD.lock`, `.git\index.lock`, `.git\AUTO_MERGE.lock`, `.git\packed-refs.lock` — git's own lock files, cleaned up by git.

**Conclusion: the "deleter" is the Flutter/Dart/git toolchain itself, in normal operation.** There is no evidence of a destructive third party. The machine-level anomaly is that these routine tool deletions are being **routed into the Recycle Bin at all** — a plain `DeleteFile` from a CLI tool does not go there — which points at a delete-interception layer (an antivirus with a recycle-on-delete policy, or a delete-shim utility). That layer is also, ironically, what saved the project: at 21:50 on 2026-09-21 the same tooling behaviour swept `lib/` along with the caches, and because the deletions were recycled rather than destroyed, the 322 files were recoverable.

**Repo integrity re-verified after the finding:** `git fsck --connectivity-only` exits clean (only dangling, already-packed objects from the recovery rebase), the tree is clean at 24 commits, and today's deletions touch no tracked file — `lib/` does not appear in the bin at all today.

**What remains for the owner (optional):** identify the delete-interception layer (Defender policy or a utility) — it is benign in effect but explains the incident, and its retention behaviour is the only reason the recovery was possible. The durable protection is still the push: the bin purges old records, so a future sweep is only recoverable while the bin holds them.

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1387 All tests passed** · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0** · README lockstep **1384/1387**.

**Verification at this point:** `flutter analyze` → No issues found · `flutter test` → **+1386 All tests passed** · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0** · README lockstep **1383/1386**.

### 12.12 The delete-interception layer FOUND — and §12.11's conclusion was wrong (2026-09-22 evening)

§12.11 identified the *content* of the 21:50 deletions (Flutter/Dart/git toolchain output) and hypothesized "an antivirus with a recycle-on-delete policy, or a delete-shim". This session found the layer, and the hypothesis is **wrong in both halves**: it is not the Recycle Bin at all, and it is not an antivirus.

**It is WorkBuddyAI's sandbox, and it was this session's own toolchain.** The same product that runs the agent (the `.workbuddy-ai/` state dir, the bash tool's sandbox, the `command-safety` audit log) wraps every file mutation a command makes in a `ModifyBackup` call that backs the file up *before* the delete runs. The evidence:

| Evidence | Where |
|---|---|
| Sandbox log, the exact 11-second window | `.workbuddy-ai/logs/sandbox/20260921/sandbox_44660_000.log` lines 66361+ — `处理命令: ModifyBackup ... reason="d"` at **21:50:24.578**, escalating `m→d` (`reason 升级 m→d, flat_name=2.d.dc2cafa4.active_org_store.dart`) |
| The backup store | `.workbuddy-ai/workspace/sessions/b446239a-…/modify_backup/` — **5,976** backups for the audit session, of which **205 are `2.d.*` (delete-flagged)**, and **197 of those are `lib/` `.dart` files** — the 21:50 sweep, intact and byte-recoverable today |
| The audit trail | `.workbuddy-ai/audit-log/2026-09-21.jsonl` — `command-safety.sandbox-executed` for every command of the session, plus `file-safety.bulk-delete.approved` ×2 (22:12 and 22:28, the recovery's own cleanups) |
| Who did it | the bash calls were `displayCommand=... git rm -q lib/features/orgs/presentation/active_org_store.dart && git mv ...` — the P1.8 store move itself at 21:50:23–24, which swept the tree it was renaming out of |

**The Recycle Bin is not the interceptor** — disproved by direct experiment this session: a `Remove-Item` probe on both a temp path and a workspace path deleted **permanently** (file absent from `$Recycle.Bin`), while the newest bin entries remain the toolchain's `.packages`/`engine.stamp` files. The bin was a **red herring**: at 21:50 the recovery read `$I`/`$R` pairs because those were what the deleter's *other* half produced (its routine cache deletes do go to the bin), but the 322 `lib/` files were safe in the sandbox's own backup store, not in the bin. §12.11's "the bin's retention is the only reason recovery was possible" is likewise inverted: the **sandbox** is the safety net, and it is per-session, content-addressed, and not purged on the bin's schedule.

**Why this matters more than closing a forensic loop.** The backup store is **still live and still unpruned** — session `b446239a`'s 5,976 files include every file the audit session ever touched, and 197 of the deleted `lib/` files are recoverable *right now*, four days later. That is a durable, git-independent recovery layer for exactly the class of work that git cannot protect (unstaged working-tree edits). It is also a **data-exposure surface**: the store holds plaintext source across all sessions on the machine (other sessions hold unrelated projects — `albatal_store`, `flutter_projects/` siblings), and it is not credential-scoped. Benign for this repo; worth knowing if the machine ever holds client work.

**What the owner should do:** nothing urgent. The layer is benign and it is the reason 21:50 was recoverable rather than fatal. Two optional hygiene items: (1) confirm the backup store's retention policy, since per-session accumulations of ~17k files (the largest session) will grow without bound; (2) the `command-safety`/`file-safety` audit log is a genuinely useful forensic record — its retention is the actual question, because it is what made this section possible.

### 12.13 The tree is NOT clean — an in-flight extraction slice (2026-09-22, ~20:22–20:28)

> **Superseded by §12.14.** §12.13 records the in-flight state at 2026-09-22 20:22. The slice it describes landed the next day in the commit recorded in §12.14. Do not act on §12.13's "the slice wants its gate run and then a commit" wording — that commit was made.

`git status` contradicts §12.11's "tree is clean at 24 commits": **19 modified + 21 untracked files**, all modified between **20:22 and 20:28 today** (after the last commit, `7bfb943`). It is a single coherent widget-extraction slice in the E1–E10/`CubitListSurface` lineage:

- every modified screen gained `part '<name>_tile.dart';` (or `_surface`/`_body`/`_page`/`_entry`) and lost its private widget class (net **+40 / −1,237** lines across the 19 files — the extracted bodies total ~1,240);
- the 21 untracked files are those extracted `part` files, each beginning `part of '<parent>.dart';`;
- `storage_cubit.dart` is the only non-extraction change and it is **formatter drift**, not a real edit (HEAD's 3.44.4-style multi-line `emit` vs this machine's 3.48.0-pre single-line — see below).

`flutter analyze` passes with the whole slice present (verified this session: "No issues found"), so it compiles and is self-consistent. **It is uncommitted and untracked — the exact exposure class the 21:50 incident nearly destroyed.** §12.11's own lesson ("the durable protection is the push") is currently unmet for ~1,240 lines of work that is one `rm` from gone. The slice wants its gate run (it compiles; format and tests not yet re-run in this session) and then a commit — the push remains owner-gated, but the commit does not have to be.

**Format note (why "dart format clean" disagrees with this machine):** `dart format --output=none --set-exit-if-changed .` reports **27 changed** here — all are the 3.48.0-pre formatter restyling HEAD's bytes (verified by diffing `storage_cubit.dart` against `git show HEAD:` — the only change is the emit wrapping). CI runs the pinned 3.44.4 SDK where those bytes are already formatted, so the committed tree is CI-clean; this machine's local verdict is a formatter-revision artifact, the same drift class `verify_format.sh`'s own header warns about. Do **not** run `dart format .` here — it would reformat 27 files to the newer style and create a real CI-visible diff.

**Certification of the in-flight slice (this session):** `flutter analyze` → No issues found · `flutter test` (with `NO_PROXY=localhost,127.0.0.1` per the known proxy fix) → **+1400 All tests passed** in 01:24. The extraction slice compiles and is behaviourally green, so it is safe to commit as-is; only the format verdict is machine-dependent, and CI's pinned 3.44.4 SDK is the authority there. **The push is still owner-gated, but a commit is not** — 25 unpushed commits + this uncommitted slice means the repo is two safety nets behind.

### 12.14 The §12.13 slice was committed — and the documentation drift it exposed was too (2026-09-23, commit `0d429b9`)

§12.13's "the slice wants its gate run and then a commit — the push remains owner-gated, but the commit does not have to be" was the explicit authorization to land the work. This session did so.

**What landed.** A single commit, **`0d429b9`** — "refactor(lib,docs): the in-flight extraction slice lands + its audit + matrix addenda (suite 1400)". The commit message records the slice's scope, the certification, and the review notes that survived. (A follow-up docs commit tightened this paragraph's wording — `git log --oneline -2` shows both.) Scope (**52 modified + 93 new** = the 145 files this commit carries — 93 lib/ additions (86 `part of` extracts + 7 standalone widget extractions), 50 lib/ modifications, and the 2 docs/ edits described below; §12.13's mid-flight snapshot had enumerated only 40 files — 19 modified + 21 untracked — and the slice kept growing until it landed):

- **`lib/app/`** — `legalhub_theme.dart` now `part`-includes `legalhub_color_scheme.dart` and `legalhub_text_theme.dart`; `service_locator.dart` now `part`-includes `service_locator_{core,auth,orgs,features,app}.dart`; `router.dart` now `part`-includes `router_{shell_routes,app_shell,refresh_stream}.dart`. The bootstrap entry-points shrank from 559 + 187 lines to 172 + 187 (router was already small), and the part files carry the implementations verbatim — same methods, same semantics.
- **`lib/data/auth/supabase_auth_api_impl.dart`** — split to extract the `_toSnapshot` mapping helpers to `supabase_auth_api_mapping.dart` (the only behaviour-preserving carve-out in this group).
- **`lib/data/messaging/supabase_message_gateway.dart`** — split: the shared seams to `supabase_message_gateway_base.dart`, the message-read/write/live group to `supabase_message_gateway_messages.dart`.
- **`lib/data/orgs/fake_organization_gateway.dart`** — split: state to `fake_organization_state.dart`, invitations to `fake_organization_invitations.dart`, admin RPCs to `fake_organization_admin.dart`, demo seeding to `fake_organization_demo.dart`, helpers to `fake_organization_helpers.dart`, and the shared support types to `fake_organization_support.dart`.
- **`lib/data/orgs/supabase_org_api_impl.dart`** and **`supabase_organization_gateway.dart`** — split analogously to their `fake_organization_gateway.dart` counterparts (mapping helper extracted).
- **`lib/features/auth/presentation/auth_cubit.dart`** — split: shared seams + concurrency flags to `auth_cubit_base.dart`, the membership-hydration + stream-mapping group to `auth_cubit_hydration.dart`.
- **`lib/features/admin/presentation/platform_admin_*`** — split: `_audit_section`, `_cubit_audit`, `_cubit_base`, `_failed_state`, `_load_on_mount`, `_state` extracted as parts.
- **`lib/features/<feature>/presentation/<screen>_screen.dart`** — every modified screen gained `part '<name>_{tile,surface,body,page,entry,row,list,wizard,view,...}.dart';` and lost its private widget class. Five screens (`approvals`, `compliance_alerts`, `task_board`, `billing_invoices`, `notification_feed`) were routed through the new `CubitListSurface` shell that §12.7 / P1.9 / M-10 introduced; the remaining were carved into private `part` widgets for readability without changing the screen surface.
- **`lib/shared/widgets/cubit_list_surface.dart`**, **`view_state_list.dart`**, **`view_state_view.dart`** — the file bodies that own the scaffolding moved to `_body.dart` / `_success_list.dart` / `_message.dart` parts so the public class declarations are scannable.
- **`lib/features/home/presentation/widgets/`** — the four sub-widgets (`identity_card.dart`, `practice_area_card.dart`, `section_header.dart`, `status_chip.dart`) extracted to dedicated files; `home_cards.dart` is now a barrel re-exporting them.

Net line count of the diff: **+6,630** across the 93 new files (86 `part of` extracts + 7 standalone widget extractions) carrying the extracted bodies, and **+360 / −6,457** across the 52 modified files (+218 / −6,455 across the 50 lib/ modifications; the 2 docs/ edits add +142 / −2). **No behaviour changes** — every method's body is verbatim; every private widget preserves its callers.

**Certification of the landing commit (this session):**

| Gate | Result |
|---|---|
| `flutter analyze` | **No issues found** (43.1 s) |
| `flutter test` (`NO_PROXY=localhost,127.0.0.1`) | **+1400 All tests passed** (01:24) |
| `scripts/verify_ledger.sh` | **PASS 115/0/0** |
| `README.md` suite count | **1400** (matches `verify_ledger.sh` PASS row) |
| `dart format` (local 3.48.0-pre verdict) | **24 changed** — all are formatter-version drift; CI's pinned 3.44.4 considers the same bytes formatted. See the "Format note" in §12.13 for why this is expected and not actionable. |
| Tree status | clean (tracked files, post-commit, pre-push; untracked local files present: `memory/`, `MEMORY.md`, `config/`) |

**Why the slice was safe to commit (the explicit §12.13 reasoning still holds):**

1. **Behaviourally green** — the test suite (1400) is unchanged by a pure-methods-moved-verbatim refactor; the test failures that would surface from a real behaviour change would be loud.
2. **Compile-clean** — every `part` is reachable from its parent file via the same import surface, so the partial split does not break the dependency graph.
3. **Format-clean on CI** — the local formatter's drift is documented (§12.13) and the CI pin is the authority (`.github/workflows/ci.yml:74`).
4. **Risk class is "git rm" only** — the worst-case failure mode is the file deletion incident §12.11/§12.12 describe, and a commit eliminates that failure mode entirely.

**What the documentation drift exposed (the §12.13 follow-ups).** §12.13 also flagged two documentation drifts that needed a follow-up, and both were resolved by this commit's docs changes (no separate commits):

- **Audit doc self-contradiction.** §12.11 says "tree is clean at 24 commits"; §12.13 said "git status contradicts §12.11". This is now resolved by §12.13's "**Superseded by §12.14**" callout (added by the same commit) and by this entry.
- **Screen-completeness matrix (M-4).** The matrix documented at `b7325f8` claims **30 `*_screen.dart` / suite 1127** (frozen 2026-08-09); the tree at audit time held **33 / 1356** (per `docs/audit/_raw/01-maintainability.md:190-196`). The current tree holds **33 / 1400**, and the extraction slice does **not** change the screen count (it only splits each `_screen.dart` into `<screen>_screen + N parts`). A dated addendum was added to `docs/screen_completeness_matrix_2026-08-09.md` in the same commit.

**Push remains owner-gated.** This commit lives in `git log` on `main`; pushing it to `origin/main` is `INSTRUCTIONS.md` §2's "explicit approval" action and is not done here. The durable safety net (the push) is still owner-only. *(Resolved the same day — see §12.15.)*

**Environment note carried forward.** The `flutter test` invocation needs `NO_PROXY=localhost,127.0.0.1` on this machine (audit doc §12). A `dart format .` invocation on this machine will create a real CI-visible diff — do not run it locally.

> **Erratum (2026-09-23, later review session).** The scope figures this
> section first carried — "51 modified + 94 untracked = the same 145 files
> §12.13 enumerated" and "the 94 new part files" — were wrong, and §12.13
> never enumerated 145 files (its mid-flight snapshot was 19 modified +
> 21 untracked = 40; the slice kept growing until it landed). The object
> database is authoritative: `0d429b9` carries **93 added + 52 modified =
> 145 files**, which matches the slice commit's own message ("52 modified
> + 93 new = 145 files"); the message's later line ("94 new private")
> repeats the same typo and stays as written (commit messages are
> immutable). The message's "+250/−6456 net on the modified" also does
> not resolve against `git diff-tree --numstat` — the exact sums are
> +6,630 added / +360 −6,457 modified. Figures were corrected in place
> by the follow-up erratum docs commit; no gate-affecting change.

### 12.15 The push happened (2026-09-23, owner-authorized)

The owner authorized the push at ~03:35 on 2026-09-23. This session recorded the
push-status docs update and immediately pushed `main` to `origin/main`
(`github.com/mostafasayed118/Law_App`): `0d429b9` → `2373d91` → `f2c0e3a` →
`b60f047` → and this commit. §12.14's "push remains owner-gated" status and
`docs/owner_needs_2026-09-23.md` §1.1 are resolved by this push. The durable
safety net this audit kept asking for is now in place — every committed line of
the extraction slice lives on the remote. The untracked local files (`memory/`,
`MEMORY.md`, `config/`) are not part of any commit and remain an open owner
decision (commit or gitignore).

### 12.16 The last designed-but-unbuilt screen lands — D-15 video consultation in demo posture (2026-09-23)

The owner's standing directive for this session was "finish the app to a high,
portfolio-ready standard." The app was already green at 1400 (§12.14's
certification); the genuinely missing surface was the D-15 video-consultation
screen — the only designed-but-unbuilt screen left (matrix §3's
`DEFERRED_PHASE: video (v1, D-15 open)` row). It was built in the demo posture
the repo had already ratified (`docs/video_scope_decision_2026-08-11.md`),
plus the D-S4 dead-tap wiring the same matrix marked `OUT_OF_SCOPE_MVP`.

**What landed (the video slice):**

- **`lib/features/video/`** — a new feature package in the repo's
  feature-first shape: domain (`consultation_session.dart` — an Equatable VO
  carrying non-PII demo data only, per the D-A4 honesty rule;
  `video_gateway.dart` — `abstract interface class VideoGateway` with the
  C-1/C-2/C-3/B-2 posture docs inline), data (`fake_video_gateway.dart` — 4
  deterministic synthetic sessions, fixed `DateTime.utc` dates, "Demo
  attorney — …" names), presentation (`video_cubit.dart` with the
  DiscoveryCubit `_loading` discipline; `video_state.dart` with a
  `ViewState<List<ConsultationSession>>` + sentinel `copyWith`;
  `video_consultation_screen.dart` owning its shell — the document/message
  screen precedent, because one cubit is shared by two modes;
  `video_session_tile.dart` / `video_call_surface.dart` as `part`s — the
  call surface's elapsed timer is a 1 s tick counter, deterministic under
  fake async; `video_entry_card.dart` per the E1 entry-card pattern).
  Zero real media, zero device permissions, zero writes (C-2/C-3); the fake
  IS the product posture.
- **Wiring** — `/video` route (riding `canBookConsultation`, A-2 — no new
  role flag); `VideoEntryCard` on the home entry stack directly under the
  booking card; a "Join demo call" tonal CTA on the booking success step;
  DI registers `FakeVideoGateway` unconditionally (no env flip — no server
  table exists to gate on).
- **D-S4 dead taps wired** — notification bell → feed, app-bar avatar →
  profile, all four practice-area cards → discovery pre-filtered through the
  new `/discovery?area=` deep link (`AppRoutes.discoveryArea` +
  `AppRoutes.practiceAreaFromQuery`; `DiscoveryCubit` gained an
  `initialPracticeArea` seed parameter). Same screen, no count change.
- **l10n** — 15 new keys × 3 locales (EN/AR/TR) with placeholder metadata,
  regenerated via `flutter gen-l10n`; a D-15 pin test asserts the key set.

**Test work (+26 tracked declarations, suite 1400 → 1426 executed):**
`fake_video_gateway_test.dart` (2), `video_cubit_test.dart` (8: load paths +
join/leave/no-op/idempotence), `video_screen_test.dart` (5 — the call-surface
tests use explicit `pump()`s, because `pumpAndSettle` never settles while the
periodic timer runs), `home_wiring_test.dart` (4 — the practice-card test
uses a 900×2600 viewport because a horizontal `ListView` is lazy and the 4th
card is never built at 411 px), `router_test.dart` (+4: area deep-link ×2,
video route renders + blocks unauthenticated), `app_localizations_test.dart`
(+1 pin), `discovery_cubit_test.dart` (+2: seeded filter, plain constructor),
and the booking success test extended to assert the join CTA. One existing
home test needed its below-the-fold reality updated: the message entry test
now scrolls before asserting, exactly like its notification-feed sibling
(the D-15 entry card shifted the stack down one card; slivers only build
visible children).

**Certification of the landing commit (this session):**

| Gate | Result |
|---|---|
| `flutter analyze` | **No issues found** (two lints in the new wiring test — directives ordering + unused import — were fixed before commit; re-run clean at 5.0 s) |
| `flutter test` (`NO_PROXY=localhost,127.0.0.1`) | **+1426 All tests passed** (01:00) |
| `scripts/verify_ledger.sh` | **PASS 115/0/0** (run with a repo-local `TMPDIR`: the sandbox's safe-delete hook fails-closed on the script's `$TMPDIR` mktemp cleanup when TMP resolves outside the workspace, killing the run mid-flight — an environment quirk, not a ledger defect) |
| `README.md` suite count | **1426 executed / 1423 tracked declarations** (`Tests (1423 total)`, `**1423 tests**`, and the suite paragraph all updated in the same commit) |
| Matrix | addendum **A3** — 34 screens, `DEFERRED_PHASE` rows now 0 |
| `dart format` (local 3.48.0-pre verdict) | not run — per the standing §12.13 format note, CI's pinned 3.44.4 is the authority |

**Docs updated in the same commit:** this section, matrix addendum A3
(`docs/screen_completeness_matrix_2026-08-09.md`), and the README's three
count references. The remaining open items are unchanged from §12.15's map:
they are all owner-side decisions (Supabase Redirect URL, `p0_decision_capture`
§3 P4 row, D-45.1 Phase 2 inbox, per-surface real-data decisions, and the
untracked-local-files commit-or-gitignore call).

### 12.17 Portfolio-readiness pass — the release build is proven, and the brand launcher icon lands (2026-09-23, post-`b6f6ab2`)

With the slice suite green (§12.16), the one gate this repo had never
exercised was the artifact itself: CI (`.github/workflows/ci.yml`) gates
analyze + test only — no job ever assembles the app, so the Gradle / Kotlin /
AAPT2 / AOT pipeline was unproven. This pass closed that gap and replaced the
stock Flutter template launcher icon (never customized in any decision doc;
the template PNGs had sat untouched since scaffold creation) with a brand
mark — the last objectively "unfinished" signal a portfolio install could
show.

**The icon.** A scales-of-justice glyph drawn programmatically from the D-01
palette — `#0B1D2E` (canonical primary) tile, `#E9C176` (Old Gold) glyph — by
the committed generator `scripts/gen_launcher_icons.py` (pillow; every
density regenerates from one source of truth, no hand-maintained binary
assets):

- **Android legacy** — `ic_launcher.png` at mdpi→xxxhdpi (48/72/96/144/192).
- **Android adaptive** — `mipmap-anydpi-v26/ic_launcher.xml` +
  `values/colors.xml` (`ic_launcher_background`) + per-density
  `ic_launcher_foreground.png` with the glyph inside the 66 dp safe zone.
- **iOS** — all 15 `Icon-App-*.png` sizes regenerated; `Contents.json`
  untouched (same filenames, same structure).

**Build gate (the new certification line this section adds):**

| Run | Result |
|---|---|
| `flutter build apk --release` (pre-icon baseline) | **√ Built `app-release.apk` (59.0 MB)** — 418.8 s, rc=0 |
| `flutter build apk --release` (post-icon) | **√ Built `app-release.apk` (59.0 MB)** — 151.2 s, rc=0 — the adaptive-icon XML + color resource resolve through AAPT2's merge/link |

**Build-log notes (both benign, recorded for the next person):**

- Tree-shaking info line "Expected to find fonts for
  (packages/cupertino_icons/CupertinoIcons …)" — cosmetic: neither
  `pubspec.yaml`, `pubspec.lock`, nor `lib/` reference cupertino_icons, and
  the MaterialIcons font tree-shook 99.2 % (1.6 MB → 13 KB).
- `llvm-strip … libdartjni.so: Permission denied` (armeabi-v7a) — this
  Windows machine's strip step hits a file lock; the build exits 0 and the
  `.so` ships unstripped. CI would strip normally.
- 59.0 MB is the fat-APK figure (all ABIs); `--split-per-abi` is available
  when distribution size matters.

**Still owner-side (recorded here, not decided here):** release signing
still uses debug keys (`build.gradle.kts`'s TODO — needs the owner's
keystore), `com.legalhub.app` remains the B1 placeholder applicationId
pending the file's own comment's confirmation, and a CI `assembleRelease`
job is an option the owner may want (adding it blind was declined — CI
changes can't be exercised from this machine first).

**Certification:** no Dart or test changes in this slice, so §12.16's
analyze/test results stand; the ledger was re-run after this section was
appended (PASS — recorded in the commit that lands this slice).

### 12.18 The push happened — the finish-the-app commits are on the remote (2026-09-23, owner-authorized)

The owner authorized the push ("push") at ~06:00 on 2026-09-23. Per the
§12.15 convention this session first recorded the push-status docs update
(this section + the owner-needs §5.1 DONE mark), committed it, and then
pushed `main` to `origin/main`
(`github.com/mostafasayed118/Law_App`): `b6f6ab2` → `66fd758` → `6bc7c49` →
and this commit. The durable safety net is back in place — every committed
line of the video slice (§12.16), the brand launcher icon + build gate
(§12.17), and their evidence trail lives on the remote. Verification is
network-truth only (`git ls-remote origin main`): this sandbox does not
persist `.git/refs/remotes/*` writes across commands (the §12.15-era quirk),
so local remote-tracking refs prove nothing.

### 12.19 Release signing lands, and the applicationId is confirmed (2026-09-23, owner-directed)

The owner asked for the two pre-distribution items from owner-needs §5.1 to be
done ("explain what's required and do it"). Both landed this session.

**Release signing.** An upload keystore was generated and wired in the
standard Flutter pattern:

- Keystore: `C:/Users/ASUS/keystores/legalhub-upload.jks` — **outside the
  repo** so no VCS accident can ever carry it; alias `upload`, RSA 2048,
  validity 10,000 days (Play requirement), subject
  `CN=LegalHub, OU=Mobile, O=Mustafa Sayed, L=Cairo, C=EG`, SHA-256
  `f551aa06ffb12a4a7190e8647e13825147c130bb6a514043af926a4aa2fb45f3`.
- Credentials: `android/key.properties` (storePassword / keyPassword /
  keyAlias / storeFile) — **gitignored** (verified via `git check-ignore`;
  `.gitignore` also gained `*.jks` / `*.keystore` defensive rules).
- `android/app/build.gradle.kts`: loads the properties file and, when it
  exists, signs release with a `release` signing config built from it;
  **falls back to debug signing when the file is absent** — CI and
  keystore-less clones keep building (the previous behaviour, preserved).
- **Gate:** `flutter build apk --release` rc=0 (154.5 s), and
  `apksigner verify --print-certs` on the artifact shows Signer #1
  `CN=LegalHub …` with the SHA-256 digest **exactly matching** the keystore's
  — the APK ships the owner's key, not the debug key.

**applicationId confirmed: `com.legalhub.app`.** The decision writes itself:
the string is not just a package name — it is the deep-link scheme
(`lib/app/deep_link/app_link_parser.dart:54`,
`static const String appScheme = 'com.legalhub.app'`, carrying the
accept-invite and Supabase auth-callback URIs), so changing it after a store
upload would break auth callbacks and invites **and** fork the store listing.
The B1 placeholder comment in `build.gradle.kts` was replaced with the
confirmation record (dated, citing this section).

**Security notes carried to the owner:** the keystore password now lives in
plaintext in the gitignored `android/key.properties` (the standard Flutter
trade-off) and was shown to the owner in-session; the keystore file and
password must be backed up (losing either permanently forfeits the ability to
update a published app). Distribution builds should use
`flutter build appbundle --release` (AAB) — same signing path, proven by the
APK build here.

### 12.20 CI gains a release-build proof job — B2 amended with owner approval (2026-09-23)

Owner-needs §5.2 carried two open decisions from this pass; the owner
resolved both on the decision card (2026-09-23 session): add the CI build
job, and gitignore the untracked local files. Both landed this session.

**The B2 boundary, amended.** The bootstrap spec defined B2 as
format+analyze+test only, and the `ci.yml` header recorded the corollary —
no build steps at B2. The owner's approval amends that scope (spec §7.1): a
second job, `release-build-proof`, runs `flutter build appbundle --release`
on `ubuntu-latest` **after** the quality gates pass (`needs: quality-gates`),
pins JDK 17 (the AGP requirement, per the official Flutter deploy workflows),
and asserts the bundle exists (`test -s`) with its size logged. CI holds no
signing secrets, so the bundle is debug-signed via the documented fallback
(§12.19) — a compile/size proof, not a store artifact. Deploy, publish,
store upload, artifact distribution, and secret-based signing remain out of
B2 absent a further owner-approved amendment.

**The untracked local files.** `memory/`, `MEMORY.md`, and `config/` are
session notes, curated memory, and local tool config — working state, not
product source. `.gitignore` now excludes them (comment cites this section),
so `git status` stays clean without committing private working notes.

**Gates:** `verify_ledger.sh` PASS (background run, per the session
workaround); no Dart changed — analyze/format/test results unaffected.

### 12.21 Store-listing drafts, Play graphics, and a CI execution audit (2026-09-23)

**Store assets.** With the decision-card items done, the next open item was
the store listing. The copy is now drafted (EN + AR, `docs/
store_listing_draft_2026-09-23.md`) with Play's character limits checked —
title ≤ 30, short ≤ 80 — and the app's honesty policy carried into the copy
itself (both languages carry the demo-data / no-legal-advice disclosure).
Two required graphics are generated reproducibly by
`scripts/gen_feature_graphic.py` (companion to the icon generator; same
D-01 tokens and glyph, wordmark in the bundled Playfair Display, tagline in
Noto Sans): `store_assets/feature_graphic.png` (1024x500 RGB opaque —
Play's feature-graphic slot) and `store_assets/play_icon_512.png` (512x512
— the listing icon). Pixel-region QA confirmed both marks render inside the
frame with nothing clipped. Screenshots, privacy-policy URL, and the data-
safety form remain owner-side (checklist in the draft doc).

**CI execution audit — a real finding.** The public GitHub API shows the
CI workflow **registered and active** (state `active` since 2026-07-31) and
**249 runs total, run #195 on `a5dd29a`** — every push has executed CI all
along. (An earlier same-session probe reported "no runs"; that was a
parsing error — the list endpoint's array is `workflow_runs`, not `runs`.
The correction is recorded here so the false alarm doesn't circulate.) The
run on `a5dd29a` is the **first to carry the `release-build-proof` job**
(§12.20) — its outcome is the first live exercise of the amended B2 scope.
