# Live apply — 2026-10-24 audit remediation (participant read gates + edge hardening)

**STATUS: APPLIED 2026-10-28** (see `docs/live_apply_2026-10-28_audit_followups.md`).
This document is the forward-only apply plan for the verified security findings
fixed in this change.

**Scope:** `supabase/migrations/27_audit_remediation.sql`,
the seven read-policy files under `supabase/policies/`, the seven read RPCs under
`supabase/rpc/`, and the `research-analyze`, `video-token` and `paymob-reconcile`
edge functions. No Flutter, Android or web files are involved.

## What changed and why

| Finding (verified at source) | Fix |
|---|---|
| `video_sessions` SELECT was `is_active_member(organization_id)` only, and `video-token` minted a 2 h publish token after that read | `video_sessions_select_org` now calls `public.can_access_video_session(id)`; `video-token` keeps the RLS read as its boundary (now participant-scoped) and still maps no-row to 404 / policy error to 403 |
| `approval_requests`, `compliance_alerts`, `research_runs`, `research_findings` (and their events tables) were readable by any active org member | Each policy now requires partner / role / requester / creator / decider / matter participant, and event tables inherit the parent row's visibility |
| The security-definer list/get RPCs bypass RLS and re-asserted only the org gate | The RPCs now re-assert the same participant predicate |
| `constantTimeEqual` lower-cased both HMAC operands | Case-sensitive SHA-256 + XOR loop; the Paymob `?auth_token=` query contract is documented and the token is never logged |
| `research-analyze` used `Access-Control-Allow-Origin: *`, concatenated untrusted titles/question into the prompt, and had no throttle before the paid provider call | `ALLOWED_ORIGINS` allowlist (echo only allowed origins), `<untrusted_context>` delimiters + data-not-instructions rule, and a 5-per-hour per-caller throttle returning 429 `rate_limited` |

## Preflight (read-only; record output)

Run as the connection role against the target project. Do not proceed if any
snapshot differs from the expected pre-27 state.

```sql
-- 1. Target identity and schema prerequisites.
select current_database(), current_user, version();
select column_name, data_type
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'matters'
   and column_name in ('assigned_client_id', 'assigned_attorney_id', 'created_by');
select column_name, data_type, is_nullable
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'video_sessions'
 order by ordinal_position;

-- 2. Current policy definitions (the rollback source of truth).
select tablename, policyname, cmd, qual
  from pg_policies
 where schemaname = 'public'
   and tablename in ('video_sessions', 'approval_requests', 'approval_events',
                     'compliance_alerts', 'compliance_alert_events',
                     'research_runs', 'research_findings')
 order by tablename, policyname;

-- 3. Current helper / RPC definitions and grants.
select p.proname,
       pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef,
       p.proconfig,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('can_read_matter', 'can_access_video_session',
                     'list_video_sessions', 'get_video_session',
                     'mark_video_session_live', 'list_approval_requests',
                     'list_compliance_alerts', 'list_research_runs',
                     'list_research_findings');

-- 4. Row-count snapshot (useful after apply and after rollback).
select 'video_sessions' as table_name, count(*) from public.video_sessions
union all select 'approval_requests', count(*) from public.approval_requests
union all select 'compliance_alerts', count(*) from public.compliance_alerts
union all select 'research_runs', count(*) from public.research_runs
union all select 'research_findings', count(*) from public.research_findings;
```

Confirm the preflight shows no `can_read_matter` / `can_access_video_session`
(they are new in 27) and that the current policy quals are the org-member text.

## Forward-only apply order

Use the repo convention (`supabase db query --linked --file …`), **never**
`supabase db push`. Each step is applied once, in this order.

### 1. Migration 27 (helpers)

```bash
supabase db query --linked --file supabase/migrations/27_audit_remediation.sql
```

This creates `public.can_read_matter(uuid, uuid)` and
`public.can_access_video_session(uuid)`, both `security definer`, `stable`,
`set search_path = public`, with `PUBLIC`/`anon` EXECUTE revoked and
`authenticated` EXECUTE granted.

### 2. Policies (idempotent drop + create)

Apply after 27, in any order:

```bash
supabase db query --linked --file supabase/policies/video_sessions.sql
supabase db query --linked --file supabase/policies/approval_requests.sql
supabase db query --linked --file supabase/policies/approval_events.sql
supabase db query --linked --file supabase/policies/compliance_alerts.sql
supabase db query --linked --file supabase/policies/compliance_alert_events.sql
supabase db query --linked --file supabase/policies/research_runs.sql
supabase db query --linked --file supabase/policies/research_findings.sql
```

### 3. Read RPCs (security definer; re-assert the participant gate)

```bash
supabase db query --linked --file supabase/rpc/list_video_sessions.sql
supabase db query --linked --file supabase/rpc/get_video_session.sql
supabase db query --linked --file supabase/rpc/mark_video_session_live.sql
supabase db query --linked --file supabase/rpc/list_approval_requests.sql
supabase db query --linked --file supabase/rpc/list_compliance_alerts.sql
supabase db query --linked --file supabase/rpc/list_research_runs.sql
supabase db query --linked --file supabase/rpc/list_research_findings.sql
```

`end_video_session` is intentionally unchanged (creator/partner gate remains).
`create_video_session` and `start_research_run` keep their existing write gates;
`can_read_matter` mirrors their inline matter rule.

### 4. Edge functions

Set the new CORS allowlist first (comma-separated; no value in the repo):

```bash
supabase secrets set ALLOWED_ORIGINS="https://app.example.com,https://admin.example.com" \
  --project-ref <project-ref>
```

Deploy from the repo root (the CLI bundles `_shared/`; do not use the MCP deploy
tool for these):

