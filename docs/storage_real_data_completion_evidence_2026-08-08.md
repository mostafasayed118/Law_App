# LegalHub — Real-Storage (Read) Completion Verification & Evidence Record (2026-08-08)

> **Record type:** Slice T8 close-out evidence (plan
> `docs/storage_real_data_plan_2026-08-08.md`) — the **fourth §14
> per-feature un-deferral**, records exactly what was **verified** about the
> real storage (matter file metadata + byte-level read) path (server commits
> `6f52930`..`92c72e8` merged at `0b81297`, client `704f212`, all on `main`,
> no push) and exactly what is **still pending**, with no claim beyond what
> was actually run (INSTRUCTIONS.md §1.3 #5).
>
> **Status: SHIPPED 2026-08-08 — client read surface + all server
> rehearsal-ready artifacts complete, full gate green on `main` (analyze
> clean, suite 953 runtime / README 950 declaration, ledger PASS 115).** The
> server apply (T5) remains **⏳ HELD** on the r1 rehearsal evidence — the
> ephemeral battery has not been executed/recorded, so **nothing has been
> applied to the dev project**; the dated close decision is recorded in §9
> of this commit, mirroring the P0C / P3.1–P3.5 / matters / documents /
> messages close format.

---

## 1. What this record covers

The real storage **read** data path (file **metadata** via `public.files` +
**bytes** via `storage.objects` RLS on a private `matter-files` bucket —
D-STR1..D-STR4) — from the RLS-gate design review through the env-gated
client swap — delivered as plan T1–T8:

| Stage | Artifact | Commit |
|---|---|---|
| T1 — RLS-gate design review (§8 Q1–Q6 for storage) | `docs/storage_rls_gate_review_2026-08-08.md` (the plan + D-STR ratification on `main` `cc33da3`/`bad9641`) | `6f52930` (+ nits `0d7bdca`) |
| T2 — schema artifacts (rehearsal-ready, NOT applied at commit) | `supabase/migrations/07_storage.sql` (+`07_storage.down.sql`), `supabase/policies/files.sql` + `supabase/policies/storage_objects.sql` (private `matter-files` bucket + `public.files` metadata table, D-STR3) | `87b6ef5` (+ watch-item `0bc21ed`) |
| T3 — policy battery + harness | `supabase/tests/07_storage_rls.sql` (22 check blocks on **both layers**), `00_fixtures.sql` file/object rows, `scripts/verify_policy_tests.sh` (battery list + `--apply` order + structural pins 9→10 tables / 8→9 policies + 1g storage pins + forward pin narrowed to `('messages')`) | `47150be` (+ findings `83b406c`) |
| T4 — ephemeral rehearsal (r1) | `docs/storage_rehearsal_evidence_r1_2026-08-08.md` — **⏳ PENDING** (owner-side run; the failed-attempt finding recorded; the record stays uncommitted until real output lands) | — |
| T5 — dated apply-approval → apply | `docs/storage_apply_approval_2026-08-08.md` (§6 signed **APPLY APPROVED**) + `docs/storage_apply_execution_2026-08-08.md` (skeleton, uncommitted) — **execution ⏳ HELD on the r1 evidence; nothing applied** | `15bb744` (draft) + `41ce8ec` (nit) + `91c49ce` (APPROVED) |
| T6 — dated matrix addendum (§7 discipline) | `docs/permission_matrix.md` §4 — "View a matter file (metadata)" row + §6 — the two storage rows enforced (at generation + TTL, caveat recorded) | `d456f8e` (+ nits `92c72e8`) |
| T7 — env-gated client swap (D-STR7, NEW surface) | `lib/features/storage/` (VO + gateway + fake + cubit/state) + `lib/data/storage/` (seam/impl/gateway) + `lib/features/matters/presentation/matter_files_section.dart` + `RoleCapability.canViewFiles` + `service_locator` flip + l10n ×3, 32 new test declarations, README lockstep | `704f212` |
| T8 — lockstep + evidence + close | roadmap §14 fourth per-feature flip + §13 row, plan task/AC update, this record, dated close decision | this commit |

The branch was merged into `main` at `0b81297` (conventional `--no-ff`,
zero conflicts — docs + SQL only) so T7's client swap built on the merged
base (the matters/documents/messages precedent).

## 2. Verified (actually run, 2026-08-08)

### 2.1 Final gate on `main` (post-`704f212`, the last code commit; T8 is docs-only and re-swept the ledger)

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | 0 files changed (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` (full suite) | **953 passed** (exit 0) |
| `scripts/verify_ledger.sh` | **PASS — 115 passed, 0 warnings, 0 failures** (README 950 in lockstep) |
| `scripts/verify_policy_tests.sh --check` (static battery) | **PASS 331/0/0** (run at T3 on the committed tree) |

### 2.2 Server-side verification (the P2/P3 discipline chain — artifacts + probes; the live battery is T4, ⏳)

- **RLS-gate design review (T1)** — the Q1–Q6 pattern answered for storage:
  the **two-layer mechanism** (metadata table + `storage.objects` path
  policy, D-STR2), bucket/object scoping (D-STR4), the guessed-path +
  signed-URL negatives (matrix §6), rollback pairing.
- **Live read-only probes on the dev project (this session, zero change):**
  `storage.buckets` columns verified (`owner` is the deprecated form,
  superseded by `owner_id` — omitted from the migration insert), the bare
  `(id, name, public)` insert is valid (`type` is NOT NULL **with default**
  `'STANDARD'::storage.buckettype`), `storage.foldername` exists (the
  objects policy's path helper), the platform grants SELECT on
  `storage.objects` to anon + authenticated (so RLS is the real gate),
  storage policies baseline **0**, public policies **8**.
- **Battery `07_storage_rls.sql` (22 check blocks) — written, static-green,
  live run ⏳ T4:** positives on **both layers** (client-a 2 files + 2
  objects, partner-a 3/3, orphan 1/1); denies on both layers — org-role-
  alone · **non-vacuous org-mismatch** (temp org-b matter `fffc` + file
  `fffe` + path-org-mismatched object `fffd`; the assignment + membership
  arms pass so only the clause denies) · cross-org · **suspended** (the
  `is_active_member` arm on the objects layer — fixture matter 6 assigns
  `suspended-a`) · owner (Q4 residual) · anon · **guessed-path** (matrix §6
  row 1: an object under an unknown matter id denies for every role) ·
  `size_bytes` CHECK · matter-delete cascade. Structural pins: 10 tables /
  9 policies / bucket present / `files_storage_select` present / storage
  policies exactly 1 / forward pin narrowed to `('messages')`;
  01–06 regressions covered by the 331-check static sweep.
- **Matrix addendum (`d456f8e` + `92c72e8`, §7 discipline)** — the "View a
  matter file (metadata)" row (client/attorney SHIP behind
  `files_select_assigned` + `files_storage_select`; partner/
  `compliance_officer` "deny unless separately assigned" stay ungranted,
  D-STR6; `platform_owner_admin` deny always), the six deny rows on both
  layers, the `size_bytes` CHECK + cascade rows, and the §6 storage rows
  flipped to enforced (guessed-path download denied — battery-proven; stale
  signed URL — policy-at-generation + TTL, caveat recorded honestly, never
  instant revocation) — landed **before** the client surface (T6 `d456f8e`
  < T7 `704f212`), effective on the apply execution.

### 2.3 Test coverage added by the client swap (+32 declarations, suite 921 → 953 runtime; README 918 → 950)

- `supabase_storage_api_impl_test` (+5): the exact `files` columns sent
  (`id, matter_id, name, mime_type, size_bytes, storage_path,
  matters(title)`); denial / RLS-text / unknown PostgrestException mapping;
  non-Postgrest failure → `providerUnavailable`.
- `supabase_storage_gateway_test` (+14): full row→VO mapping
  (size_bytes/mime/storage_path guarded casts); matterRef resolution via
  the embedded `matters(title)` (D-STR5) + raw-matter-id fallback (embed
  absent, and embed title empty); empty success; five loud
  provider-drift / malformed rows (non-int size_bytes, missing
  name/matter_id/storage_path/id — no raw `TypeError`s across the
  boundary); denied / unavailable / unknown `AppError` mapping with empty
  redaction-safe context.
- `storage_gateway_test` (+5): fake determinism + non-PII; every file
  references a known synthetic matter title (D-STR5); D-STR4 path encoding
  (3 segments, `org-demo/matter-N/…`); no download affordance (no
  http/signed-URL shape).
- `storage_cubit_test` (+6): starts loading; load → success; empty →
  `ViewEmpty`; failure → `ViewError`; duplicate in-flight ignored; retry
  after error.
- `service_locator_test` (+2): the env-gated DI flip pins — env-less →
  `FakeStorageGateway`, configured (anon key) → `SupabaseStorageGateway`.
- `matter_details_screen_test` (extended): the Files section renders
  matter-1's file with its byte-size label (`240 KB` — the KB branch of the
  size formatter, pinned), empty-subset copy with an `_EmptyStorageGateway`,
  and the capability gate hides the section when `canViewFiles` is false.

## 3. Pending (honestly NOT run — do not read as verified)

- **The r1 ephemeral rehearsal (T4) is ⏳ PENDING.** The static `--check`
  (331/0/0) is verified; the live battery against a Postgres-with-storage
  host has **not been executed or recorded** — the failed-attempt finding
  (no Docker/psql on this machine; the PowerShell env-var syntax error) is
  documented in `docs/storage_rehearsal_evidence_r1_2026-08-08.md`, which
  stays ⏳ PENDING and uncommitted until real output lands (owner's Docker
  `supabase start` host — the matters/documents/messages r1 Path A
  precedent).
- **The server apply (T5) is ⏳ HELD on the r1 evidence.** The approval is
  APPLY APPROVED (`91c49ce`, §6 dated sign-off) and the read-only baseline
  probes are verified (files 0, bucket 0, public policies 8→9, storage
  policies 0→1, the four demo matter ids resolve under org
  `ef43087b-…`); per the approval's §6 validity clause and
  `rollback_plan.md` §2, **nothing touches the dev project until the r1
  PASS evidence lands**. The execution record is drafted, uncommitted.
- **No live configured-build read on a device/emulator** — all client
  verification is the typed/fake test suite + DI pins (the D-45.1 Phase 2
  convention; needs `.env`, git-ignored).
- **Byte download affordance + signed-URL UX + upload/write path are NOT
  built (D-STR9)** — the storage.objects gate is proven by the battery
  server-side; the client interaction is a flagged follow-up slice.
- **Partner/`compliance_officer` "deny unless separately assigned"
  oversight rows are not granted (D-STR6)** — the mechanism is undefined
  and stays a future slice (mirrors D-MR5/D-DR5/D-MSR5).
- **Realtime / audit surfacing / billing / AI stay §14-deferred** — the
  forward pin now narrows to `('messages')` (individual message
  rows/bodies).
- **No push** — `main` is ahead of `origin`; push awaits owner approval.

## 4. Acceptance-criteria status (plan §8)

| Criterion | Status | Evidence |
|---|---|---|
| A file's **metadata** readable iff active member of its org **and** assigned on its matter (RLS + battery, matrix line 143/148) | **PARTIAL** — battery written + static green; live r1 run + apply pending | battery 07.01–07.04; static 331/0/0 |
| A file's **bytes** readable iff the same gate holds, path-scoped — **guessed path denied** for every role (matrix §6 row 1) | **PARTIAL** — battery row written + static green; live r1 run + apply pending | battery 07.12 (non-vacuous) |
| Org-role-alone, cross-org, unassigned, org-mismatch, unauth, `platform_owner_admin` denied on **both layers** | **PARTIAL** — battery rows written + static green; live r1 run + apply pending | battery 07.04–07.09, 07.05 non-vacuous |
| Battery green via `verify_policy_tests.sh`; rehearsal passed with evidence before any apply | **PARTIAL** — static `--check` **331/0/0** verified; **live r1 ⏳ PENDING** | T3 committed; rehearsal record ⏳ |
| Apply executed only under the dated apply-approval with `_down.sql` + git-revert pairing + cleanup discipline | **HELD** — approval APPLY APPROVED (`91c49ce`); execution gated on the r1 evidence; nothing applied | §6 signed; baseline probes |
| Client surface new but consumer-attached (D-STR7): env-gated; env-less + suite unchanged (fake); metadata-only, no download | **VERIFIED** | DI flip pins; suite green on the fake; `matter_files_section` (D-STR9) |
| Dated matrix §4 + §6 addendum precedes the client surface; roadmap §14 fourth flip; README lockstep; ledger PASS | **VERIFIED** | `d456f8e` (T6) before `704f212` (T7); this commit; README 950; PASS 115 |
| Full gate on every client slice; nothing pushed | **VERIFIED** | §2.1; nothing pushed |

## 5. Exact commands (as run — reproducible)

```bash
cd <law_app main worktree>
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bash scripts/verify_ledger.sh
bash scripts/verify_policy_tests.sh --check   # static battery, no DB
# DB battery (owner-side / CI — the T4 gate): SUPABASE_TEST_DB_URL=… scripts/verify_policy_tests.sh --apply && scripts/verify_policy_tests.sh
# Apply (dev project, signed §6 — only after r1 PASS evidence): supabase db query --linked --file supabase/migrations/07_storage.sql ; policies/files.sql ; policies/storage_objects.sql ; demo seed (4 file rows + 4 objects, applied demo matter ids)
```

## 6. Ledger impact

README test count **918 → 950** across the slice in lockstep with the
ledger's declaration count (suite 921 → 953 runtime; the 3-test spread is
the `blocTest<>` expansion convention). Final state
`scripts/verify_ledger.sh` **PASS 115/0/0**. The slice's SQL artifacts are
battery-covered (not ledger-covered); the docs all sweep green with the
resolved commit refs.

## 7. Review findings — resolved (not papered over)

- **T1/T2 (review + artifacts):** the bucket column list was **verified
  live** via a read-only `information_schema` probe instead of guessed —
  `owner` is the deprecated form (superseded by `owner_id`) and omitted;
  the reviewer's watch-item (`storage.buckets.type` nullability) was folded
  into the migration comment (`0bc21ed`) and later **settled definitively**
  by the T5 baseline probe: NOT NULL **with default** `'STANDARD'`, so the
  bare `(id, name, public)` insert is valid.
- **T3 (battery/harness):** the anon-posture probe showed the *hosted*
  platform grants SELECT on `storage.objects` to anon + authenticated — the
  anon row asserts `insufficient_privilege` on files and RLS-0-rows on
  objects; the reviewer's catch (a local `supabase start` schema may revoke
  anon entirely) was folded in (`83b406c`): the objects arm accepts **either**
  deny outcome, T4-verified not assumed. Static `--check` 331/0/0.
- **T5 (approval):** the rollback pairing is **self-contained** (the
  messages T5 reviewer lesson pre-folded — `07_storage.down.sql` +
  demo-row/object delete + policy git-revert); the §7 branch-pointer nit
  folded (`41ce8ec`); the approval was flipped APPLY APPROVED (`91c49ce`)
  with the execution honestly **held** on the missing r1 evidence.
- **T6 (matrix addendum):** placed chronologically after the messages
  addendum; the reviewer's wording nits — the §6 lead-in must not read
  present-tense while nothing is applied, and the signed-URL caveat belongs
  in the review citation — were folded (`92c72e8`): the addendum cites the
  actual slice state (r1 ⏳, apply ⏳ HELD) with the "takes effect on the
  apply execution" framing.
- **T7 (client swap):** every `as` cast is guarded (typed `FormatException`
  → `AppError`, never a raw `TypeError`); the `providerUnavailable` →
  `file_read_unavailable` mapping is tested from the start (the documents T7
  lesson pre-built); the reviewer's size-label note was folded — the
  formatter trims the trailing `.0` (`240 KB`, not `240.0 KB`) and the KB
  branch is pinned through the widget test.

## 8. Owner attention needed

- **The one-paste unblock (T4 + the apply):** run the storage rehearsal on
  your Docker host —
  `supabase start` → `export SUPABASE_TEST_DB_URL=<url from supabase status>`
  → `bash scripts/verify_policy_tests.sh --apply` →
  `bash scripts/verify_policy_tests.sh` — and paste the tail (the
  `== summary:` / `RESULT:` line, the 1a/1e/1g pins, the 07 battery result).
  I fill + flip the rehearsal record to PASSED, then execute the apply under
  the §4 guardrails with each step recorded verbatim (the CLI link + owning
  account are active).
- **Push approval:** `main` is ahead of `origin`; the slice's commits await
  your push approval.
- **Next slices:** realtime (the fifth deferred path) and the D-STR9
  download/upload UX + the partner/owner oversight row (D-STR6) are the
  flagged follow-ups with the same per-feature discipline.

## 9. Dated close decision

**Storage real-data read slice — CLOSED 2026-08-08 for the client read
surface + all server rehearsal-ready artifacts.** T1–T3, T6, T7 met their
gates: design review passed, artifacts + battery + harness committed
(static `--check` 331/0/0), dated matrix §4 + §6 addenda landed before the
client surface, and the env-gated client swap (D-STR7 NEW surface, incl.
`RoleCapability.canViewFiles`) shipped with the full gate green on `main`
(format clean · analyze clean · suite 953 runtime / README 950 · ledger
PASS 115) and no shipped VO/presentation changed. The §14 storage row
flips to per-feature SHIPPED (fourth un-deferral). **The server apply (T5)
remains ⏳ HELD** on the r1 rehearsal evidence — nothing has been applied
to the dev project — and will execute under the §4 guardrails once the
ephemeral battery passes and is recorded (the approval is already APPLY
APPROVED). Realtime, audit surfacing, billing, AI, and the file write path
stay deferred each behind their own future per-feature un-deferral.
Nothing pushed.
