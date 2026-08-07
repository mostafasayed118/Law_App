# LegalHub — Real-Documents (Read) Completion Verification & Evidence Record (2026-08-07)

> **Record type:** Slice T8 close-out evidence (plan
> `docs/documents_real_data_plan_2026-08-07.md`) — the **second §14
> per-feature un-deferral**, records exactly what was **verified** about the
> real documents (read) path (commits `77f14fb`..`cb682ca`, all on `main`,
> no push) and exactly what is **still pending**, with no claim beyond what
> was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-07 — slice complete, full gate green on
> `main` (analyze clean, suite 897, ledger PASS 115).** The dated close
> decision is recorded in §9 of this commit, mirroring the P0C / P3.1–P3.5 /
> matters close format.

---

## 1. What this record covers

The real documents **read** data path — from the RLS-gate design review
through the env-gated client swap — delivered as plan T1–T8:

| Stage | Artifact | Commit |
|---|---|---|
| T1 — RLS-gate design review (§8 Q1–Q6 for documents) | `docs/documents_rls_gate_review_2026-08-07.md` | `77f14fb` |
| T2 — schema artifacts (rehearsal-ready, NOT applied at commit) | `supabase/migrations/05_documents.sql` (+`05_documents.down.sql`), `supabase/policies/documents.sql` | `f8cc6c6`, `7c8ab79` (review) |
| T3 — policy battery + harness | `supabase/tests/05_document_rls.sql`, `00_fixtures.sql` document rows, `scripts/verify_policy_tests.sh` (battery list + `--apply` order + structural pins 7→8 tables / 6→7 policies) | `b5bf0b2` |
| T4 — ephemeral rehearsal (r1) | `docs/documents_rehearsal_evidence_r1_2026-08-07.md` — **PASSED** (Path A, owner's Docker host) | `a115e99`, `7f9e89a`, `b1fe823` |
| T5 — dated apply-approval → apply | `docs/documents_apply_approval_2026-08-07.md` (§6 signed) + `docs/documents_apply_execution_2026-08-07.md` — 05_documents + policy + demo seed **applied and verified** on the dev project (`eutmvevpskerzpqmwplv`), post-apply role-impersonated smoke green | `7554997`/`0e004d0` (draft), `388e31d`, `f500095`, `c1fcebd` |
| T6 — dated matrix addendum (§7 discipline) | `docs/permission_matrix.md` §4 — "View a document (metadata)" row + body-row deferral | `b9b95f9`, `4ae04d9` |
| T7 — env-gated client swap (D-DR7) | `lib/data/documents/supabase_document_api.dart` + `supabase_document_api_impl.dart` + `supabase_document_gateway.dart`, `lib/app/service_locator.dart` flip, 20 new tests, README lockstep | `9b42a84`, `cb682ca` (review) |
| T8 — lockstep + evidence + close | roadmap §14 second per-feature flip + §13 row, plan task/AC update, this record, dated close decision | this commit |

The branch was merged into `main` at `6a576bb` (conventional `--no-ff`,
11 files / 1054 insertions, zero conflicts) so T7's client swap built on
the merged base (the matters precedent).

## 2. Verified (actually run, 2026-08-07)

### 2.1 Final gate on `main` (post-`cb682ca`, the last code commit; T8 is docs-only and re-swept the ledger)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **897 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 894 in lockstep) |
| `scripts/verify_policy_tests.sh --check` (static battery) | **PASS 31/0/0** (run at T3 on the committed tree) |

### 2.2 Server-side verification (the P2/P3 discipline chain)

- **Battery `05_document_rls.sql` (11 checks) — r1 PASSED** on an ephemeral
  project built from the committed files: assigned-client (2) and
  assigned-attorney (3) positives, orphan 1, org-role-alone 0,
  **org-mismatch 0 (the D-DR2 load-bearing clause)**, cross-org 0,
  suspended 0, owner 0, anon denied, `document_type` CHECK rejects `'tax'`,
  matter-delete cascade. Structural pins: 8 tables / 8 RLS / 7 policies /
  documents SELECT grant + anon absence; 01/02/03/04 regressions
  unaffected.
- **Apply on the dev project — executed and verified under the signed §6
  approval** (`388e31d`): baseline probe → `05_documents.sql` → policy →
  demo seed (4 rows referencing the **applied** demo matter ids, org
  `ef43087b-…`, every row's `organization_id` = its matter's org) →
  mid-apply structural check (RLS true, policy present, narrow grant, **no
  body/content/size/url column** — D-V1 live) → post-apply
  role-impersonated smoke: the partner/attorney reads exactly its 3
  documents; the assigned-but-non-member demo clients read 0 — the
  **D-DR1 org-membership guard confirmed live** on the dev project.
  Rollback pairing standing by (`05_documents.down.sql` + targeted
  demo-row delete per approval §4.3); no trigger condition fired.
- **Matrix addendum (`b9b95f9`, §7 discipline)** — the "View a document
  (metadata)" row (client/attorney SHIP behind `documents_select_assigned`;
  partner/`compliance_officer` "deny unless separately assigned" stay
  ungranted; `platform_owner_admin` deny always), the six deny rows, the
  body row's §14 deferral (no body column, D-V1), and the 05.10/05.11
  traceability line — landed **before** the client surface (T7), effective
  since the apply execution.

