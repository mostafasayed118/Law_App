# LegalHub — Realtime Completion Verification & Evidence Record (2026-08-08)

> **Record type:** Slice T8 close-out evidence (plan
> `docs/realtime_real_data_plan_2026-08-08.md`) — the **sixth §14
> per-feature un-deferral** (matters → documents → message_threads →
> storage → audit surfacing → individual messages/bodies), records exactly
> what was **verified** about the realtime read path (server commits
> `790f6e7` → `35cceb9`, client `7b8a808`, all on `main`, no push) and
> exactly what is **still pending**, with no claim beyond what was
> actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-08 — server applied + client surface complete,
> full gate green on `main` (analyze clean, suite 1014 runtime / README
> 1011 declaration, ledger PASS 115).** This slice was the first with a
> **genuinely executed rehearsal battery** (T4 — run to completion on a
> Docker-backed local stack, `== summary: 70 passed, 0 warnings, 0
> failures ==`, pins 11 tables / 11 RLS / 10 policies) and the first whose
> **apply was executed from this session** (T5 — `08_messages` +
> `policies/messages` + 10 demo message rows on the dev project, 8→9
> policies, verified per the §4 guardrails). The dated close decision is
> recorded in §9, mirroring the P0C / P3.1–P3.5 / matters / documents /
> messages / storage / audit close format.

---

## 1. What this record covers

The realtime **read** path — thread-scoped individual message rows with
bodies (`messages` table + `messages_select_assigned` RLS + the env-gated
client `fetchMessages` + the first thread-open affordance) — delivered as
plan T1–T8:

| Stage | Artifact | Commit |
|---|---|---|
| T1 — RLS-gate design review | `docs/realtime_rls_gate_review_2026-08-08.md` (Q1–Q6: thread-scoped exists gate one hop deeper, the **three-way org equality load-bearing** D-RT2, the `body` CHECK, no embed needed Q3, live delivery follow-up D-RT6) | `790f6e7` |
| T2 — schema artifacts (NOT applied) | `supabase/migrations/08_messages.sql` + `08_messages.down.sql` + `supabase/policies/messages.sql` — the **first content column** (`body` with the non-empty CHECK, the scoped D-MSG1 consummation) | `60198e2` |
| T3 — battery + harness | `supabase/tests/08_message_rls.sql` (12 checks: per-thread 2/3/1 positives, non-vacuous org-mismatch, body CHECK, cascade, 08.12 mapping-consistency) + `verify_policy_tests.sh` re-scope (pins 10→11 tables / 9→10 policies; forward pin flips to **messages-present + live-delivery-absent**); static `--check` **333/0/0** | `9f01870` |
| T4 — rehearsal r1 | **Genuinely executed** battery on a Docker-backed scratch stack (the first real execution in the slice history): 70/0/0, pins verified, **two findings fixed + committed** (`f22e672` — the storage-api `protect_objects_delete` GUC host-compat + the pre-existing 01.08 privileged-observer defect); evidence `docs/realtime_rehearsal_evidence_r1_2026-08-08.md` **PASSED** | `f22e672` + `8204245` |
| T5 — dated apply gate + execution | `docs/realtime_apply_approval_2026-08-08.md` **APPLY APPROVED 2026-08-08** (owner §6 signature) → apply executed: baseline probe → `08_messages` → `policies/messages` → **10 demo message rows** referencing the four applied demo thread ids → post-apply smoke; evidence `docs/realtime_apply_execution_2026-08-08.md` **APPLIED** | `75f1880` + `35cceb9` |
| T6 — dated matrix §4 addendum | the **"Read a document/message body" row's client/attorney cells SHIP** behind `messages_select_assigned`; D-MSG1 reversal recorded; partner/compliance stay ungranted; live delivery stays deferred (D-RT6) | `d350824` |
| T7 — env-gated client swap | `SupabaseMessageApi`/impl/gateway `fetchMessages` (`.eq('thread_id')` filter) + NEW `Message` VO + `MessageThreadDetailCubit/State/Screen` (read-only thread-detail, first thread-open affordance) + row tap + l10n ×3 + tests | `7b8a808` |
| T8 — lockstep + evidence + close | README count lockstep (1011), roadmap §14 sixth flip + §13 gate-table row, this record, dated close decision | this commit |

