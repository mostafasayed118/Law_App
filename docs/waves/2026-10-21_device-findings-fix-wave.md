# Fix wave — device findings 2026-10-21 (`c835ced`)

> PM plan. Source of truth: `docs/device_e2e_2026-10-21_c835ced.md` (device evidence,
> Infinix X6882, real `law_project` backend). Nothing here is implemented yet.
> Every brief is **assess-first**: the executor must prove the root cause at source
> before changing code, and a probe-proven STOP is a success.
>
> **Owner rulings (2026-10-21), recorded before dispatch:**
> - **D1** — F4 is fixed with a **policy carve-out for the creator** (the audit's
>   "no carve-out (Q4)" rule is explicitly relaxed by the owner). The matters table
>   has **no `created_by` column**, so the carve-out needs a schema addition + the
>   `create_matter` RPC writing it + the read policy. Client-side copy/refresh
>   fixes ride along.
> - **D2** — F5 (thread creation) is **in this campaign** as its own wave (W5):
>   a server-side write path (`create_thread` RPC + grant) plus a client surface.
> - **D3** — the PM dispatches one executor agent per wave, **sequentially** (one
>   Flutter gate at a time — the Flutter startup lock), and re-verifies every report
>   at source before landing anything.
> - **D4** — the evidence doc is committed (docs-only) so the wave start gate has a
>   clean tree.

## Start state (verified fresh, 2026-10-21)

| Item | Value |
|---|---|
| HEAD | `c835ceddda58427adedc8377344b52bb819eeebb` |
| origin/main (`ls-remote`) | `c835ceddda58427adedc8377344b52bb819eeebb` |
| unpushed | 0 |
| working tree | clean after the docs commit (this file + the evidence doc) |
| CI | run `39569576730` on `c835ced` — success (quality + release AAB + debug APK) |
| gates (local, verified this session) | `flutter analyze` clean · `flutter test` 1750/1750 (after W2) · `dart format --output=none --set-exit-if-changed .` 0 changed (the CI command) · `scripts/verify_ledger.sh` PASS (115/0) · `scripts/verify_arb_parity.sh` PASS (511/511/511 — W2 added one l10n key) |

**Campaign state (updated by the PM after each wave):**

