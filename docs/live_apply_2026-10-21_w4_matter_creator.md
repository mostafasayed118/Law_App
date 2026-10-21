# Live apply + incident — 2026-10-21 (W4: matter creator carve-out)

Owner-authorized live window on `law_project` (Supabase ref `eutmvevpskerzpqmwplv`,
eu-west-2), executed by the PM from the Supabase dashboard **SQL Editor**
(the environment's Management API PAT lacks `database_read`/`database_write`, the
Supabase MCP is bound to a different project, and the CLI reports
`database_write` missing — so the dashboard SQL editor was the only write path
available). `supabase db push` was **not** used (the project has no
`supabase_migrations.schema_migrations` history).

**Status: the schema apply is COMPLETE and verified. A PostgREST schema-cache
incident is OPEN and blocks the app's RPC write paths (see §Incident).**

## 1. Owner ruling

**D1 (owner, 2026-10-21)** — device finding F4: a matter's creator must be able to
read the matter they created. The audit's "no carve-out exists (Q4)" rule in
`supabase/policies/matters.sql` is relaxed for exactly this case; the policy file's
comment block now records the ruling (date + owner). Evidence:
`docs/device_e2e_2026-10-21_c835ced.md`.

## 2. Local proof (executor, before any live write)

- Ephemeral local stack only (`supabase start --workdir …`, scratch ports
  54421–54424; the pre-existing "Portfolio-Fixer" stack was never touched). The
  batteries are destructive and ran **only** there.
- `scripts/verify_policy_tests.sh --check` → 108/0 PASS
- `scripts/verify_policy_tests.sh --apply` → 70/0 PASS (69 before the change)
- `scripts/verify_policy_tests.sh` (full battery) → **126/0 PASS** (unchanged)
- Carve-out probes on the local stack:
  - before: creator-read-count = 0, non-creator = 0, suspended = 0, non-member = 0
  - after: **creator-read-count = 1**, non-creator = 0, suspended = 0, non-member = 0
- Count pins held: 15 policies, 17 public tables, 3 storage policies.

## 3. Live apply (PM, dashboard SQL Editor)

Applied in this order, as one script, from the repo SQL files (comments stripped,
the `begin;`/`commit;` wrapper of the migration dropped):

| # | Statement | Source file |
|---|---|---|
| 1 | `alter table public.matters add column created_by uuid references auth.users (id) on delete set null;` | `supabase/migrations/21_matter_creator.sql` |
| 2 | `create index matters_created_by on public.matters (created_by) where created_by is not null;` | same |
| 3 | `create or replace function public.create_matter(...)` (body now writes `created_by = auth.uid()`; every audit gate untouched) | `supabase/rpc/create_matter.sql` |
| 4 | `revoke execute on function public.create_matter(uuid, text, text, uuid, uuid) from public, anon;` | same |
| 5 | `grant execute on function public.create_matter(uuid, text, text, uuid, uuid) to authenticated;` | same |
| 6 | `drop policy if exists matters_select_assigned on public.matters;` | `supabase/policies/matters.sql` |
| 7 | `create policy matters_select_assigned on public.matters for select using (public.is_active_member(organization_id) and (assigned_client_id = auth.uid() or assigned_attorney_id = auth.uid() or created_by = auth.uid()));` | same |

Editor result: **"Success. No rows returned"**.

### Content fingerprints (SHA-256)

| Artifact | SHA-256 |
|---|---|
| applied script (assembled from the three repo files) | `cc4bbc7e6d57f292491dd67e76a87edce70af3bc7c0992cf36e462d2f655608c` |
| `supabase/migrations/21_matter_creator.sql` | `74b46c1172026813c1af4ea04767c66e7e3c8169fd2fab78ddf0e97260c4b643` |
| `supabase/rpc/create_matter.sql` | `de0b07c746d6063ee39f4ecf171778437f42365017f87ecb82c36e5b862bda85` |
| `supabase/policies/matters.sql` | `54aa4e3d4329c53b95df40688e51a6c439bd28af77095d632a268b48af40472d` |

### Post-apply verification (live, read back through the dashboard SQL editor)

| Probe | Result |
|---|---|
| `information_schema.columns` → `matters.created_by` | **1** (present) |
| `pg_indexes` → `matters_created_by` | **1** (present) |
| `pg_policy` → the read policy mentions `created_by` | **true** (carve-out live) |
| `pg_get_functiondef(create_matter)` mentions `created_by` | **true** (RPC stamps the creator) |
| `create_matter` overloads | **1** (no duplicate) |
| `has_function_privilege('authenticated', …, 'execute')` on `create_matter` | **true** (anon: false, service_role: true) |
| authenticated-callable public functions | **33** |