### 2.3 Test coverage added by the client swap (+20 declarations, suite 877 → 897; README 874 → 894)

- `supabase_document_api_impl_test` (+5): columns sent to `documents`;
  denial / RLS-text / unknown PostgrestException mapping; non-Postgrest
  failure → `providerUnavailable`.
- `supabase_document_gateway_test` (+14): full row→VO mapping (all four
  `document_type` names, local-time `created_at`); matterRef resolution via
  the embedded `matters(title)` (D-DR4); raw-matter-id fallback (embed
  absent, and embed title empty); empty success; four loud provider-drift /
  malformed rows (unknown type, missing title, missing matter_id, missing
  id); denied / unavailable / unknown `AppError` mapping with empty
  redaction-safe context.
- `service_locator_test` (+1): the env-gated DI flip pin (configured →
  `SupabaseDocumentGateway`, env-less → `FakeDocumentGateway`).

## 3. Pending (honestly NOT run — do not read as verified)

- **No live configured-build read on a device/emulator.** All client
  verification is the typed/fake test suite + DI pins; a configured-build
  vault read against the dev project remains **owner-side** (needs `.env`,
  git-ignored), per the D-45.1 Phase 2 convention.
- **The demo client accounts still have no dev memberships** — they read 0
  documents by design (the live membership guard). A fuller client-side
  demo is a deliberate, separate data action (recorded in the execution
  evidence §3 note).
- **Partner/`compliance_officer` "deny unless separately assigned"
  oversight rows are not granted (D-DR5)** — the mechanism is undefined
  and stays a future slice (mirrors D-MR5).
- **Messages / storage / realtime / audit surfacing / billing / AI stay
  §14-deferred** — each is a separate per-feature un-deferral with the same
  discipline.
- **No push** — `main` is ahead of `origin`; push awaits owner approval.
- **No document write path / no body storage** — the slice is metadata-only
  read (D-V1); mutations and bodies are a separate review + addendum +
  apply.

## 4. Acceptance-criteria status (plan §8)