## 2. Verified (actually run, 2026-08-08)

### 2.1 Final gate on `main` (post-`7b8a808`, the last code commit; T8 is docs-only and re-swept the ledger)

| Check | Result |
|---|---|
| `bash scripts/verify_format.sh` (whole repo, CI-exact `dart format .`) | **PASS — 0 changed** |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **1014 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 1011 in lockstep) |
| `scripts/verify_policy_tests.sh --check` (static battery) | **PASS 333/0/0** (unchanged this slice — the 08 battery landed at T3) |
| Live battery (rehearsal, genuinely executed) | **`== summary: 70 passed, 0 warnings, 0 failures ==` / `RESULT: PASS`** (T4, evidence `8204245`) |

### 2.2 Server-side verification (applied + verified on the dev project)

- **`08_messages` applied** (`35cceb9` execution record): the D-RT3 column
  shape verified live (8 NOT NULL columns incl. `body`), RLS on,
  `messages_select_assigned` policy present, **pg_policies 8 → 9** (the
  approval record's exact prediction), `authenticated` SELECT only
  (anon denied).
- **Demo seed** (10 rows, 1/2/3/4 per thread matching each thread's
  `message_count`): org resolved per thread — **0 org mismatches** (the
  D-RT2 invariant at seed time); generic demo authors/bodies only — **0
  non-generic rows**; ids recorded from RETURNING.
- **Post-apply smoke (role-impersonated, R1 pattern):** the partner reads
  **6/10** — assigned attorney on 3 of the 4 demo matters while the
  **family matter's attorney is NULL**, so its 4 messages deny — the
  D-RT2 assignment clause firing live (honest expectation, recorded as
  designed, never as a defect); cross-org 0; stranger (no membership) 0;
  the `body` CHECK rejected an empty string live (nothing written, tally
  10).
- **Matrix addendum (`d350824`, §7 discipline)** — the "Read a
  document/message body" row's dated addendum, placed chronologically
  after the storage §4 addendum: client/attorney SHIP behind
  `messages_select_assigned`; the D-MSG1 reversal recorded (the first
  content column, read-path only); deny rows each battery-checked incl.
  the non-vacuous org-mismatch; partner/compliance stay ungranted; live
  delivery stays §14-deferred (D-RT6); "extends not replaces" per §7;
  landed **before** the client swap (T6 `d350824` < T7 `7b8a808`).

### 2.3 Test coverage added by the client surface (+28 declarations, suite 983 → 1011 declaration; 986 → 1014 runtime)

- `supabase_message_api_impl_test` (+5): `fetchMessages` column list +
  the **`.eq('thread_id')` pin**; denial / RLS-text / unknown
  PostgrestException mapping; non-Postgrest failure → `providerUnavailable`
  (the seam's `_boundTable` gains the optional filter; the existing
  threads tests updated to the new caller signature).
- `supabase_message_gateway_test` (+9): full row → `Message` VO mapping
  (id/authorDisplayName/body/sentAt local-time); empty success; missing
  id / body / author and unparseable `sent_at` → loud `FormatException` →
  `message_body_read_failed`; denied / unavailable / unknown →
  `message_body_read_denied` / `message_body_read_unavailable` /
  `message_body_read_failed` (distinct codes from the thread-list's).
- `message_gateway_test` (fake) (+3): deterministic per-thread rows
  matching each thread's `messageCount`; R1/D-RT4 non-PII bodies (demo
  framing, no `@`); unknown thread id → honest empty.
- `message_thread_detail_cubit_test` (+6): initial loading; success;
  empty → ViewEmpty; failure → ViewError; in-flight guard; retry after
  error (fetchCalls pinned per `threadId`).
- `message_thread_detail_screen_test` (+4): renders the tapped title +
  the thread's read-only rows (authors alternate, no TextField/Send);
  localized fallback title; empty state; error + retry recovers.
- `router_test` (+1): tapping a thread row navigates to
  `/messages/thread-1` and renders the detail surface (bodies visible, no
  composer).
- Stub updates (not new declarations): the 4 `MessageGateway` test stubs
  (matter-details, list-screen ×2, search) gained `fetchMessages`; the
  list-screen's AC-2 pin re-scoped to the D-RT5 posture (row InkWell +
  chip = 10; unresolved rows keep their thread-open tap; the chip stays
  gated by `canViewMatters`).

  Per-file sums: 5 + 9 + 3 (data) + 6 + 4 + 1 (presentation/router) =
  **28 declarations** — matching the ledger lockstep 983 → 1011 (suite
  986 → 1014 runtime; the 3-test spread is the `blocTest<>` expansion
  convention).