```bash
supabase functions deploy research-analyze
supabase functions deploy video-token
supabase functions deploy paymob-reconcile
supabase functions deploy paymob-webhook
```

`paymob-webhook` also imports `verifyTransactionHmac` from `_shared/paymob.ts`, so
it must be redeployed for the case-sensitive comparison to take effect.
`paymob-initiate` does not use `constantTimeEqual` and is unaffected by this
change.

## Post-apply verification

### A. Helpers and grants

```sql
select p.proname,
       pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef,
       p.proconfig,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('can_read_matter', 'can_access_video_session');

-- Expect: prosecdef = t, proconfig contains search_path=public,
-- auth_exec = t, anon_exec = f.
```

### B. Policy predicates

```sql
select tablename, policyname, qual
  from pg_policies
 where schemaname = 'public'
   and tablename in ('video_sessions', 'approval_requests', 'approval_events',
                     'compliance_alerts', 'compliance_alert_events',
                     'research_runs', 'research_findings')
 order by tablename, policyname;
```

Expect `can_access_video_session(id)` on `video_sessions`, `can_read_matter(...)`
on the four parent policies, and parent-exists subqueries on both event tables.

### C. Behavioral probes (replace the placeholders with real ids)

```sql
-- Run as a normal authenticated caller (PostgREST/JWT, not the connection role).
select public.can_read_matter('<matter-id>', '<org-id>');
select public.can_access_video_session('<session-id>');

-- Unrelated active member: expects 0 rows, not an error.
select count(*) from public.video_sessions where id = '<session-id>';
select count(*) from public.list_video_sessions('<org-id>');
```

Repeat with a partner / creator / booking client / matter assignee JWT and
confirm the matching row is visible. For `video-token`, POST with a participant
token (expect 200 with a LiveKit token) and with an unrelated org member token
(expect 404 `session_not_found`; a policy error is 403 `forbidden`).

### D. `research-analyze` CORS and throttle

```bash
# Allowed origin: the response echoes the origin.
curl -i -X OPTIONS "$FUNCTION_URL" \
  -H "Origin: https://app.example.com" \
  -H "Access-Control-Request-Method: POST"

# Disallowed or unset origin: no Access-Control-Allow-Origin header.
curl -i -X OPTIONS "$FUNCTION_URL" \
  -H "Origin: https://evil.example" \
  -H "Access-Control-Request-Method: POST"

# Six authenticated calls inside one hour: the sixth is 429 {"error":"rate_limited"}.
```

### E. Paymob HMAC

Re-send a known-good Paymob test callback and confirm the signature verifies.
The comparison is now case-sensitive; Paymob’s documented HMAC is lowercase hex.
Confirm logs contain no `auth_token`, API key, or full inquiry URL.

## Rollback

Rollback is ordered: restore the old policies and RPCs **before** dropping the
helpers, because the old definitions do not reference them.

### 1. Restore the pre-27 policies

```sql
drop policy if exists video_sessions_select_org on public.video_sessions;
create policy video_sessions_select_org on public.video_sessions
  for select using (public.is_active_member(organization_id));

drop policy if exists approval_requests_select_org on public.approval_requests;
create policy approval_requests_select_org on public.approval_requests
  for select using (public.is_active_member(organization_id));

drop policy if exists approval_events_select_org on public.approval_events;
create policy approval_events_select_org on public.approval_events
  for select using (public.is_active_member(organization_id));

drop policy if exists compliance_alerts_select_org on public.compliance_alerts;
create policy compliance_alerts_select_org on public.compliance_alerts
  for select using (public.is_active_member(organization_id));

drop policy if exists compliance_alert_events_select_org on public.compliance_alert_events;
create policy compliance_alert_events_select_org on public.compliance_alert_events
  for select using (public.is_active_member(organization_id));

drop policy if exists research_runs_select_org on public.research_runs;
create policy research_runs_select_org on public.research_runs
  for select using (public.is_active_member(organization_id));

drop policy if exists research_findings_select_org on public.research_findings;
create policy research_findings_select_org on public.research_findings
  for select using (public.is_active_member(organization_id));
```

### 2. Restore the pre-27 RPC bodies

The old bodies are in git at the commit before this change. Restore each file
and re-apply it:

```bash
git show <pre-apply-sha>:supabase/rpc/list_video_sessions.sql > /tmp/list_video_sessions.sql
# ... repeat for get_video_session, mark_video_session_live,
#     list_approval_requests, list_compliance_alerts, list_research_runs,
#     list_research_findings
supabase db query --linked --file /tmp/list_video_sessions.sql
# ... repeat for each restored file
```

The old video RPCs gate on `is_active_member(v_row.organization_id)` (or the
equivalent), and the old list RPCs filter by organization only.

### 3. Drop the helpers

```bash
supabase db query --linked --file supabase/migrations/27_audit_remediation.down.sql
```

### 4. Revert the edge functions

Redeploy the pre-change `research-analyze`, `video-token`, `paymob-reconcile`
and `paymob-webhook` from the reverted tree (or `git revert` the function
commit and deploy again). Unset `ALLOWED_ORIGINS` if the deployment must return
to the previous CORS behavior.

## Test battery note (outside this change’s granted paths)

`scripts/verify_policy_tests.sh` hard-codes its `--apply` migration list and its
battery list. It must add `migrations/27_audit_remediation.sql` immediately after
`26_video_sessions.sql` before `policies/*.sql` are applied; otherwise the new
policies reference missing helpers and the rehearsal apply fails. That script was
**not modified** in this change (the brief restricted edits to `supabase/**` and
`docs/live_apply_*.md`). Batteries 23–26 were extended in place; their expected
counts, not their fixture UUIDs, changed to match the participant gates.
