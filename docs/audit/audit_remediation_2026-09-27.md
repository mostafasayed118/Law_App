# Audit remediation journal — 2026-09-27

Fixes all findings from the 2026-09-21 audit (`LegalHub_AUDIT_2026-09-21.md`)
plus the 2026-09-27 sweep deltas, in five phases. Standing rules kept
throughout: gates green (`flutter analyze --no-pub`,
`dart format --output=none --set-exit-if-changed lib test`, `flutter test`),
Supabase policies versioned in git only, live dev ref
`eutmvevpskerzpqmwplv` untouched, `features/*/presentation|domain` never
imports `supabase_flutter` or `package:law_app/data`.

## Phase 1 — security (S-S1…S-S7, M-1, M-4, F-06, H-1…H-8, A-3…A-6, T-P0)

- `SupabaseEnv.ensureHttpsUrl` + wiring in `lib/main.dart` /
  `lib/app/service_locator_auth.dart`; failure closed in prod
  (`kReleaseMode` + `AppFlavor.production`).
- `kSupabaseFilterableColumns` + `requireFilterableColumn` in
  `lib/data/list_query_guards.dart`; Android verified-links comment fixed.
- Tests: `test/data/auth/supabase_env_test.dart`,
  `test/data/list_query_guards_test.dart`.

## Phase 2 — architecture (A-A1…A-A9, +1 H sweep)

- Flutter-free `HomeEntryIcon`/`HomeEntryRoute` in
  `lib/features/home/domain/home_entries.dart` (`_iconFor`/`_routeFor` in
  `home_entry_cards.dart`).
- `MatterWorkspaceCubit` + `MatterWorkspaceState` composite; four
  `matter_*_section.dart` consume it via `buildWhen`; four
  `*_section_body.dart` deleted; `MatterDetailsScreen` provides the
  workspace via `serviceLocator`. Test:
  `matter_workspace_cubit_test.dart`.

## Phase 3 — performance (search, send, mark-read, resolver, +1 M sweep)

- Search fan-out: `SupabaseSeam.boundSearchTable`
  (`lib/data/supabase_seam.dart`); `MatterSearchCaller` /
  `DocumentSearchCaller` / `MessageSearchCaller` typedefs;
  `searchMatters` / `searchDocuments` / `searchMessageThreads` on the
  Supabase APIs (+ `_boundSearch` impls, `_run` / `_runThreads` gateways)
  and on `MatterGateway` / `DocumentGateway` / `MessageGateway` (+ fakes);
  `SearchCubit` reads the bounded page and refines client-side with
  `effectiveLimit` (`searchPageSize` / `kSearchPageSize` = 30, no data-layer
  import in presentation). **Follow-up 2026-10-20:** the title-only SQL
  prefilter was removed — it silently dropped every non-title hit (status,
  practice area, document type, matter reference, participants, localized
  labels), which `SearchCubit` still matches. `_boundSearch` now reads the
  bounded cap-200 page; the client refines it. Mapping + denial tests per
  seam (`supabase_*_gateway_test.dart`, `supabase_*_api_impl_test.dart`,
  fake-gateway search tests); stubs updated in 15+ test files +
  `test/service_locator_test.dart`.
- `send_message` full-row (D-SM2): `supabase/rpc/send_message.sql` returns
  `jsonb` (`to_jsonb(messages.*)`); `SupabaseMessageApi.sendMessage`
  returns `Map<String, dynamic>`; impl + gateway map directly, no re-read,
  `_rowWithId` removed; battery `10_send_message_rls.sql` 10.01/10.02 pin
  the row fields/author echo, and 10.09 pins the empty-body CHECK. Resolves
  Q-T5 (no more id-only mocks).
- Optimistic mark-read (D-N6/D-F6): `NotificationCubit.markRead` flips
  locally via `_flipReadLocal`, no reload (`_n1Read` fixture +
  `fetchCalls == 1` pins).
- Resolver Map: `buildMatterTitleIndex` + `resolveMatterByTitleIn`
  (`matter_title_resolver.dart`); once-per-render index in
  `document_list_screen.dart` + `message_list_screen.dart`.

## Phase 4 — quality sweep (Q-Q1…Q-T5)

- Q-Q1: six (filed as five) byte-identical `_kindFor` clones →
  `postgrestKindFor` in `lib/data/postgrest_failures.dart`; the three
  extended classifiers (platform_admin, org, matter_write) keep theirs
  (behavior differs — documented).