## 3. Pending (honestly NOT run — do not read as verified)

- **No live configured-build read on a device/emulator** — all client
  verification is the typed/fake test suite + DI pins (the D-45.1 Phase 2
  convention; needs `.env`, git-ignored). The real `fetchMessages` path is
  inert until a configured build exists.
- **No composer / send / reply / attachments** — the slice has no write
  grant (D-RT5); message writing is a recorded follow-up with its own
  gate.
- **Live delivery stays §14-deferred (D-RT6)** — `postgres_changes`
  push is a different authorization surface (publication membership ≠
  table SELECT RLS) and gets its own mechanism review + dated approval;
  the forward pin now pins **messages present + live delivery absent**.
- **No push** — `main` is ahead of `origin`; push awaits owner approval.

## 4. Acceptance-criteria status (plan §7/T7 done-when)

| Criterion | Status | Evidence |
|---|---|---|
| Server slice rehearsed (battery green on the committed files) + applied on the dev project with rollback pairing | **VERIFIED** | T4 genuinely executed 70/0/0 (`8204245`); T5 applied + smoke (`35cceb9`); rollback pairing standing by, not invoked |
| Dated matrix §4 addendum precedes the client surface | **VERIFIED** | `d350824` (T6) < `7b8a808` (T7) |
| Env-gated `fetchMessages` swap (fake in env-less runs + ALL tests); `Message` VO + read-only thread-detail surface; shipped thread VO/presentation otherwise untouched | **VERIFIED** | DI pins; fake determinism tests; suite green on the fake; `MessageThread` VO unchanged |
| `.eq('thread_id')` thread-scoped SELECT; guarded mapping; failure mapping incl. `providerUnavailable` from the start | **VERIFIED** | impl pin test; gateway loud-drift + failure tests |
| No composer/send/reply; live delivery absent (forward pin) | **VERIFIED** | widget assertions (no TextField/Send); harness `pg_publication_tables` = 0 pin |
| Full gate on the client slice; README lockstep; ledger PASS | **VERIFIED** | §2.1; README 1011; PASS 115 |

## 5. Exact commands (as run — reproducible)

```bash
# T4 — rehearsal (scratch Docker stack + psql shim; see the r1 record §3)
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh --apply
SUPABASE_TEST_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bash scripts/verify_policy_tests.sh          # -> 70/0/0, RESULT: PASS
# T5 — apply on the dev project (owner approved, `35cceb9`)
supabase db query --linked --file supabase/migrations/08_messages.sql
supabase db query --linked --file supabase/policies/messages.sql
# demo seed + smoke — see docs/realtime_apply_execution_2026-08-08.md §0/§3
# T7 — client gate
bash scripts/verify_format.sh                  # whole-repo, CI-exact
flutter analyze
flutter test                                   # 1014 passed
bash scripts/verify_ledger.sh                  # PASS 115
```

## 6. Ledger impact

