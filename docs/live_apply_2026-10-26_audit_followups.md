# Live apply — 2026-10-26 audit follow-ups (29 indexes + 30 profiles contract)

**STATUS: NOT APPLIED.** This document is the forward-only apply plan for this
change. Nothing here was run against a live database, and no edge function or
client was deployed.

**Scope:** `supabase/migrations/29_membership_and_order_indexes.sql` and
`supabase/migrations/30_profiles_mutations_rpc_only.sql`, plus their companion
down files. Also added in the same wave (not applied by this plan):
`21_matter_creator.down.sql` and `28_audit_indexes_and_list_bounds.down.sql`.
Repo artifacts updated in the same change (no database apply):
`supabase/policies/profiles.sql` (no longer declares `profiles_update_own`)
and `supabase/tests/01_identity_session.sql` (CHECK 01.04-01.06 assert the
42501 denial contract). The live database change remains only migrations 29
and 30. No Dart, Android, web, RPC body, or edge function is changed.

## What changed and why

| Finding (verified at source, HEAD `0b52374`) | Fix |
|---|---|
| `memberships` is read by `user_id` for the active-membership lookup, but its only index is the unique `(organization_id, user_id)` constraint — `user_id` is not a usable leading column | Migration 29 adds `memberships_user (user_id)` |
| `documents` / `files` / `tasks` list reads filter `organization_id` and order `created_at desc` (`lib/data/list_query_guards.dart:29-51`); the existing indexes are `organization_id` only, so every page sorts | Migration 29 adds `(organization_id, created_at desc)` for each |
| `billing_invoices` filters `organization_id` and orders `issued_at desc`; `message_threads` filters `organization_id` and orders `last_activity_at desc`; both existing indexes are `organization_id` only | Migration 29 adds `(organization_id, issued_at desc)` and `(organization_id, last_activity_at desc)` |
| `research_runs` has org-first indexes (`research_runs_org_created`, `research_runs_matter`), which already serve the only read path (`list_research_runs` filters by organization and orders by created_at) | No new index (the previously proposed `(requested_by, created_at desc)` could not serve that query) |
| `profiles` still has one direct client mutation: 01's `grant select, update (display_name, locale)` plus `profiles_update_own`. That contradicts the stated "ALL mutations RPC-only" contract | Migration 30 revokes both UPDATE ACL layers and drops `profiles_update_own`; SELECT stays via `profiles_select_own` |

### Evidence that profiles UPDATE has no client or RPC dependency

Read-only checks run at HEAD `0b52374` on 2026-10-26:

```text
rg -n --glob "*.dart" "from\('profiles'\)" lib test          → 0 matches
rg -n --glob "*.dart" 'from\("profiles"\)' lib test          → 0 matches
rg -n -i "(update|insert into|delete from)\s+(public\.)?profiles" supabase
  → 02_rls_functions.sql:74  insert into public.profiles  (handle_new_user trigger)
  → supabase/tests/*         fixture inserts/updates only
  → no RPC, no migration UPDATE
rg --files-without-match -i "security definer" supabase/rpc
  → supabase/rpc/_down.sql only (drops; defines no function)
```

`handle_new_user()` is `security definer` and performs an INSERT, which the
UPDATE revoke does not affect. `delete_my_account()` is `security definer` and
deletes `auth.users`; the `profiles` row goes via the FK cascade, not a grant.
The profile-reading joins in `list_org_members_metadata`,
`list_members_metadata`, and `send_message` run inside `security definer`
bodies. The only direct authenticated UPDATE path in the repo was the policy
battery itself; the battery now asserts denial (see "Companion repo changes"
below).

## Preflight (read-only; record output)

Run as the connection role against the target project.

