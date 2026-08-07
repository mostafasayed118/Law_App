# LegalHub — Real-Messages (Read) Completion Verification & Evidence Record (2026-08-07)

> **Record type:** Slice T8 close-out evidence (plan
> `docs/messages_real_data_plan_2026-08-07.md`) — the **third §14
> per-feature un-deferral**, records exactly what was **verified** about the
> real messages (thread-metadata read) path (commits `443f42e`..`7168f38`,
> all on `main`, no push) and exactly what is **still pending**, with no
> claim beyond what was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-07 — slice complete, full gate green on
> `main` (analyze clean, suite 921 runtime / README 918 declaration, ledger
> PASS 115).** The dated close decision is recorded in §9 of this commit,
> mirroring the P0C / P3.1–P3.5 / matters / documents close format.

---

## 1. What this record covers

The real messages **read** data path (thread **metadata** only — D-MSG1) —
from the RLS-gate design review through the env-gated client swap —
delivered as plan T1–T8:

| Stage | Artifact | Commit |
|---|---|---|
| T1 — RLS-gate design review (§8 Q1–Q6 for messages) | `docs/messages_rls_gate_review_2026-08-07.md` | `443f42e` (+ nit `ab41c83`) |
| T2 — schema artifacts (rehearsal-ready, NOT applied at commit) | `supabase/migrations/06_message_threads.sql` (+`06_message_threads.down.sql`), `supabase/policies/message_threads.sql` | `5a506ca` |
| T3 — policy battery + harness | `supabase/tests/06_message_rls.sql`, `00_fixtures.sql` thread rows, `scripts/verify_policy_tests.sh` (battery list + `--apply` order + structural pins 8→9 tables / 7→8 policies + forward pin narrowed to `('messages','files')`), READMEs | `0ed14c7` (+ nits `4905697`) |
| T4 — ephemeral rehearsal (r1) | `docs/messages_rehearsal_evidence_r1_2026-08-07.md` — **PASSED** (Path A, owner's Docker host) | `a37c6dc` |
| T5 — dated apply-approval → apply | `docs/messages_apply_approval_2026-08-07.md` (§6 signed) + `docs/messages_apply_execution_2026-08-07.md` — 06_message_threads + policy + demo seed **applied and verified** on the dev project (`eutmvevpskerzpqmwplv`), post-apply role-impersonated smoke green | `5aa0231`/`8a88660` (draft + nit), `38494e3` (APPROVED), `a14650d` (execution) |
| T6 — dated matrix addendum (§7 discipline) | `docs/permission_matrix.md` §4 — "View a message thread (metadata)" row + body-row deferral | `d5ac001` |
| T7 — env-gated client swap (D-MSR7) | `lib/data/messaging/supabase_message_api.dart` + `supabase_message_api_impl.dart` + `supabase_message_gateway.dart`, `lib/app/service_locator.dart` flip, 24 new tests, README lockstep | `7168f38` |
| T8 — lockstep + evidence + close | roadmap §14 third per-feature flip + §13 row, plan task/AC update, this record, dated close decision | this commit |

The branch was merged into `main` at `9bcf4cd` (conventional `--no-ff`,
zero conflicts — docs + SQL only) so T7's client swap built on the merged
base (the matters/documents precedent).

## 2. Verified (actually run, 2026-08-07)

### 2.1 Final gate on `main` (post-`7168f38`, the last code commit; T8 is docs-only and re-swept the ledger)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **921 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 918 in lockstep) |
| `scripts/verify_policy_tests.sh --check` (static battery) | **PASS 37/0/0** (run at T3 on the committed tree) |

### 2.2 Server-side verification (the P2/P3 discipline chain)

- **Battery `06_message_rls.sql` (11 checks) — r1 PASSED** on an ephemeral
  project built from the committed files: assigned-client (2) and
  assigned-attorney (3) positives, orphan 1, org-role-alone 0,
  **org-mismatch 0 (the D-MSR2 load-bearing clause, NON-VACUOUS — 06.02
  proves an assigned reader reads org-a threads generally)**, cross-org 0,
  suspended 0, owner 0, anon denied, `message_count` CHECK rejects a
  negative count, matter-delete cascade. Structural pins: 9 tables / 9 RLS /
  8 policies / threads SELECT grant + anon absence / forward pin narrowed
  to `('messages','files')`; 01/02/03/04/05 regressions unaffected.
- **Apply on the dev project — executed and verified under the signed §6
  approval** (`38494e3`): baseline probe (threads absent, matters 4 demo
  rows, `pg_policies` 7, the four demo matter ids resolve) →
  `06_message_threads.sql` → policy → demo seed (4 rows referencing the
  **applied** demo matter ids, org `ef43087b-…`, every row's
  `organization_id` = its matter's org — D-MSR2 join probe 0 mismatches) →
  mid-apply structural check (RLS true, policy present, narrow grant,
  **no body/preview/attachment/sender column** — D-MSG1 live, `pg_policies`
  8) → post-apply role-impersonated smoke: the partner/attorney reads
  exactly its 3 threads; the assigned-but-non-member demo clients read 0 —
  the **D-MSR2 org-membership guard confirmed live** on the dev project.
  Rollback pairing standing by (`06_message_threads.down.sql` + targeted
  demo-row delete + policy git-revert per approval §4.3); no trigger
  condition fired.
- **Matrix addendum (`d5ac001`, §7 discipline)** — the "View a message
  thread (metadata)" row (client/attorney SHIP behind
  `message_threads_select_assigned`; partner/`compliance_officer` "deny
  unless separately assigned" stay ungranted; `platform_owner_admin` deny
  always), the six deny rows incl. the non-vacuous org-mismatch, the body
  row's §14 deferral (no body column, D-MSG1), and the 06.10/06.11
  traceability — landed **before** the client surface (T7), effective since
  the apply execution.

### 2.3 Test coverage added by the client swap (+24 declarations, suite 897 → 921; README 894 → 918)

- `supabase_message_api_impl_test` (+5): columns sent to `message_threads`;
  denial / RLS-text / unknown PostgrestException mapping; non-Postgrest
  failure → `providerUnavailable`.
- `supabase_message_gateway_test` (+18): full row→VO mapping (participants
  text[] → **unmodifiable** `List<String>` incl. the mutation guard, empty
  participants, local-time `last_activity_at`, `message_count`); matterRef
  resolution via the embedded `matters(title)` (D-MSR4); raw-matter-id
  fallback (embed absent, and embed title empty); empty success; seven
  loud provider-drift / malformed rows (missing title/matter_id/id,
  malformed participants, non-string participant, non-int message_count,
  unparseable date); denied / unavailable / unknown `AppError` mapping with
  empty redaction-safe context.
- `service_locator_test` (+1): the env-gated DI flip pin (configured →
  `SupabaseMessageGateway`, env-less → `FakeMessageGateway`).

## 3. Pending (honestly NOT run — do not read as verified)

- **No live configured-build read on a device/emulator.** All client
  verification is the typed/fake test suite + DI pins; a configured-build
  messaging read against the dev project remains **owner-side** (needs
  `.env`, git-ignored), per the D-45.1 Phase 2 convention.
- **The demo client accounts still have no dev memberships** — they read 0
  threads by design (the live membership guard). A fuller client-side demo
  is a deliberate, separate data action (recorded in the execution evidence
  §3 note).
- **Partner/`compliance_officer` "deny unless separately assigned"
  oversight rows are not granted (D-MSR5)** — the mechanism is undefined
  and stays a future slice (mirrors D-MR5/D-DR5).
- **Message bodies / individual message rows / storage / realtime / audit
  surfacing / billing / AI stay §14-deferred** — each is a separate
  per-feature un-deferral with the same discipline; the forward pin now
  narrows to `('messages','files')`.
- **No push** — `main` is ahead of `origin`; push awaits owner approval.
- **No message write path / no body storage** — the slice is thread-
  metadata-only read (D-MSG1); individual messages, bodies, and mutations
  are a separate review + addendum + apply.

## 4. Acceptance-criteria status (plan §8)

| Criterion | Status | Evidence |
|---|---|---|
| A message thread (metadata) is readable iff active member of its org **and** assigned on its matter (RLS + battery, matrix line 143/148) | **VERIFIED** | battery 06.01–06.03; r1 PASSED; live dev smoke (partner 3) |
| Org-role-alone, cross-org, unassigned, unauth, `platform_owner_admin` denied | **VERIFIED** | battery 06.04–06.09 + non-vacuous org-mismatch row + Q4 owner residual recorded |
| Battery green via `verify_policy_tests.sh`; rehearsal passed before any apply | **VERIFIED** | r1 PASSED (`a37c6dc`), static `--check` 37/0/0 |
| Apply only under dated approval, `_down.sql` pairing + demo-row cleanup discipline | **VERIFIED** | §6 signed (`38494e3`); execution evidence `a14650d` |
| Client swap env-gated; env-less + suite unchanged; VO/presentation untouched | **VERIFIED** | DI flip pin; suite green on the fake |
| Dated matrix addendum precedes client surface; roadmap §14 third flip; README lockstep; ledger PASS | **VERIFIED** | `d5ac001` (T6) before `7168f38` (T7); this commit; README 918; PASS 115 |
| Full gate on every client slice; nothing pushed | **VERIFIED** | §2.1; nothing pushed |

## 5. Exact commands (as run — reproducible)

```bash
cd <law_app main worktree>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash scripts/verify_ledger.sh
bash scripts/verify_policy_tests.sh --check   # static battery, no DB
# DB battery (owner-side / CI): SUPABASE_TEST_DB_URL=… scripts/verify_policy_tests.sh --apply && scripts/verify_policy_tests.sh
# Apply (dev project, signed §6): supabase db query --linked --file supabase/migrations/06_message_threads.sql ; policies/message_threads.sql ; demo seed INSERT ... RETURNING
# Post-apply smoke: supabase db query --linked "begin; set local role authenticated; select set_config('request.jwt.claim.sub','<uid>',true); ... select count(*) from public.message_threads; rollback;"
```

## 6. Ledger impact

README test count **894 → 918** across the slice in lockstep with the
ledger's declaration count (suite 897 → 921 runtime; the 3-test spread is
the `blocTest<>` expansion convention). Final state
`scripts/verify_ledger.sh` **PASS 115/0/0**. The slice's SQL artifacts are
battery-covered (not ledger-covered); the docs all sweep green with the
resolved commit refs.

