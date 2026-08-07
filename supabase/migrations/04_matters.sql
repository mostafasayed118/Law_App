-- 04_matters.sql — matters read-path migration (REHEARSAL-READY — NOT applied, 2026-08-07)
-- Source of truth: docs/matters_real_data_plan_2026-08-07.md (D-MR1/D-MR3)
--                + docs/matters_rls_gate_review_2026-08-07.md (Q1-Q6).
-- Rollback: 04_matters.down.sql (same directory).
--
-- The first roadmap §14 un-deferral: a real, org-scoped, ASSIGNMENT-gated
-- matters table (read path only). RLS grants a row iff the reader is an
-- active member of the matter's organization AND is the assigned client or
-- assigned attorney (matrix §4 — an org role alone never grants matter
-- access). No INSERT/UPDATE/DELETE grant (Q5): mutations are a future
-- reviewed slice.

begin;

-- 4.8 matter lifecycle status — matches the client MatterStatus enum set
-- (lib/features/matters/domain/matter.dart: open | active | closed).
create type public.matter_status as enum ('open', 'active', 'closed');

-- 4.9 matters — org-scoped, assignment-gated (D-MR1/D-MR3)
create table public.matters (
  id                   uuid primary key default gen_random_uuid(),
  organization_id      uuid not null references public.organizations (id) on delete cascade,
  title                text not null,       -- generic demo/real title; never PII by convention (D-M4)
  practice_area        text not null,       -- client PracticeArea enum-name: corporate|civil|criminal|family (D-MR3)
  status               public.matter_status not null default 'open',
  assigned_client_id   uuid references auth.users (id) on delete set null,
  assigned_attorney_id uuid references auth.users (id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- The two RLS lookup shapes (assigned client / assigned attorney) + the
-- org-scoped list read.
create index matters_org_status
  on public.matters (organization_id, status);
create index matters_assigned_client
  on public.matters (assigned_client_id) where assigned_client_id is not null;
create index matters_assigned_attorney
  on public.matters (assigned_attorney_id) where assigned_attorney_id is not null;

-- RLS on (default deny: with no policy, all access is denied).
alter table public.matters enable row level security;

-- Default-deny baseline: strip the hosting default grants (the 01 pattern).
revoke all on public.matters from anon, authenticated;

-- Narrow direct SELECT grant per Q5 (row-scoped reads only; mutations are
-- RPC-only and not part of this slice). Grants alone do nothing without
-- policies; the policy follows in policies/matters.sql.
grant select on public.matters to authenticated;

commit;