**Backfill:** none. Existing matters keep `created_by = NULL`, so the carve-out does
not apply to them and their readers stay the assignees. Nothing was backfilled from
the audit log (the §8 audit rows carry no creator id).

## 4. Incident — PostgREST schema cache lost its function section (OPEN)

**Symptom.** Every PostgREST **RPC** call now returns
`404 PGRST202 "Could not find the function … in the schema cache"` — for
`create_matter`, `send_message` and `list_organizations_metadata` alike, with
different argument shapes (0/3/4/5 args) and with null and non-null values.
**Table reads are unaffected** (`GET /rest/v1/memberships` → 200).

**Timeline (evidence).**

| When | What | Evidence |
|---|---|---|
| 2026-10-21 ~13:05 | the app created a matter through the `create_matter` RPC and got the id back ("Matter created", `a457cf53-d1d2-48fd-b0dc-2a333031f9bb`) | device E2E + the row in `public.matters` ⇒ the RPC path was live before this window |
| ~20:45 | the live apply (7 statements) → "Success. No rows returned" | dashboard SQL editor |
| ~20:50 | first RPC call after the apply → `404 PGRST202` (3-arg shape) | API Gateway log `21 Oct 26 21:05:20` |
| 21:06–21:15 | every RPC shape → 404; `send_message` and `list_organizations_metadata` (never touched by this wave) fail too ⇒ **the whole function section of the cache is empty**, not one function | API Gateway logs |
| 21:0x | `notify pgrst, 'reload schema'` and `select pg_notify('pgrst','reload schema')` executed → **no recovery** | dashboard SQL editor |
| 21:1x | `create or replace function` with the two `default null` args removed (PostgreSQL required `drop function` first) → the function is now default-free, still 404 | dashboard SQL editor |

**Diagnosis (what is known).** The grants are intact (`has_function_privilege`
= true for `authenticated`), the functions exist, the overload count is 1, the
column/index/policy/RPC are all in place, and table reads work. The failure is
confined to PostgREST's **function** part of the schema cache. The trigger window
is this apply; the mechanism is not yet attributed — the leading hypotheses are
(a) PostgREST v12+ excluding functions that carry default arguments from the cache
(4 of the repo's RPC files do: `create_matter`, `create_task`, `book_consultation`,
`apply_paymob_transaction`; the live `list_organizations_metadata` also has
defaults even though its repo file does not), and (b) a cache-load failure inside
PostgREST that the platform's reload path is not recovering from. The default-free
rewrite of `create_matter` did **not** restore the surface, so (a) alone does not
explain it.

**Impact.** Read paths (tables, PostgREST selects) work. **Every RPC-backed write
path is down on the live project**: matter creation, task creation, booking,
membership/org mutations and message sending — i.e. the app's write surfaces for
every account, not only the QA one.

**Remediation (needs the owner's GO — a live service window).**

1. **Restart the project** (dashboard: Project Settings → Restart project; the
   platform's PostgREST then rebuilds the schema cache from scratch). The previous
   session used the same lever on this project (`INACTIVE → ACTIVE_HEALTHY`).
2. After the restart, re-verify: `POST /rest/v1/rpc/create_matter` (the app's exact
   5-arg shape) → 200, plus one `send_message`-style call, and the carve-out
   proof (create a matter with no assignee as the QA partner → read it back).
3. If the restart restores the functions, the apply is complete and the wave
   closes; if the function section is still empty after the restart, the carve-out
   must be re-applied on a project whose PostgREST is healthy (and the wave's
   local proof re-run, since the local stack's PostgREST is a different version).

**PM note.** The live apply itself is verified correct (§3) and the local proof is
green (§2); the open item is a platform-side cache, not a schema defect. The PM
triggered the window and owns the incident.

## 5. Repo side (both commits landed locally, nothing pushed)

| Commit | Content |
|---|---|
| `2bd5984` | `feat(db): let a matter's creator read the matter they created` — the migration, the RPC (created_by), the policy + its D1 comment, the battery cases (04.11–04.14 + 13.16), the harness apply order |
| `8f435db` | `fix(matters): explain the visibility rule and refresh the list after create` — the client half: the success copy reworded ("You see it now because you created it. Others see it once it is assigned to them."), the list re-reads when the create screen closes, the l10n pin |

Gates at that commit: `flutter analyze` 0 · `flutter test` 1759/1759 ·
`dart format --output=none --set-exit-if-changed .` 0 changed ·
`scripts/verify_ledger.sh` 115/0 · `scripts/verify_arb_parity.sh` 520/520/520 ·
local battery 126/0.
