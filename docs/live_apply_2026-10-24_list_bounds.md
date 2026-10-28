# Live apply — 2026-10-24 list bounds, audit indexes, payment retry, research scoping

**STATUS: APPLIED 2026-10-28** (see `docs/live_apply_2026-10-28_audit_followups.md`).
This document is the forward-only apply plan for this change.

**Scope:** `supabase/migrations/28_audit_indexes_and_list_bounds.sql`, seven
bounded list RPCs under `supabase/rpc/`, `supabase/rpc/initiate_invoice_payment.sql`,
`supabase/functions/research-analyze/index.ts`, and
`supabase/policies/messages_insert.sql`. No Dart, Android or web files are
involved.

## What changed and why

| Finding (verified at source) | Fix |
|---|---|
| `audit_events` had no secondary index while `read_org_audit` filters by `organization_id` and orders by `server_timestamp desc`, and `read_platform_audit` orders globally | Migration 28 adds `audit_events_org_ts (organization_id, server_timestamp desc)` and `audit_events_ts (server_timestamp desc)`, both idempotent |
| Seven list RPCs returned every matching row (`list_approval_requests`, `list_compliance_alerts`, `list_matter_assignable_members`, `list_org_members_metadata`, `list_research_findings`, `list_research_runs`, `list_video_sessions`) | Each takes `p_limit int default 200, p_offset int default 0`, clamps them to `1..500` / `>= 0`, and applies `limit … offset …` after the existing deterministic order. The old signatures are dropped, not left as overloads |
| `initiate_invoice_payment` withheld `provider_order_id`, so `paymob-initiate` minted a new Paymob order on every retry and re-attached | Both response branches now include `provider_order_id`; the existing pending branch reads it from the row, the new branch returns `null`. `paymob-initiate` already reads the field and skips `attach_paymob_order` when it is set |
| `research-analyze` read documents by `organization_id + id` only, so a matter-scoped run could cite another matter's document | The document read also filters `matter_id` when the run supplies a matter. `document_ids` is capped at 50 with a typed `422 too_many_documents` before any run row or paid call |
| `policies/messages_insert.sql` re-granted direct INSERT when applied without `send_message.sql` | The file is marked SUPERSEDED and self-neutralizes: it drops `messages_insert_assigned` and revokes INSERT from `authenticated` at the end |

The 12k context cap and every auth/role check are unchanged. The page
parameters are additive and defaulted, so the existing Dart named-argument
calls stay compatible; no client change is required.

## Exact new RPC signatures

```
public.list_approval_requests(uuid, text, integer, integer)
public.list_compliance_alerts(uuid, text, text, integer, integer)
public.list_matter_assignable_members(uuid, integer, integer)
public.list_org_members_metadata(uuid, integer, integer)
public.list_research_findings(uuid, integer, integer)
public.list_research_runs(uuid, integer, integer)
public.list_video_sessions(uuid, integer, integer)
```

`initiate_invoice_payment(uuid)` keeps its signature; only its jsonb response
shape changes. `list_attorney_profiles`, `list_members_metadata`,
`list_organizations_metadata` and `list_stale_pending_payments` already had
limits and are unchanged.

## Preflight (read-only; record output)

Run as the connection role against the target project.

```sql
-- 1. Audit indexes (expect only the primary key before the apply).
select indexname, indexdef
  from pg_indexes
 where schemaname = 'public'
   and tablename = 'audit_events'
 order by indexname;

-- 2. Current list RPC signatures, security posture and grants.
select p.proname,
       pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef,
       p.proconfig,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('list_approval_requests', 'list_compliance_alerts',
                     'list_matter_assignable_members', 'list_org_members_metadata',
                     'list_research_findings', 'list_research_runs',
                     'list_video_sessions', 'initiate_invoice_payment',
                     'list_attorney_profiles', 'list_members_metadata',
                     'list_organizations_metadata', 'list_stale_pending_payments')
 order by p.proname, args;

-- 3. Payment row shape and pending rows that will exercise retry.
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public' and table_name = 'payments'
   and column_name in ('provider_order_id', 'paymob_order_id');
select id, invoice_id, status, provider_order_id
  from public.payments
 where status = 'pending'
 order by created_at desc
 limit 20;

-- 4. Message INSERT surface (expect the grant + policy before this wave).
select has_table_privilege('authenticated', 'public.messages', 'INSERT') as auth_insert;
select policyname from pg_policies
 where schemaname = 'public' and tablename = 'messages';
```

