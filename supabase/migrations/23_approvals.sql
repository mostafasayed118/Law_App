-- 23_approvals.sql — org-scoped approval requests (NOT APPLIED — rehearsal only)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §3
--                + docs/superpowers/plans/2026-10-22-approvals.md Tasks 1-3.
--
-- Replaces the synthetic approvals queue with a persisted request/decision
-- workflow. Two tables:
--   approval_requests — one row per request, org-scoped, optional matter link,
--                       lifecycle pending -> approved | rejected | cancelled;
--   approval_events   — append-only status trail (created/approved/rejected/
--                       cancelled), written by the RPCs in the same
--                       transaction as the state change.
--
-- The tables are default-deny: RLS on, all privileges revoked from anon +
-- authenticated, and exactly one narrow SELECT grant. The read policies live
-- in supabase/policies/approval_requests.sql + approval_events.sql; the four
-- audited RPCs live in supabase/rpc/*approval*.sql; the drops are mirrored in
-- supabase/rpc/_down.sql and 23_approvals.down.sql.
--
-- No org role named 'admin' exists (01_org_schema: client | attorney |
-- partner | compliance_officer). Decision authority is partner; the platform
-- owner holds no membership and is denied by every gate.
--
-- Rollback: 23_approvals.down.sql (same directory).

begin;

create table public.approval_requests (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  matter_id       uuid references public.matters (id) on delete set null,
  title           text not null check (length(trim(title)) between 2 and 160),
  description     text check (description is null or length(description) <= 4000),
  kind            text not null check (kind in ('conflict','waiver','filing','expense','other')),
  status          text not null default 'pending'
                    check (status in ('pending','approved','rejected','cancelled')),
  requested_by    uuid references auth.users (id) on delete set null,
  decided_by      uuid references auth.users (id) on delete set null,
  decided_at      timestamptz,
  decision_note   text check (decision_note is null or length(decision_note) <= 2000),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index approval_requests_org_status
  on public.approval_requests (organization_id, status, created_at desc);
create index approval_requests_matter
  on public.approval_requests (matter_id) where matter_id is not null;

create table public.approval_events (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid not null references public.approval_requests (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  action          text not null check (action in ('created','approved','rejected','cancelled')),
  actor_id        uuid references auth.users (id) on delete set null,
  note            text check (note is null or length(note) <= 2000),
  created_at      timestamptz not null default now()
);

create index approval_events_request
  on public.approval_events (request_id, created_at);

alter table public.approval_requests enable row level security;
alter table public.approval_events enable row level security;
revoke all on public.approval_requests from anon, authenticated;
revoke all on public.approval_events from anon, authenticated;
grant select on public.approval_requests to authenticated;
grant select on public.approval_events to authenticated;

commit;