```sql
-- 1. Index inventory for the six tables. Expect none of the six new names
--    (29_preflight) and note the existing index names/shapes.
select tablename, indexname, indexdef
  from pg_indexes
 where schemaname = 'public'
   and tablename in ('memberships', 'documents', 'files', 'billing_invoices',
                     'message_threads', 'tasks')
 order by tablename, indexname;

-- 2. Profiles policy + both UPDATE ACL layers (expect the policy present and
--    all three booleans true before the apply).
select policyname, cmd, qual, with_check
  from pg_policies
 where schemaname = 'public' and tablename = 'profiles';

select has_table_privilege('authenticated', 'public.profiles', 'UPDATE') as table_update,
       has_column_privilege('authenticated', 'public.profiles', 'display_name', 'UPDATE') as display_name_update,
       has_column_privilege('authenticated', 'public.profiles', 'locale', 'UPDATE') as locale_update;

-- 3. Row counts (context for the non-concurrent index build window).
select 'memberships' as table_name, count(*) from public.memberships
union all select 'documents', count(*) from public.documents
union all select 'files', count(*) from public.files
union all select 'billing_invoices', count(*) from public.billing_invoices
union all select 'message_threads', count(*) from public.message_threads
union all select 'tasks', count(*) from public.tasks
union all select 'research_runs', count(*) from public.research_runs;

-- 4. Profile-reading RPCs must stay SECURITY DEFINER (they read profiles
--    without an authenticated UPDATE grant).
select p.proname, p.prosecdef, p.proconfig
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('list_org_members_metadata', 'list_members_metadata', 'send_message')
 order by p.proname;
-- Expect prosecdef = true for each.
```

If any preflight differs (e.g. `profiles_update_own` missing, or an update
boolean already false), stop and re-derive the state before applying.

## Forward-only apply order

Use the repo convention (`supabase db query --linked --file …`), **never**
`supabase db push`. Apply once, in this order.

### 1. Migration 29 (indexes)

```bash
supabase db query --linked --file supabase/migrations/29_membership_and_order_indexes.sql
```

`create index` is not `concurrent`, so each build takes a SHARE lock that blocks
writes on its table. Run in a low-traffic window when any table is large; the
file is `if not exists`, so a re-run after a partial failure is safe.

### 2. Migration 30 (profiles contract)

Only after the preflight confirms no direct writer. The shipped client has no
`.from('profiles')` write path, so no client deploy is required.

```bash
supabase db query --linked --file supabase/migrations/30_profiles_mutations_rpc_only.sql
```

The file revokes table-level UPDATE, revokes the column-level
`update (display_name, locale)` grant, then drops `profiles_update_own`.

## Post-apply verification

### A. Indexes exist and serve the shapes

```sql
select tablename, indexname, indexdef
  from pg_indexes
 where schemaname = 'public'
   and indexname in ('memberships_user', 'documents_org_created',
                     'files_org_created', 'billing_invoices_org_issued',
                     'message_threads_org_activity', 'tasks_org_created')
 order by indexname;
-- Expect exactly six rows.

explain (costs off)
select id from public.memberships where user_id = '<user-id>';

explain (costs off)
select id from public.documents
 where organization_id = '<org-id>' order by created_at desc limit 200;

explain (costs off)
select id from public.files
 where organization_id = '<org-id>' order by created_at desc limit 200;

explain (costs off)
select id from public.billing_invoices
 where organization_id = '<org-id>' order by issued_at desc limit 200;

explain (costs off)
select id from public.message_threads
 where organization_id = '<org-id>' order by last_activity_at desc limit 200;

explain (costs off)
select id from public.tasks
 where organization_id = '<org-id>' order by created_at desc limit 200;
```

Expect an index scan (not a full scan plus Sort) on a non-trivial table. On an
empty or tiny table the planner may still choose a sequential scan; verify with
`set enable_seqscan = off` in a rehearsal if needed.

### B. Profiles is RPC-only for mutations