README test count **983 → 1011** across the slice in lockstep with the
ledger's declaration count (suite 986 → 1014 runtime; the 3-test spread is
the `blocTest<>` expansion convention). Final state
`scripts/verify_ledger.sh` **PASS 115/0/0**. The docs all sweep green with
the resolved commit refs.

## 7. Review findings — resolved (not papered over)

- **T4 rehearsal (genuinely executed — the first real battery run):** two
  latent findings surfaced and were fixed + committed (`f22e672`):
  1. **Storage-api host-compat:** the stack's storage-api v1.68.1 ships a
     `protect_objects_delete` trigger blocking the fixtures' objects reset;
     the reset now sets the session GUC `storage.allow_delete_query =
     'true'` (the trigger's own escape hatch, privileged-session only).
  2. **Pre-existing battery defect 01.08:** CHECK 01.08 read `audit_events`
     under `set role authenticated`, which holds no SELECT by D-P0C4
     design — it could never pass as written; fixed with the in-file
     privileged-observer `reset role` pattern (01.13 precedent). The four
     prior r1 records never surfaced this because they were filled from
     pasted summary lines.
- **T5 apply smoke (live finding, recorded honestly):** the partner reads
  6/10, not 10 — the family matter's `assigned_attorney_id` is NULL, so
  its 4 messages deny. This is the D-RT2 assignment clause firing live
  (an org role alone never grants), recorded as designed behavior, never
  as a defect.
- **T7 client (reviewer-grade self-review):** the AC-2/D-C2 list pins were
  re-scoped to the D-RT5 posture (row InkWell + chip); the 4 `MessageGateway`
  stubs across the test tree were updated to the new seam (compile-level);
  the `.eq('thread_id')` filter is pinned at the impl; the impl caller
  typedef gained the optional `threadId` parameter with the existing
  threads tests updated in the same commit.
- **T7 ledger (count accuracy):** the first ledger sweep reported 1001
  because `git grep` skips untracked files — the two new test files were
  not yet committed. Corrected to the true tracked-tree count **1011**
  (983 + 28) in the amended T7 commit before T8.

## 8. Owner attention needed

- **Push approval:** `main` is ahead of `origin`; the slice's commits
  (`790f6e7` T1, `60198e2` T2, `9f01870` T3, `f22e672`+`8204245` T4,
  `75f1880`+`35cceb9` T5, `d350824` T6, `7b8a808` T7, this T8) await your
  push approval.
- **Live delivery (D-RT6 follow-up):** the push half of \"realtime\" —
  `postgres_changes` publication + channel authorization + client
  subscription lifecycle — is the recorded next natural slice, with its
  own mechanism review + dated approval.
- **Remaining §14 deferred paths:** billing (D-09) and AI (no scope), plus
  the recorded write-path follow-ups (send/reply). Each keeps the same
  per-feature discipline.

## 9. Dated close decision

**Realtime read slice — CLOSED 2026-08-08.** T1–T7 met their gates: the
RLS-gate design review (D-RT2 three-way org equality load-bearing) landed;
the `08_messages` artifacts + battery shipped (static `--check` 333/0/0)
and the **rehearsal battery was genuinely executed green (70/0/0)** with
two latent findings fixed; the owner's dated approval was signed and the
**apply executed on the dev project** (`08_messages` + `policies/messages`
+ 10 demo message rows, 8→9 policies, smoke verified with the family-thread
denial recorded as the clause firing live); the dated matrix §4 addendum
consummated the \"Read a document/message body\" row for client/attorney
before the client surface; and the env-gated `fetchMessages` swap + `Message`
VO + read-only thread-detail surface shipped with the full gate green on
`main` (format PASS · analyze clean · suite 1014 runtime / README 1011 ·
ledger PASS 115). The §14 realtime row flips to per-feature SHIPPED (sixth
un-deferral). **Nothing pushed**; live delivery (D-RT6), billing, and AI
stay deferred each behind their own future per-feature un-deferral.
