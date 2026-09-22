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

**Verification:** `flutter analyze` → No issues found · `flutter test` → **+1387 All tests passed** · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0** · README lockstep **1384/1387**.

**Verification at this point:** `flutter analyze` → No issues found · `flutter test` → **+1386 All tests passed** · `dart format` clean · `scripts/verify_ledger.sh` → **PASS 115/0/0** · README lockstep **1383/1386**.

*Audit produced by five parallel dimension subagents with independent consolidator verification. Raw findings: `docs/audit/_raw/`.*