| Wave | Status | Commit | Baseline for the next wave |
|---|---|---|---|
| W1 | **landed + PM-verified** | `8b5b08b` (root cause: candidate B — the seed guard in `active_org_store.dart` skipped a same-user re-auth; `OrganizationMembership` is an Equatable, so the membership-set comparison is by value) | — |
| W2 | **landed + PM-verified** | `094246e` (root cause: go_router prefers `platformDispatcher.defaultRouteName` over `initialLocation`, so the platform hands the foreign URI to the router as the initial location; `findMatch` throws and the app had no `errorBuilder` → go_router's raw error page. Fix: one `errorBuilder` + a calm localized surface; the accept-invite path is untouched and still green) | `flutter test` = **1750**, tracked declarations **1744**, ARB parity **511/511/511**, ledger 115/0, repo-wide `dart format` = 0 changed |
| W3 | next | — | — |
| W4 | queued (owner ruling D1) | — | — |
| W5 | queued (owner ruling D2) | — | — |

> **README note for the executors:** the repo's ledger gate compares the README's
> test-count lines with the tracked declaration count. Whenever a wave adds tracked
> test declarations, the README's two count lines **must** be bumped in the same
> commit or `scripts/verify_ledger.sh` goes red. `README.md` (those two lines only)
> is therefore in scope for any wave that adds tests.
>
> **Known doc nit (campaign close-out, not a wave):** `README.md:31` still reads
> "**Quality gates** — 1741 tests"; the ledger only checks the two count lines, so
> that third reference drifts with every wave. Fix it once, at the end, against the
> final count.

**Flutter startup lock:** only one Flutter gate process at a time — waves run
**sequentially**, never in parallel.

**Live-apply access:** the PAT in the environment has no `database_read/write`, the
Supabase MCP is bound to another project, and the CLI reports `database_write`
missing — so **the PM applies the W4/W5 backend SQL to `law_project` through the
Supabase dashboard SQL Editor** (the project is `law_project` / `eutmvevpskerzpqmwplv`,
eu-west-2), records a dated apply record, and never runs `supabase db push` (the
project has no `supabase_migrations.schema_migrations` history). The **policy
batteries are destructive and run only on an ephemeral local stack**, never on the
dev project.

## Findings → disposition

| # | Finding | Evidence | Disposition |
|---|---|---|---|
| **F1** | Honest-copy gap: 7 home entry subtitles + the Settings role card + the sign-out label still say "development demo" / "End demo session" in a **configured, real-backend** build | device: configured build home + Settings | **W3** |
| **F2** | A deep link that does not match a route renders a raw `Page Not Found` + `GoException: no routes for location: com.legalhub.app.dev:///tasks` | device: `am start VIEW` intent | **W2** |
| **F3** | A membership created in the same session never becomes the active org: the org hub keeps rendering the "Create Organization" form and "Create matter" says "No active organization is selected" | device: sign in → create org → sign out → sign in (broken) vs. force-stop + relaunch (works) | **W1** |
| **F4** | A matter created with the default (no) assignee is invisible to its creator — `policies/matters.sql` reads `is_active_member(org) AND (assigned_client_id = auth.uid() OR assigned_attorney_id = auth.uid())` and the table has no `created_by` | device: matter `a457cf53…` invisible; matter `63982ae0…` (client assigned) visible | **W4** (D1: creator carve-out) |
| **F5** | No client path can create a message thread: `message_threads` has no INSERT grant for `authenticated` and no create-thread RPC; the app only reads threads and calls `send_message(p_thread_id, p_body)` on an existing one | device: `42501 permission denied for table message_threads` | **W5** (D2) |
| **F1-correction** | The five surfaces whose note is *not* posture-gated — discovery (`attorney_search_surface.dart:83`), approvals (`approvals_screen.dart:50`), compliance (`compliance_alerts_screen.dart:56`), research (`ai_research_surface.dart:89`), video (`video_consultation_screen.dart:126`) — are **fake-only in every build** (no `supabase_*` impl; `VideoGateway` is registered as `FakeVideoGateway.new` at `service_locator_features.dart:45`). Their "Demo mode" note is therefore **truthful** and must NOT be gated — gating them would hide the truth that the data is synthetic. | code | **closed, no change** |

## Wave plan (sequential, disjoint ownership)

| Wave | Finding | Kind | Owned paths |
|---|---|---|---|
| **W1** | F3 — active-org seeding after a same-user re-auth | client | `lib/app/active_org_store.dart` + its test |
| **W2** | F2 — unmatched deep link must not render a raw GoException | client | `lib/app/router.dart` (+ a router/deep-link test) |
| **W3** | F1 — posture-honest home subtitles + Settings copy | client + l10n | `lib/features/home/**`, `lib/features/home/presentation/settings_screen.dart`, `lib/l10n/**` |
| **W4** | F4 — the creator can read the matter they created | **backend + client** | `supabase/**` (new migration + `rpc/create_matter.sql` + `policies/matters.sql`), `lib/features/matters/**` |
| **W5** | F5 — a client path to create a message thread | **backend + client** | `supabase/rpc/create_thread.sql` (+ grant/policy), `lib/features/messaging/**`, `lib/features/matters/**` (the "new thread" affordance) |

**Sequencing:** W1 → W2 → W3 → W4 → W5. W4 and W5 are backend-first (the PM applies
the SQL live after the executor's SQL + tests land); the client half of each follows
its own SQL.

---

# PROMPT 1 — W1: the active organization must survive a same-user re-auth

**Context.** Device finding F3 (evidence doc §"Root cause refined"). Sequence
reproduced on a real device against the live backend:

1. sign in → **Create Organization** → org `QA Device Firm` created, membership row
   `role=partner, status=active` (PostgREST-verified);
2. sign out → sign in as the same user → org hub **still renders the
   "Create Organization" form**; "Create matter" says *"No active organization is
   selected. Choose an organization from the org hub, then return here to create a
   matter."*;
3. force-stop + relaunch (cold start) → org hub **shows** "QA Device Firm /
   qa-device-131043 / Partner / ACTIVE" → matter creation works.

**Leading hypothesis (prove or refute, do not assume).**
`ActiveOrgStore.syncFromSession` (`lib/app/active_org_store.dart:118-124`) seeds the
active org **only when the session userId changes**:

```dart
final String? userId = session?.userId;
if (userId == _seededUserId) { return; }   // ← early return
_seededUserId = userId;
```

A sign-out that does not null the session's userId (or a re-auth of the same user
that never re-emits a null session) therefore leaves `_seededUserId == userId`, the
seed is skipped, and `_activeOrganizationId` stays `null` — while a cold start
builds a fresh store and seeds correctly.

**STEP 0 — baseline (measure, never trust a stale ledger).**

```
cd C:\flutter_projects\law_app
git rev-parse HEAD                # MUST be e92cccb (the docs commit: device evidence + wave plan)
git status --porcelain=v1         # MUST be empty
git rev-list --count origin/main..HEAD   # MUST be 1 (the docs commit is local — NEVER PUSH)
git ls-remote origin refs/heads/main     # MUST be c835ceddda58427adedc8377344b52bb819eeebb
flutter analyze --no-pub          # 0 issues
flutter test                      # 1741 tests, all green — record the exact count
```

**STEP 1 — PROBE FIRST (no production edit).** Write a **test** that reproduces the
device sequence at the seam level and states which of the two candidate causes holds:

- candidate **A**: `session.memberships` is **empty** after the re-auth (the
  memberships read returns nothing) → the defect is in the hydration read, not the
  store;
- candidate **B**: `session.memberships` is **non-empty** but
  `ActiveOrgStore.activeOrganizationId` is `null` after the re-auth → the defect is
  the seed guard at `active_org_store.dart:120`.

Use the existing seams: `AuthCubit` (`lib/features/auth/presentation/auth_cubit.dart`),
`AuthCubit.hydrate()` / `_applyAuthenticatedSession`
(`lib/features/auth/presentation/auth_cubit_hydration.dart:24` and `:80`),
`ActiveOrgStore.syncFromSession` (`lib/app/active_org_store.dart:118`),
`Session.activeMembership` (`lib/core/auth/session.dart:76`).
Record the observed candidate in the report. **If candidate A holds, STOP** and
report it (the fix belongs in the hydration path, not in the store) — do not
"fix" the store.

**STEP 2 — minimal fix (only under candidate B).** Re-seed the active org when the
session's **membership set** changes, not only when the user id changes. Keep the
documented invariants of `syncFromSession` intact: a selection made in the current
session wins; a persisted selection wins only if the session still holds it; a
sign-out clears the context; no notification is emitted from `syncFromSession`. Do
**not** add a second store, a polling timer, or a `notifyListeners()` inside the
seed.

**Owned paths (exclusive).** `lib/app/active_org_store.dart` and its test file only.
**FORBIDDEN (do not touch).** `lib/features/auth/**`, `lib/features/orgs/**`,
`lib/app/router*.dart`, `lib/l10n/**`, `test/**` files outside your own new test,
`docs/**`, `supabase/**`.

**Gates (after the change, in the same tree).**

```
flutter analyze --no-pub          # 0 issues
flutter test                      # 1741 + your new tests, all green
bash scripts/verify_ledger.sh     # PASS (115/0)
bash scripts/verify_arb_parity.sh # PASS (510/510/510) — no l10n change, must stay
```

**Commit (explicit pathspec, one rollback unit).**

```
git add -- lib/app/active_org_store.dart test/app/active_org_store_test.dart
git commit -m "fix(org): re-seed the active organization when the session membership set changes"
```

**Report shape (verbatim, no prose padding).**
1. STEP-0 verbatim outputs (HEAD, porcelain, unpushed, ls-remote, analyze count, test count).
2. The probe result: **candidate A or B**, with the exact assertion output.
3. The diff summary (`git show --stat`).
4. The gate outputs (analyze, test count, ledger, ARB parity).
5. `git status --porcelain=v1` after the commit (must be empty) and `git rev-parse HEAD`.
6. Deviations, if any.

**STOP list (a STOP is success).**
- Candidate A holds → STOP, report the hydration-path defect with the assertion.
- The fix requires touching `lib/features/auth/**` → STOP, report why.
- `flutter test` count changes by more than your own new tests → STOP, report the delta.
- The ledger or ARB parity gate fails → STOP, report the verbatim failure.
- Any of the other findings is out of this brief's scope → ignore it, do not fix it.

---

# PROMPT 2 — W2: an unmatched deep link must not render a raw GoException

**Context.** Device finding F2. Sending a `VIEW` intent to the dev flavor
(`am start -a android.intent.action.VIEW -d "com.legalhub.app.dev:///tasks"`) while the
app is running renders a raw error page:

```
Page Not Found
GoException: no routes for location: com.legalhub.app.dev:///tasks
```

`lib/app/router.dart` builds the router with `initialLocation` (`:132-134`) and a
`redirect` (`:182`) but **no `errorBuilder` and no `onException`**. The app's own
deep-link feature deliberately ignores anything that is not an accept-invite link
(`lib/app/deep_link/app_link_parser.dart`: `AcceptInviteIntent` / `RecoveryIntent` /
`NoAppLinkIntent`), so the raw URI arrives as an unmatched *platform initial route*
and GoRouter throws.

**STEP 0 — baseline.** Same commands as PROMPT 1 (HEAD must be the W1 commit
`8b5b08b` unless a later wave landed, porcelain empty, unpushed = 2, ls-remote
`c835ced…`; record the exact `flutter test` count: **1745**).

**STEP 1 — PROBE FIRST.** Reproduce the defect **without a device**: construct the
router with an unmatched initial location and assert what the app renders. Confirm
(a) the raw `GoException` text is what the user sees, and (b) that the accept-invite
path (`com.legalhub.app://accept-invite?token=…`) still routes to
`AppRoutes.acceptInvitation` — the accept-invite flow must keep working exactly as
before (it is the one deep link the app owns). Read
`lib/app/deep_link/app_link_listener.dart` and `app_link_parser.dart` before
touching anything.

**STEP 2 — minimal fix.** Give the router a graceful unmatched-route outcome: an
`errorBuilder` (and/or `onException`) that renders a calm, localized "this link
could not be opened" surface with a route back into the app — **no raw exception
text on screen**. Reuse the existing shared widgets (`lib/shared/widgets/**`) and
the existing l10n keys if one already fits; if a new string is needed, you may add
it to the three ARB files **only if** you also regenerate the localization files and
`scripts/verify_arb_parity.sh` still passes — otherwise STOP and propose the copy
in the report instead of adding a key.

**Do NOT** change the accept-invite or recovery deep-link behaviour, and do NOT
turn general URI paths into routes (the app owns exactly one deep link).

**Owned paths (exclusive).** `lib/app/router.dart` and the router/deep-link test
files you add or extend. **FORBIDDEN.** `lib/app/deep_link/**` (read-only for you),
`lib/features/**`, `lib/l10n/**` (unless you proved a new key is required and the
parity gate passes), `supabase/**`, `docs/**`.

**Gates.** `flutter analyze --no-pub` · `flutter test` · `scripts/verify_ledger.sh` ·
`scripts/verify_arb_parity.sh`.

**Commit.** `git add -- lib/app/router.dart test/…` then
`git commit -m "fix(router): render a calm surface for unmatched deep links instead of a raw GoException"`.

**Report shape / STOP list.** Same shape as PROMPT 1. STOP if: the accept-invite
routing cannot be preserved without touching `lib/app/deep_link/**`; a new l10n key
is required and you are not prepared to regenerate the localizations; the fix would
need a router-wide behavior change beyond the unmatched-route case.

---

# PROMPT 3 — W3: honest copy in a configured build (home subtitles + Settings)

**Context.** Device finding F1. In a **configured** build (real backend, real
account) the dashboard still advertises the server-backed features as demo data:
"Schedule a consultation — development demo.", "Browse demo matter files — development
demo.", "Browse demo document metadata — development demo.", "Browse demo message
threads — development demo.", "Browse demo invoice metadata — development demo.",
"View org activity alerts — read-only demo feed.", "Browse demo tasks — development
demo." — and Settings shows "Partner / **Development-only demo session**" with a
sign-out button labelled "**End demo session**".

**Correction (do not "fix" these).** The entries whose data is synthetic in *every*
build — discovery, video, compliance alerts, pending approvals, AI research — keep
their demo wording, because their gateways are fake-only
(`service_locator_features.dart:45` registers `FakeVideoGateway.new`; there is no
`supabase_*` impl for them). Their wording is truthful. Only the **server-backed**
entries listed above, plus the Settings role card and the sign-out label, are
dishonest in a configured build.

**STEP 0 — baseline** (same commands; also record `bash scripts/verify_arb_parity.sh`
= **511/511/511** before you touch any ARB file, and `flutter test` = **1750**).

**STEP 1 — PROVE THE TRUTH PER ENTRY.** For each of the twelve home entries in
`lib/features/home/domain/home_entries.dart`, determine from the DI registration
whether its data comes from a real (Supabase-backed) gateway or a fake-only one in a
configured build. Record the verdict per entry in the report. **Any entry whose
gateway is fake-only keeps its current subtitle — no change.**

**STEP 2 — minimal change.**
- Introduce a per-entry truth flag in the home-entry descriptor (e.g.
  `isServerBacked`) — **not** a single global posture flag, because the two
  populations differ.
- For the server-backed entries, the subtitle must read as the real feature in a
  configured build and keep the demo wording in an unconfigured (demo-posture) build.
  Implement it with the existing posture seam
  (`backendIsLocalOnly` / `BackendPosture`, `lib/core/backend_posture.dart`) or the
  per-gateway truth where one already exists (booking already has a gateway-level
  `isLocalOnly`).
- The Settings role card and the sign-out label must reflect the real posture (a
  real account is not a "demo session").
- New copy ⇒ **three** ARB files (`en`, `ar`, `tr`) with the same key set, then
  regenerate the localization files, then `scripts/verify_arb_parity.sh` must still
  report `en=ar=tr=<same count>` for all three. Pin the exact per-locale wording in
  `test/app_localizations_test.dart` the way the neighbouring wording pins are
  written (see the existing pinned-wording tests in that file).

**Owned paths (exclusive).** `lib/features/home/**`,
`lib/features/home/presentation/settings_screen.dart`, `lib/l10n/**` (ARB + generated
files), `test/app_localizations_test.dart`, and the home/settings test files you
add. **FORBIDDEN.** `lib/features/**` outside `home/`, `lib/app/**`,
`lib/data/**`, `supabase/**`, `docs/**`, and any test file you did not extend.

**Gates.** `flutter analyze --no-pub` · `flutter test` · `scripts/verify_ledger.sh` ·
`scripts/verify_arb_parity.sh` (all three locales equal).

**Commit.** `git add -- <the exact paths you changed>` then
`git commit -m "fix(ui): keep dashboard and settings copy honest in a configured build"`.

**Report shape / STOP list.** Same shape. STOP if: the per-entry truth cannot be
established from the DI registrations (report the entries you could not classify);
the l10n net cannot be kept at parity in three locales without touching files
outside your scope; the fix would require a new l10n **key** (report the proposed
copy instead of adding it).

---

# PROMPT 4 — W4: the creator of a matter must be able to read it (D1: creator carve-out)

**Context.** Device finding F4. `create_matter` writes no creator column and the read
policy (`supabase/policies/matters.sql`) is:

```sql
using (public.is_active_member(organization_id)
       and (assigned_client_id = auth.uid() or assigned_attorney_id = auth.uid()))
```

⇒ a partner who creates a matter without assigning someone gets a matter they can
never read back (device: matter `a457cf53…` invisible; the same matter with the
client assigned is visible).

**Owner ruling D1 (2026-10-21):** the fix is a **creator carve-out** in the read
policy; the audit's "no carve-out exists (Q4)" note is relaxed for this case. The
matters table has **no `created_by` column**, so the carve-out needs three backend
pieces plus a client half.

**Scope split (do not mix):** this brief delivers the **backend** half (SQL + repo
SQL files + the local battery) **and** the **client** half (copy + refresh), as two
commits. The **PM applies the SQL to the live project** through the dashboard SQL
Editor after your SQL lands and your local proof is green — you must NOT touch the
live project.

**STEP 0 — baseline** (same commands) + `git status --porcelain=v1` must be empty.

**STEP 1 — PROVE (locally, on the ephemeral stack).** The policy batteries are
destructive: they run **only** on a fresh ephemeral local stack
(`supabase start` on scratch ports 54421–54424), never against the dev project.
Recipe (from the previous session's close-out): start Docker → scratch
`supabase/config.toml` ports 54421–54424 → `supabase start` → the URL-last `psql`
shim under Git Bash → `--apply` then the full battery. Prove on the local stack:
(a) a matter created without an assignee is unreadable by its creator (the current
behavior), and (b) after your change the creator **can** read it, while the
assignment gate still denies an unassigned, non-creator member.

**STEP 2 — backend change (repo SQL only).**
1. A new numbered migration file under `supabase/migrations/` that adds
   `created_by uuid references auth.users(id) on delete set null` to `public.matters`
   (plus the index the read path needs) — follow the numbering/style of the existing
   `17`…`20` files and do **not** use `supabase db push` (the live project has no
   migration history; the PM applies SQL by hand).
2. `supabase/rpc/create_matter.sql`: set `created_by = auth.uid()` on insert. Keep
   every existing audit gate untouched (F2-D1 partner gate, F2-D2 platform-owner
   ban, F2-D4 assignee-must-be-an-active-member, the title check, the redacted
   audit write). Bump the RPC's `create or replace` body accordingly.
3. `supabase/policies/matters.sql`: extend the read policy with the creator arm
   (`or created_by = auth.uid()`) **and update the file's own comment block** to
   record the owner's D1 ruling (the comment currently states "no carve-out
   exists, Q4" — that statement is now wrong and the file must say so, with the
   date and the ruling).
4. Backfill: existing matters have no `created_by`; the carve-out simply does not
   apply to them (their readers are the assignees) — state that in the apply record,
   do not backfill from the audit log.

**STEP 3 — client change.** The create-matter success copy must state the visibility
rule plainly, and the matters list must refresh when the create screen completes
(today it only updates when the screen is re-entered). If the copy needs a new
l10n key, add it to all three ARB files, regenerate, and keep
`scripts/verify_arb_parity.sh` at parity; otherwise reuse the existing keys and
report the exact wording you used.

**Owned paths (exclusive).** `supabase/migrations/<your new file>.sql`,
`supabase/rpc/create_matter.sql`, `supabase/policies/matters.sql`,
`lib/features/matters/**` (+ its tests). **FORBIDDEN.** `supabase/tests/**` (unless
you extend a battery for the new behavior — if you do, say so), `lib/app/**`,
`lib/l10n/**` (report proposed copy instead of adding keys), `docs/**` except the
apply record the PM writes, and **the live project** (no live SQL, ever).

**Gates.** `flutter analyze --no-pub` · `flutter test` · `scripts/verify_ledger.sh` ·
`scripts/verify_arb_parity.sh` · the local stack battery (`--apply` then the full
battery) with the exact pass counts.

**Commits (two, explicit pathspecs).**

```
git add -- supabase/migrations/<new>.sql supabase/rpc/create_matter.sql supabase/policies/matters.sql
git commit -m "feat(db): let a matter's creator read the matter they created"
git add -- lib/features/matters/... test/...
git commit -m "fix(matters): explain the visibility rule and refresh the list after create"
```

**Report shape / STOP list.** Same shape as PROMPT 1, plus: the exact SQL you wrote
(pasted, so the PM can apply it), the local-stack proof output for (a) and (b), and
the battery pass counts. STOP if: the carve-out cannot be expressed without a
second policy that widens the read gate for non-creators; the battery fails for a
reason unrelated to your change; the live apply would require `supabase db push`.

---

# PROMPT 5 — W5: a client path to create a message thread (D2)

**Context.** Device finding F5. A real user cannot start a conversation: the app
only reads `message_threads` and calls `send_message(p_thread_id, p_body)` on an
existing thread, `message_threads` has **no INSERT grant for `authenticated`**
(`revoke all on public.message_threads from anon, authenticated` in
`migrations/06_message_threads.sql`), and no create-thread RPC exists. A manual
insert attempt was rejected by Postgres (`42501 permission denied for table
message_threads`). The thread-detail surface is therefore unreachable in a
configured build — and it is one of the posture-gated surfaces (its "Demo mode"
note must be verifiable against a real thread).

**Scope split:** this brief delivers the **backend** half (a `create_thread` RPC +
its grant) **and** the **client** half (a "start a thread" affordance in the
matter's Messages section + the client surface). The **PM applies the SQL live**
after your SQL + local proof are green.

**STEP 0 — baseline** (same commands) + `git status --porcelain=v1` empty.

**STEP 1 — DESIGN + PROVE (read first).** Read `supabase/rpc/send_message.sql`
(the sibling write path and its authorization shape),
`supabase/migrations/06_message_threads.sql` (columns, RLS, grants),
`supabase/policies/` (the assignment-scoped read policy) and
`lib/features/messaging/**` (the client seam). Decide and record:
- the RPC signature (e.g. `create_thread(p_organization_id uuid, p_matter_id uuid,
  p_title text) returns uuid`);
- the authorization gates, mirroring the sibling conventions: the caller must be an
  **active partner of the org** (like `create_matter`'s F2-D1) **and** the matter must
  belong to that org, and the title must be non-empty;
- whether the thread's initial `participants` may be client-supplied (the column is
  `text[]` of generic display names, never identities) — if yes, state the
  redaction rule; if no, seed it server-side with the caller's display name;
- the client affordance: a "new thread" action in the matter's Messages section
  that calls the RPC and then opens the thread detail.

**STEP 2 — backend change (repo SQL only).** A new `supabase/rpc/create_thread.sql`
(SECURITY DEFINER, `search_path = public`, `revoke … from public, anon`, `grant
execute … to authenticated`) with the gates from STEP 1, writing the redacted audit
row the sibling writes use (`write_audit`, redacted summary — never the title), and
a policy/grants file consistent with the repo's `supabase/policies/` and
`supabase/rpc/` conventions. Add the client path in `lib/features/messaging/**` (or
`lib/features/matters/**` for the affordance) with a unit test for the new seam and
a widget test for the affordance.

**STEP 3 — prove locally.** On the ephemeral local stack (destructive batteries only
there): create a thread through the new RPC as an active partner, and prove that
(a) the thread is visible to the caller, (b) a non-member / a suspended member is
denied, and (c) a non-partner role is denied.

**Owned paths (exclusive).** `supabase/rpc/create_thread.sql` (+ a policy file if
the design needs one), `lib/features/messaging/**`, `lib/features/matters/**`
(the affordance only) and their tests. **FORBIDDEN.** `supabase/migrations/**`
(except a pure additive migration if the design proves one is needed — say so),
`supabase/tests/**` (unless you extend a battery, and then say so), `lib/app/**`,
`lib/l10n/**` (report proposed copy), `docs/**`, and **the live project**.

**Gates.** `flutter analyze --no-pub` · `flutter test` · `scripts/verify_ledger.sh` ·
`scripts/verify_arb_parity.sh` · the local battery with exact counts.

**Commits (two, explicit pathspecs).** Backend first, then client:

```
git add -- supabase/rpc/create_thread.sql supabase/policies/<yours>.sql
git commit -m "feat(db): add a create_thread RPC so a partner can open a conversation"
git add -- lib/features/messaging/... lib/features/matters/... test/...
git commit -m "feat(messaging): start a message thread from a matter"
```

**Report shape / STOP list.** Same shape as PROMPT 4 (paste the exact SQL, the local
proof output, the battery counts). STOP if: the design cannot satisfy "a partner of
the org may open a thread on a matter of that org" without widening the
`message_threads` **read** policy; the thread's `participants` would have to carry a
real identity (PII) — that is forbidden, stop and report; the local battery fails
for a reason unrelated to your change.

---

## Campaign close-out (to be written by the PM)

For each wave: the executor's verbatim report, the PM's independent re-verification
(diffs re-read at the cited lines, gates re-run, commit paths proven with
`git show --name-only`), the accepted deviations, the wave verdict, and the master
state after each landing. Landed waves are pushed only on an explicit owner GO
(proof: `git ls-remote origin refs/heads/main` == HEAD, never the tracking ref).