Expect the seven list RPCs to show their single-argument (or two/three
argument) signatures before the apply. If an old unbounded overload and a new
bounded overload both exist after the apply, stop and drop the old one.

## Forward-only apply order

Use the repo convention (`supabase db query --linked --file …`), **never**
`supabase db push`. Apply once, in this order.

### 1. Migration 28 (indexes)

```bash
supabase db query --linked --file supabase/migrations/28_audit_indexes_and_list_bounds.sql
```

### 2. List RPCs

```bash
supabase db query --linked --file supabase/rpc/list_approval_requests.sql
supabase db query --linked --file supabase/rpc/list_compliance_alerts.sql
supabase db query --linked --file supabase/rpc/list_matter_assignable_members.sql
supabase db query --linked --file supabase/rpc/list_org_members_metadata.sql
supabase db query --linked --file supabase/rpc/list_research_findings.sql
supabase db query --linked --file supabase/rpc/list_research_runs.sql
supabase db query --linked --file supabase/rpc/list_video_sessions.sql
```

Each file creates the new signature, drops the old signature, then revokes
`PUBLIC`/`anon` and grants `authenticated` on the new signature.

### 3. Payment retry response

```bash
supabase db query --linked --file supabase/rpc/initiate_invoice_payment.sql
```

No `paymob-initiate` redeploy is required: the deployed function already reads
`provider_order_id` and skips `attach_paymob_order` when it is present.

### 4. Stale messages policy (self-neutralizing)

```bash
supabase db query --linked --file supabase/policies/messages_insert.sql
```

The file grants INSERT and creates the historical policy, then immediately
drops the policy and revokes the grant. Applying it before or after
`rpc/send_message.sql` leaves the same end state: no direct INSERT path.

### 5. `research-analyze` (edge function, separate deploy)

The source change is in the tree, but `research-analyze` is **not deployed**
(baseline). When it is deployed, use the CLI from the repo root so `_shared/`
is bundled:

```bash
supabase functions deploy research-analyze
```

Requires `RIVER_API_KEY` (and the prior `ALLOWED_ORIGINS` work) before the
function can answer; until then it returns `provider_not_configured`.

## Post-apply verification

### A. Indexes

```sql
select indexname, indexdef
  from pg_indexes
 where schemaname = 'public'
   and tablename = 'audit_events'
 order by indexname;

-- Shapes the two audit read paths.
explain (costs off)
select id from public.audit_events
 where organization_id = '<org-id>'
 order by server_timestamp desc
 limit 200;

explain (costs off)
select id from public.audit_events
 order by server_timestamp desc
 limit 200;
```

Expect `audit_events_org_ts` and `audit_events_ts`, and an index scan (not a
full sort) for each query on a non-trivial table.

### B. Signatures and grants

```sql
select p.proname, pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef, p.proconfig,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('list_approval_requests', 'list_compliance_alerts',
                     'list_matter_assignable_members', 'list_org_members_metadata',
                     'list_research_findings', 'list_research_runs',
                     'list_video_sessions')
 order by p.proname;

-- Expect exactly one row per function, the new args, prosecdef = t,
-- proconfig containing search_path=public, auth_exec = t, anon_exec = f.
```

### C. Bounds behavior (as an authenticated caller)

```sql
-- Over-cap request is clamped to 500 rows (not an error).
select count(*) from public.list_research_runs('<org-id>', 1000, 0);

-- Zero/negative page size and negative offset are corrected server-side.
select count(*) from public.list_research_runs('<org-id>', 0, -5);

-- Default arity still resolves (named-argument / omitted defaults).
select count(*) from public.list_research_runs('<org-id>');
```