| Criterion | Status | Evidence |
|---|---|---|
| A document (metadata) is readable iff active member of its org **and** assigned on its matter (RLS + battery, matrix line 143/148) | **VERIFIED** | battery 05.01–05.03; r1 PASSED; live dev smoke (partner 3) |
| Org-role-alone, cross-org, unassigned, unauth, `platform_owner_admin` denied | **VERIFIED** | battery 05.04–05.09 + org-mismatch row + Q4 owner residual recorded |
| Battery green via `verify_policy_tests.sh`; rehearsal passed before any apply | **VERIFIED** | r1 PASSED (`7f9e89a`), static `--check` 31/0/0 |
| Apply only under dated approval, `_down.sql` pairing + demo-row cleanup discipline | **VERIFIED** | §6 signed (`388e31d`); execution evidence `f500095` |
| Client swap env-gated; env-less + suite unchanged; VO/presentation untouched | **VERIFIED** | DI flip pin; suite green on the fake |
| Dated matrix addendum precedes client surface; roadmap §14 second flip; README lockstep; ledger PASS | **VERIFIED** | `b9b95f9` (T6) before `9b42a84` (T7); this commit; README 894; PASS 115 |
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
# Apply (dev project, signed §6): supabase db query --linked --file supabase/migrations/05_documents.sql ; policies/documents.sql ; demo seed INSERT ... RETURNING
# Post-apply smoke: supabase db query --linked "begin; set local role authenticated; select set_config('request.jwt.claim.sub','<uid>',true); ... select count(*) from public.documents; rollback;"
```

## 6. Ledger impact

README test count **874 → 894** across the slice in lockstep with the
ledger's declaration count (suite 877 → 897 runtime). Final state
`scripts/verify_ledger.sh` **PASS 115/0/0**. The slice's SQL artifacts are
battery-covered (not ledger-covered); the docs all sweep green with the
resolved commit refs.

## 7. Review findings — resolved (not papered over)

- **T1/T2 (RLS-gate review + artifacts):** the org gate must come from the
  matter's **authoritative org**, not the document's denormalized column —
  the `m.organization_id = documents.organization_id` clause is
  load-bearing and battery-pinned by the org-mismatch deny row; the gate
  row cites the apply execution evidence `7d0fbfe`, and the migration table
  numbering was corrected (`7c8ab79`).
- **T3 (battery/harness):** the matters `--apply`-order finding was
  **pre-empted** — `05_documents.sql` gained a place in the apply list, and
  `00_fixtures.sql` was named as a touched artifact; the org-mismatch deny
  row is non-vacuous (reader is a member of the doc's org **and** assigned
  on the matter — only the clause denies).
- **T5 (apply):** the approval §2 criterion 2 pin was corrected from
  "8 tables / 7 RLS / 7 policies" to **8 / 8 / 7** (the harness pins RLS on
  all eight); the evidence §4 restates the §4.3 targeted-delete standby;
  the §3 header dated (`c1fcebd`).
- **T6 (matrix addendum):** line citations corrected to 143/148 (×2),
  "effective on apply execution" → "in effect since the apply execution",
  and the 05.10/05.11 traceability line added (`4ae04d9`).
- **T7 (client swap):** (a) the `providerUnavailable` → `document_read_unavailable`
  AppError mapping was untested (the matters gateway had the same omission)
  — now pinned; (b) the one unguarded `as` cast (`document_type`) is now
  guarded so a present-but-non-string value surfaces as the typed
  `FormatException`, never a raw `TypeError` (`cb682ca`).

## 8. Owner attention needed

- **Live smoke (optional):** a configured-build vault read as the partner
  demo account (expect exactly the 3 assigned demo documents with the
  embedded matter titles) — the last client-side check, owner-side (needs
  `.env`).
- **Demo memberships (optional):** adding memberships for the demo client
  accounts would let them read their assigned documents — a deliberate,
  separate data action outside this slice's scope.
- **Push approval:** `main` is ahead of `origin`; the slice's commits
  await your push approval.
- **Next §14 un-deferrals:** messages gets its own plan with this same
  discipline; the documents/matters **write paths** and the partner/owner
  oversight mechanism (D-DR5/D-MR5) are the flagged follow-ups.

## 9. Dated close decision

**Documents real-data read slice — CLOSED 2026-08-07.** All T1–T8 gates
met: design review passed, battery green (r1 PASSED, static `--check`
31/0/0), apply executed on the dev project under the signed dated approval
with rollback pairing, matrix addendum landed before the client surface,
env-gated client swap shipped with the full gate green (format clean ·
analyze clean · suite 897 · ledger PASS 115) and the `Document` VO /
presentation untouched. The §14 documents row flips to per-feature SHIPPED
(second un-deferral); messages/storage/realtime/audit surfacing/billing/AI
stay deferred each behind their own future per-feature un-deferral.
Nothing pushed.
