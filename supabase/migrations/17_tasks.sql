-- 17_tasks.sql — task-board write-slice table (NOT APPLIED — rehearsal only)
-- Source of truth: task/approval-writes Gate 3 spec (2026-09-27 — approved
-- in-session): matter-scoped tasks with RPC-only writes following the
-- create_matter (F2) + send_message (D-SM) precedents.
--
-- The task board's first real table (read-only synthetic surface before):
-- org-scoped + matter-scoped rows carrying a title, a status, an optional
-- assignee, and an acknowledgement. Assignment-gated reads mirror the
-- messages policy exactly (is_active_member(org) AND assigned
-- client/attorney on the MATTER — tasks carry no assignment of their own
-- for reads; the matter row is the single assignment source of truth,
-- F-01). No INSERT/UPDATE/DELETE grant: every mutation goes through the
-- audited RPCs (supabase/rpc/create_task.sql + advance_task_status.sql +
-- assign_task.sql + acknowledge_task.sql) — the D-SM3 posture from day one,
-- so no insert-policy drop is ever needed.
-- Rollback: 17_tasks.down.sql (same directory).

begin;

-- 17.1 tasks — org-scoped, matter-scoped, status-carrying.
create table public.tasks (
  id                   uuid primary key default gen_random_uuid(),
  organization_id      uuid not null references public.organizations (id) on delete cascade,
  matter_id            uuid not null references public.matters (id) on delete cascade,
  title                text not null
    check (title <> ''),                  -- client TaskItem.title; CHECK = mapping contract — no empty title
  status               text not null default 'todo'
    check (status in ('todo', 'in_progress', 'blocked', 'done')),  -- client TaskStatus enum-name (in_progress <-> inProgress); CHECK = mapping contract
  assignee_id          uuid references auth.users (id) on delete set null,  -- matters assigned_* convention (F2-D4: must be an active member, enforced in-RPC)
  acknowledged_at      timestamptz,
  acknowledged_by      uuid references auth.users (id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- The read shapes: one matter's tasks in order (the board fetch + the task
-- battery both use (matter_id, created_at)) + the org-scoped list read.
create index tasks_matter_created on public.tasks (matter_id, created_at);
create index tasks_org on public.tasks (organization_id);
create index tasks_assignee
  on public.tasks (assignee_id) where assignee_id is not null;

-- RLS on (default deny: with no policy, all access is denied).
alter table public.tasks enable row level security;

-- Default-deny baseline: strip the hosting default grants (the 01 pattern).
revoke all on public.tasks from anon, authenticated;

-- Narrow direct SELECT grant (row-scoped reads only; mutations are
-- RPC-only and not part of this slice). Grants alone do nothing without
-- policies; the policy follows in policies/tasks.sql.
grant select on public.tasks to authenticated;

commit;