### D. Payment retry

```sql
-- First call creates the pending row (provider_order_id null).
select public.initiate_invoice_payment('<invoice-id>');
-- Attach an order as the service role (rehearsal only):
select public.attach_paymob_order('<payment-id>', 'po-verify-1');
-- Second call must return the SAME payment_id and provider_order_id='po-verify-1';
-- paymob-initiate then skips attach_paymob_order.
select public.initiate_invoice_payment('<invoice-id>');
```

Confirm the response has exactly one `provider_order_id` and that
`paymob-initiate` logs no second order creation on retry.

### E. Messages policy

```sql
select has_table_privilege('authenticated', 'public.messages', 'INSERT');  -- f
select count(*) from pg_policies
 where schemaname = 'public' and tablename = 'messages'
   and policyname = 'messages_insert_assigned';  -- 0
```

### F. `research-analyze` (after deploy)

- POST 51 unique `document_ids` → `422 {"error":"too_many_documents"}` before
  any run row or provider call.
- POST a document id that belongs to a different matter with a `matter_id` →
  `403 {"error":"forbidden"}`.
- POST a document id in the supplied matter → 200, and findings cite only
  supplied ids.

## Rehearsal prerequisites (outside this wave's ownership)

The full `--apply` policy battery will fail until these frozen tests are
updated by their owner. They were not touched in this change:

- `supabase/tests/20_payment_rls.sql:75` asserts the response has **no**
  `provider_order_id`. Update the projection assertion to require the field
  (null on first insert, the attached id on retry).
- `supabase/tests/21_task_assignable_members_rls.sql:329-330` asserts exactly
  one IN parameter for `list_matter_assignable_members`, and line 350 pins
  `pg_get_function_identity_arguments(...) = 'p_matter_id uuid'`. Update both
  to the 3-argument identity.

Also: `scripts/verify_policy_tests.sh --apply` still lists migrations only
through `27_audit_remediation.sql`; it does not apply migration 28, so the
rehearsal does not exercise the new indexes. This wave was scoped to the RPC
signature list only, so adding `28_audit_indexes_and_list_bounds.sql` to the
apply list remains a follow-up (the `--check` gate does not need it).

## Rollback

### 1. Restore the seven list RPCs

The old bodies are in git at the commit before this change. Because the new
signature is an overload, drop the new signature **first**, then apply the old
files:

```sql
drop function if exists public.list_approval_requests(uuid, text, int, int);
drop function if exists public.list_compliance_alerts(uuid, text, text, int, int);
drop function if exists public.list_matter_assignable_members(uuid, int, int);
drop function if exists public.list_org_members_metadata(uuid, int, int);
drop function if exists public.list_research_findings(uuid, int, int);
drop function if exists public.list_research_runs(uuid, int, int);
drop function if exists public.list_video_sessions(uuid, int, int);
```

```bash
git show <pre-apply-sha>:supabase/rpc/list_approval_requests.sql > /tmp/list_approval_requests.sql
# … repeat for the other six
supabase db query --linked --file /tmp/list_approval_requests.sql
# … repeat for each restored file
```

### 2. Restore `initiate_invoice_payment`

```bash
git show <pre-apply-sha>:supabase/rpc/initiate_invoice_payment.sql > /tmp/initiate_invoice_payment.sql
supabase db query --linked --file /tmp/initiate_invoice_payment.sql
```

`create or replace` with the same `(uuid)` signature replaces the body; the
response reverts to omitting `provider_order_id`, at the cost of the retry
reuse.

### 3. Indexes

```sql
drop index if exists public.audit_events_org_ts;
drop index if exists public.audit_events_ts;
```

### 4. Messages policy

No database rollback is needed: the hardening removes a write path. If the
pre-wave unaudited posture must be restored on a project where
`send_message.sql` was never applied, re-apply the historical
`policies/messages_insert.sql` from git; do not do this on a project that
routes sends through `send_message` (it would re-open direct INSERT).

### 5. `research-analyze`

Redeploy the pre-change function from the reverted tree (or revert the
function commit and deploy again). No database rollback.