## 7. Review findings — resolved (not papered over)

- **T1/T2 (RLS-gate review + artifacts):** the org gate must come from the
  matter's **authoritative org**, not the thread's denormalized column —
  the `m.organization_id = message_threads.organization_id` clause is
  load-bearing and battery-pinned by the **non-vacuous** org-mismatch deny
  row (06.02 proves an assigned reader reads org-a threads generally, so
  the 06.05 deny is the clause) — the documents T3 lesson was pre-empted
  at the review level (`ab41c83`).
- **T3 (battery/harness):** the harness header + D-P0C1(b) comments and the
  `00_fixtures.sql` reset-ordering + sanity pin sites were named in the
  task up front (the documents T3 lesson); the reviewer nits — the stale
  `scripts/README.md` battery enumeration (01/02/03 only) + the D-P0C1(b)
  "no matter/document tables" claim, and the unquoted `participants`
  array literals — were folded in (`4905697`).
- **T5 (apply):** the rollback pairing gained the policy **git-revert**
  (RLS-gate review §6 convention) so the pairing is self-contained in the
  approval record (`8a88660`); the apply itself was executed on the dev
  project under the signed approval with the baseline probe, per-step
  verification, and the post-apply membership-guard smoke recorded verbatim
  (`a14650d`).
- **T6 (matrix addendum):** placed chronologically after the documents
  addendum; the forward-pin narrowing to `('messages','files')` (dropping
  the never-built join-table names) matches the harness re-scope.
