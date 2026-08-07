# LegalHub — Real-Matters (Read) Completion Verification & Evidence Record (2026-08-07)

> **Record type:** Slice T8 close-out evidence (plan
> `docs/matters_real_data_plan_2026-08-07.md`) — the first §14 per-feature
> un-deferral, records exactly what was **verified** about the real
> matters read path (commits `bf27f84`..`41577a0`, all on `main`, no push)
> and exactly what is **still pending**, with no claim beyond what was
> actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-07 — slice complete, full gate green on
> `main` (analyze clean, suite 877, ledger PASS 115).** The dated close
> decision is recorded in §9 of this commit, mirroring the P0C / P3.1–P3.5
> close format.

---

## 1. What this record covers

The real matters **read** data path — from the RLS-gate design review
through the env-gated client swap — delivered as plan T1–T8:

| Stage | Artifact | Commit |
|---|---|---|
| T1 — RLS-gate design review (§8 Q1–Q6 for matters) | `docs/matters_rls_gate_review_2026-08-07.md` | `bf27f84` |
| T2 — schema artifacts (rehearsal-ready, NOT applied at commit) | `supabase/migrations/04_matters.sql` (+`04_matters.down.sql`), `supabase/policies/matters.sql` | `6bf570d`, `c1d659f` (review) |
| T3 — policy battery + harness | `supabase/tests/04_matter_rls.sql`, `00_fixtures.sql` matters rows, `scripts/verify_policy_tests.sh` (battery list + structural pins re-scoped) | `736e433`, `a08ef99` (review) |
| T4 — ephemeral rehearsal (r1) | `docs/matters_rehearsal_evidence_r1_2026-08-07.md` — **PASSED** (Path A, owner's Docker host) | `b4afaa4`, `ea3a15d` |
| T5 — dated apply-approval → apply | `docs/matters_apply_approval_2026-08-07.md` (§6 signed) + `docs/matters_apply_execution_2026-08-07.md` — 04_matters + policy + demo seed **applied and verified** on the dev project (`eutmvevpskerzpqmwplv`), post-apply role-impersonated smoke green | `1c01870`, `0181cfa`, `7d0fbfe` |
| T6 — dated matrix addendum (§7 discipline) | `docs/permission_matrix.md` §4 matter-read grant + deny rows | `3dbf623` |
| T7 — env-gated client swap (D-MR7) | `lib/data/matters/supabase_matter_api.dart` + `supabase_matter_api_impl.dart` + `supabase_matter_gateway.dart`, `lib/app/service_locator.dart` flip, 19 new tests, README lockstep | `37cc68b`, `41577a0` (review) |
| T8 — lockstep + evidence + close | roadmap §14 per-feature flip + §13 row, plan task/AC update, this record, dated close decision | this commit |

## 2. Verified (actually run, 2026-08-07)

### 2.1 Final gate on `main` (post-`41577a0`, the last code commit; T8 is docs-only and re-swept the ledger)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **877 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 874 in lockstep) |
| `scripts/verify_policy_tests.sh --check` (static battery) | **PASS 24/0/0** (run at T3 on the committed tree) |

### 2.2 Server-side verification (the P2/P3 discipline chain)

- **Battery `04_matter_rls.sql` (10 checks) — r1 PASSED** on an ephemeral
  project built from the committed files: assigned-client (2) and
  assigned-attorney (3) positives, orphan 1, org-role-alone 0, cross-org 0,
  suspended 0, owner 0, anon denied, `practice_area` CHECK rejects `'tax'`,
  org-delete cascade. Structural pins: 7 tables / 7 RLS / 6 policies /
  matters SELECT grant + anon absence; 01/02/03 regressions unaffected.
- **Apply on the dev project — executed and verified under the signed §6
  approval** (`0181cfa`): baseline probe → `04_matters.sql` → policy →
  demo seed (4 rows, real dev `auth.users` ids) → mid-apply structural
  check (RLS true, policy present, narrow grant) → post-apply
  role-impersonated smoke: the partner/attorney reads exactly its 3 rows;
  the assigned-but-non-member demo clients read 0 — the **D-MR1
  org-membership guard confirmed live** on the dev project. Rollback
  pairing standing by (`04_matters.down.sql`); no trigger condition fired.
- **Matrix addendum (`3dbf623`, §7 discipline)** — the assigned
  client/attorney grant + five deny rows recorded, effective on apply.

### 2.3 Test coverage added by the client swap (+19 declarations, suite 857 → 877)

- `supabase_matter_api_impl_test` (+5): columns sent to `matters`; denial /
  RLS-text / unknown PostgrestException mapping; non-Postgrest failure →
  `providerUnavailable`.
- `supabase_matter_gateway_test` (+14): full row→VO mapping (all practice
  areas/statuses, local-time `created_at`); roster name resolution
  (D-MR4); once-per-org roster calls + cross-org name merge; raw-id
  fallback (id not on roster, and roster unavailable); `Unassigned`
  constant for a null attorney; empty success; three loud provider-drift
  rows; denied/unknown `AppError` mapping with empty redaction-safe
  context.
- `service_locator_test` (+1): the env-gated DI flip pin (configured →
  `SupabaseMatterGateway`, env-less → `FakeMatterGateway`).

## 3. Pending (honestly NOT run — do not read as verified)

- **No live configured-build read on a device/emulator.** All client
  verification is the typed/fake test suite + DI pins; a configured-build
  matter-list read against the dev project remains **owner-side** (needs
  `.env`, git-ignored), per the D-45.1 Phase 2 convention.
- **The demo client accounts still have no dev memberships** — they read 0
  matters by design (the live membership guard). A fuller client-side demo
  is a deliberate, separate data action (recorded in the execution
  evidence §3 note).
- **Partner/owner \"oversight\" rows are not granted (D-MR5)** — the
  mechanism is undefined and stays a future matter slice.
- **Documents / messages / storage / realtime / audit surfacing / billing
  / AI stay §14-deferred** — each is a separate per-feature un-deferral
  with the same discipline.
- **No push** — `main` is ahead of `origin`; push awaits owner approval.
- **No matter write path** — the slice is read-only; mutations are a
  separate review + addendum + apply.

## 4. Acceptance-criteria status (plan §8)

| Criterion | Status | Evidence |
|---|---|---|
| Readable iff assigned client/attorney **and** active member of the org (RLS + battery) | **VERIFIED** | battery 04.01–04.07; r1 PASSED; live dev smoke |
| Org-role-alone, cross-org, unauth, `platform_owner_admin` denied | **VERIFIED** | battery 04.05–04.09 + owner residual recorded |
| Battery green via `verify_policy_tests.sh`; rehearsal passed before apply | **VERIFIED** | r1 PASSED (`ea3a15d`), static `--check` 24/0/0 |
| Apply only under dated approval, `_down.sql` pairing + cleanup discipline | **VERIFIED** | §6 signed (`0181cfa`); execution evidence `7d0fbfe` |
| Client swap env-gated; env-less + suite unchanged; VO/presentation untouched | **VERIFIED** | DI flip pin; suite green on the fake |
| Dated matrix addendum precedes client surface; roadmap §14 flips; README lockstep; ledger PASS | **VERIFIED** | `3dbf623`; this commit; README 874; PASS 115 |
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
# Apply (dev project, signed §6): supabase db query --linked --file supabase/migrations/04_matters.sql ; policies/matters.sql ; demo seed
```

## 6. Ledger impact

README test count **854 → 874** across the slice in lockstep with the
ledger's declaration count (suite 857 → 877). Final state
`scripts/verify_ledger.sh` **PASS 115/0/0**. The slice's SQL artifacts are
battery-covered (not ledger-covered); the docs all sweep green with the
resolved commit refs.

## 7. Review findings — resolved (not papered over)

- **T2 (RLS-gate review):** (a) the owner-denial wording over-claimed
  \"deny by construction\" — corrected to the honest operational-invariant
  framing (owners never assigned) and recorded as a residual with the
  battery pin; (b) `practice_area` gained a CHECK to make the schema the
  mapping contract (`c1d659f`).
- **T3 (battery/harness):** (a) **blocking** — `--apply` never applied
  `04_matters.sql`, so a harness-built project would fail the new pins;
  the apply list was fixed; (b) the cascade test deleted org-b (vacuous —
  no matters) instead of org-a; corrected in a rolled-back txn (`a08ef99`).
- **T7 (client swap):** (a) malformed rows escaped as raw `TypeError`s —
  id/organization_id/created_at now guarded to typed `AppError`;
  (b) `providerUnavailable` had no producer — non-Postgrest failures now
  map through a defensive catch (auth-impl precedent); (c) dead test code
  (unused stub field, dead redaction-test row) removed; (d) unreachable
  `?? const` removed; (e) the multi-org roster merge test strengthened
  from a call-trace-only assertion to a positive name-merge proof
  (`41577a0`).

## 8. Owner attention needed

- **Live smoke (optional):** a configured-build matter-list read as the
  partner demo account (expect exactly the 3 assigned demo matters with
  roster-resolved attorney names) — the last client-side check, owner-side
  (needs `.env`).
- **Demo memberships (optional):** adding memberships for the demo client
  accounts would let them read their assigned matters — a deliberate,
  separate data action outside this slice's scope.
- **Push approval:** `main` is ahead of `origin`; the slice's commits
  await your push approval.
- **Next §14 un-deferrals:** documents and messages each get their own
  plan with this same discipline; the matters write path and the
  partner/owner oversight mechanism (D-MR5) are the flagged follow-ups.

## 9. Dated close decision

**Matters real-data read slice — CLOSED 2026-08-07.** All T1–T8 gates
met: design review passed, battery green (r1 PASSED, static `--check`
24/0/0), apply executed on the dev project under the signed dated
approval with rollback pairing, matrix addendum landed before the client
surface, env-gated client swap shipped with the full gate green (format
clean · analyze clean · suite 877 · ledger PASS 115) and the `Matter` VO /
presentation untouched. The §14 matters row flips to per-feature SHIPPED;
documents/messages/storage/realtime/audit/billing/AI stay deferred each
behind their own future per-feature un-deferral. Nothing pushed.