```sql
select count(*) from pg_policies
 where schemaname = 'public' and tablename = 'profiles'
   and policyname = 'profiles_update_own';
-- Expect 0.

select has_table_privilege('authenticated', 'public.profiles', 'UPDATE') as table_update,
       has_column_privilege('authenticated', 'public.profiles', 'display_name', 'UPDATE') as display_name_update,
       has_column_privilege('authenticated', 'public.profiles', 'locale', 'UPDATE') as locale_update;
-- Expect f, f, f.

select has_table_privilege('authenticated', 'public.profiles', 'SELECT') as select_grant;
-- Expect t (own-row reads stay).
```

Impersonation probe (rehearsal project; rolls back):

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '<user-id>', false);
select set_config('request.jwt.claims', '{"sub":"<user-id>"}', false);
update public.profiles set display_name = 'x' where user_id = auth.uid();
-- Expect ERROR: permission denied for table profiles (SQLSTATE 42501).
rollback;
```

Repository-side verification (no database): `bash scripts/verify_policy_tests.sh
--check` passes. After 30 is applied, the battery's CHECK 01.04-01.06 must also
pass with 42501 denials (run it against a project where 30 is applied; the
harness's `--apply` list now includes 28-30 in this change).

### C. Security-definer profile reads still work

```sql
select count(*) from public.list_org_members_metadata('<org-id>', 200, 0);
```

Run with an authenticated JWT claim for an active member. A successful roster
read proves the `profiles` join still works without the direct grant.

### D. App smoke

Sign in, open the roster, send a message (author display name is resolved
inside `send_message`), and page the documents/files/invoices/threads/tasks
lists. No client change is required or expected.

## Companion repo changes (same change, no live apply)

Both companion artifacts are updated in this change, so a fresh policy apply
cannot resurrect the old path:

- `supabase/policies/profiles.sql` no longer declares `profiles_update_own`;
  `profiles_select_own` is unchanged. Migration 30 remains the database source
  of truth for the revoke.
- `supabase/tests/01_identity_session.sql` CHECK 01.04-01.06 now assert the
  post-30 contract: own-row, identity-transfer and foreign-row UPDATEs must all
  raise `insufficient_privilege` (SQLSTATE 42501). CHECK ids/names and the
  battery structure are unchanged.
- Static validation (no database): `bash scripts/verify_policy_tests.sh
  --check` passes.

The automated battery's `--apply` list now includes migrations 28-30, and the
public-policy pin is 22 (`profiles_update_own` removed); `--check` passes. The
`--apply` path was NOT executed in this change (no database was touched).

## Rollback

### 1. Profiles UPDATE surface

```bash
supabase db query --linked --file supabase/migrations/30_profiles_mutations_rpc_only.down.sql
```

Restores `grant select, update (display_name, locale)` and recreates the
pre-30 `profiles_update_own` policy from the down file (the policy-source file
no longer declares it). No data loss; the window between 30 and its down simply
has no direct UPDATE path.

### 2. Indexes

```bash
supabase db query --linked --file supabase/migrations/29_membership_and_order_indexes.down.sql
```

Drops exactly the six new indexes. They are non-unique and derivable, so this
is safe; queries fall back to the pre-29 plans.

### 3. Companion downs (not part of this apply)

- `28_audit_indexes_and_list_bounds.down.sql` drops the two audit indexes if
  the 2026-10-24 wave must be reversed.
- `21_matter_creator.down.sql` is **destructive**: it drops
  `matters.created_by` (creator attribution is lost). Revert the creator arm in
  `supabase/policies/matters.sql` and the `create_matter` body first, or the
  column drop fails on the policy dependency.

## Apply caveats

- **Contract tightening is immediate for any direct writer.** The shipped client
  has no `.from('profiles')` write; an older/unshipped build that did would
  start receiving 42501 after 30. Confirm the deployed client matches HEAD
  before applying.
- **Index builds are locking.** `create index` inside the migration takes a
  SHARE lock per table; use a low-traffic window or convert to `concurrently`
  outside the transaction if a table is large.
- **28's up header is now stale.** It says "No down migration is added"; the
  PM-directed inverse was added in this wave. The up file is intentionally
  untouched.
- **No live claim.** Every statement above is a plan or a read-only check; no
  database was connected during authoring.