- **T7 (client swap):** the `providerUnavailable` → `message_read_unavailable`
  AppError mapping was **tested from the start** (the documents T7 finding
  pre-built), and every `as` cast is guarded so a present-but-non-string
  value surfaces as the typed `FormatException`, never a raw `TypeError`.
  The reviewer's only note — drift-test field isolation (missing-title /
  missing-matter_id rows also omit other fields) — is precedent-consistent
  with the documents test and optional; not applied.

## 8. Owner attention needed

- **Live smoke (optional):** a configured-build messaging read as the
  partner demo account (expect exactly the 3 assigned demo threads with the
  embedded matter titles + generic participants) — the last client-side
  check, owner-side (needs `.env`).
- **Demo memberships (optional):** adding memberships for the demo client
  accounts would let them read their assigned threads — a deliberate,
  separate data action outside this slice's scope.
- **Rotate the CLI access token:** the owner pasted a live Supabase access
  token into the session chat during the T5 apply; it is absent from the
  repo (verified) but should be revoked/rotated in the dashboard.
- **Push approval:** `main` is ahead of `origin`; the slice's commits
  await your push approval.
- **Next §14 un-deferrals:** storage and realtime are the natural next
  slices with this same discipline; the messages **write path / bodies /
  individual message rows** and the partner/owner oversight mechanism
  (D-MSR5/D-DR5/D-MR5) are the flagged follow-ups.

## 9. Dated close decision

**Messages real-data read slice — CLOSED 2026-08-07.** All T1–T8 gates
met: design review passed, battery green (r1 PASSED, static `--check`
37/0/0), apply executed on the dev project under the signed dated approval
with rollback pairing, matrix addendum landed before the client surface,
env-gated client swap shipped with the full gate green (format clean ·
analyze clean · suite 921 runtime / README 918 · ledger PASS 115) and the
`MessageThread` VO / presentation untouched. The §14 messages row flips to
per-feature SHIPPED (third un-deferral); message bodies / individual
messages, storage, realtime, audit surfacing, billing, and AI stay
deferred each behind their own future per-feature un-deferral. Nothing
pushed.
