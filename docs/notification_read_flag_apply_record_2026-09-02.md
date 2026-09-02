# Apply Record: Notification Read-Flag Write Slice (migration 16) — 2026-09-02

> **Record type:** The dated apply-approval + runbook + execution record for
> `supabase/migrations/16_notification_read_flag.sql` (the D-N6 write RPC;
> plan `docs/notification_read_flag_slice_plan_2026-09-02.md`, D-F1…D-F7).
> **Approval:** the owner approved the remaining project work dated
> 2026-09-02 ("أعمل push وانا موافق علي كل حاجه") — this record documents
> the execution.
>
> **Status: PENDING OWNER-RUN APPLY** — the opencode session's linked CLI
> session could not reach the Management API (403 on the login role; the
> session account is not a member of the law_project org), so the owner
> executes the runbook below **on the owner's machine** and pastes the
> per-step outputs into §4 (or re-invokes the coding agent to complete it).
> The client swap shipped env-gated (`10e45af`); env-less runs and tests
> keep the fake, so nothing client-side is blocked on this apply.

---

## 1. What is applied

`16_notification_read_flag.sql` — the `mark_notifications_read(uuid[])`
function: security definer + in-function `is_active_member` gate (the sole
write authorization), own-org still-unread rows only, idempotent, one
redacted `notification:mark_read` audit row per distinct org touched
(outside the producer's D-P2 map — no feed row re-produced), EXECUTE
revoked from `public`/`anon` + granted to `authenticated` (RPC-EXECUTE pin
20 → 21). **No table grant, no new policy** — applied counts stay
13 tables / 13 RLS / 12 public policies.

## 2. Runbook (the owner executes, per-step)

```bash
# from the repo root, with the CLI logged in to the law_project account

# Step 1 — pre-apply probe (expect 0: the function must not exist yet)
supabase db query --linked "select count(*) from information_schema.routines where routine_schema='public' and routine_name='mark_notifications_read'"

# Step 2 — apply the single migration
supabase db query --linked --file supabase/migrations/16_notification_read_flag.sql

# Step 3 — post-apply structural checks
#   3a. the function exists (expect 1 row: mark_notifications_read)
supabase db query --linked "select routine_name from information_schema.routines where routine_schema='public' and routine_name='mark_notifications_read'"
#   3b. zero client write grants on the table (expect 0)
supabase db query --linked "select count(*) from information_schema.role_table_grants where table_schema='public' and table_name='notifications' and privilege_type in ('INSERT','UPDATE','DELETE') and grantee in ('anon','authenticated')"
#   3c. the EXECUTE shape (expect f,t — anon false, authenticated true)
supabase db query --linked "select has_function_privilege('anon','public.mark_notifications_read(uuid[])','EXECUTE') as anon, has_function_privilege('authenticated','public.mark_notifications_read(uuid[])','EXECUTE') as authenticated"

# Step 4 — live smoke: battery 16 IS the smoke (delta-based, every block
# rolls back — zero residue by construction)
supabase db query --linked --file supabase/tests/16_notification_read_flag.sql
# expect: the file runs to completion with ON_ERROR_STOP and NO
# 'POLICY-BATTERY FAIL' line (each CHECK's rollback leaves no residue)
```

## 3. Expected post-apply state

- function `public.mark_notifications_read(uuid[])` live; EXECUTE:
  authenticated ✓, anon ✗;
- zero INSERT/UPDATE/DELETE grants for anon/authenticated on
  `notifications`;
- applied counts unchanged: 13 tables / 13 RLS / 12 public policies /
  RPC-EXECUTE **21**;
- battery 16 green on the dev project (same file the rehearsal harness
  runs — `scripts/verify_policy_tests.sh` lists it as battery 16).

## 4. Execution log (filled by the owner run)

| Step | Command outcome | Notes |
|---|---|---|
| 1 probe | ☐ | |
| 2 apply | ☐ | |
| 3a routine | ☐ | |
| 3b grants | ☐ | |
| 3c EXECUTE | ☐ | |
| 4 battery 16 | ☐ | |

## 5. Ledger

- APPROVED 2026-09-02 (owner, session record); runbook recorded in this
  file; execution PENDING the owner run. After the run: check the boxes in
  §4 (or have the coding agent do it) — the plan's T5/T6 then close and
  the client surface is fully live on configured builds.