- Q-Q2: three message-gateway failure mappers → `_messageFailureFor` in
  `supabase_message_gateway_base.dart` (codes/messages pinned by existing
  gateway tests).
- Q-Q3: roster-failure `continue` in `_displayNamesFor` now routes the
  failure kind through `AppLog.diagnostic` (first symptom of an RLS
  regression on the member seam).
- Q-C1: `docs/booking_scope_2026-08-03.md` §6 cited `(D-B1)` for "no
  consultation modes" — D-B1 covers category options; re-pointed at the
  video track (`video_scope_decision_2026-08-11.md` A-1).
- Q-C2: storage plan §7 battery bullet gains the D-BI6-style harness
  cross-reference (shared `00_fixtures.sql` matters +
  `verify_policy_tests.sh` wiring).
- Left as-is: Q-Q4 (`authorDisplayName` dead param — documented contract),
  Q-T1…Q-T4 (consider-only: no golden/coverage infra change, timing and
  console-assert tests untouched), Q-C3/C4/C5 (info-only notes).

## Phase 5 — gates + contract/docs

- `docs/permission_matrix.md` §4 addendum 2026-09-27: search fan-out
  mechanism note, D-SM2 full-row return (§8 audit unchanged), D-N6/D-F6
  optimistic flip (same RPC, same audit). No cell/policy/grant changes.
- Full gates: format CLEAN, `flutter analyze --no-pub` clean, full
  `flutter test` green (see Phase 5 gate run below).

## Blocked / owner-run

- `web/.well-known/assetlinks.json` is template-only
  (`REPLACE_WITH_RELEASE_SHA256_FINGERPRINT`); owner deploys the real
  SHA-256. Custom-scheme removal waits on deploy + verify.
- Policy batteries (`scripts/verify_policy_tests.sh`, Q-T2) run only in
  the owner's Docker scratch env — static `--check` only in this session.

## Phase 5 gate run

- `dart format --output=none --set-exit-if-changed lib test` — CLEAN.
- `flutter analyze --no-pub` — No issues found!
- `flutter test` — **1520 passed, all green.**
- Gate casualty fixed in-phase: the Phase 2 composite broke two l10n pins
  (`MatterDocumentsSection` / `MatterMessagesSection` now require a
  `MatterWorkspaceCubit` above them) — the l10n test now provides a
  service-locator-backed workspace cubit around both sections.

## Follow-up — 2026-10-20 (correctness pass on the same working tree)

The journal above describes the 2026-09-27 remediation. The working tree also
carries the separate **task-writes slice** (migration 17, policy, four RPCs,
Dart seam/cubit/UI, battery 17) that this journal does not cover. The
2026-10-20 pass closed the drift found while verifying it:

- **Task RPC contract (P0):** all four RPCs returned `uuid`/`text`/`void`,
  while `SupabaseTaskApiImpl` required a map row — every real write would
  have failed with `task_*_failed`. `create_task`, `assign_task`,
  `advance_task_status`, and `acknowledge_task` now return the persisted row
  as `jsonb` with the embedded `matters(title)` (the D-SM2 convention);
  battery 17 pins the shape. `assign_task` also clears the previous
  acknowledgement when the assignee changes (battery 17.21).
- **Task domain symmetry:** the gateway maps the server's `blocked` status
  instead of throwing on the whole board, `tasks` gained a deterministic
  `created_at DESC` ordering, and the acknowledge affordance is hidden on
  unassigned rows.
- **Search semantics:** see the Phase 3 follow-up note — the title-only
  prefilter was removed because it lost non-title matches.
- **Workspace retry:** the four per-list loaders re-enter `ViewLoading` on a
  retry (the composite had silently dropped that state).
- **Auth back stack:** sign-in's Forgot-password / Create-account links now
  `push` (they were `go`-replacing the stack, so system BACK could exit the
  app); the recovery wizard's back affordances pop when possible.
- **Gate run (working tree):** `dart format` clean, `flutter analyze
  --no-pub` clean, full `flutter test` **1567 passed**, `verify_ledger.sh`
  reconciled after the README count update.
- **Live apply (2026-10-21):** migrations 17–20 plus their policies/RPCs and
  the task assignable-members RPC were applied to `law_project`; the three
  Paymob Edge Functions were deployed. Batteries 18–21 were rehearsed on a
  fresh ephemeral stack — `--apply` 69/69 and full battery 126/126 (01–21);
  the dev project was not used because the fixtures are destructive. See
  `docs/live_apply_2026-10-21.md`.
