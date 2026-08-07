-- 06_message_threads.sql — messages read-path migration (REHEARSAL-READY — NOT applied, 2026-08-07)
-- Source of truth: docs/messages_real_data_plan_2026-08-07.md (D-MSR1/D-MSR3)
--                + docs/messages_rls_gate_review_2026-08-07.md (Q1-Q6).
-- Rollback: 06_message_threads.down.sql (same directory).
--
-- The third roadmap §14 un-deferral: a real, org-scoped, MATTER-scoped
-- message-thread table (read path only, METADATA only — no body/preview/
-- attachment/sender columns, D-MSG1). RLS grants a row iff the reader is an
-- active member of the thread's organization AND is assigned (client or
-- attorney) on the thread's matter (matrix §4 — messages are matter
-- content; an org role alone never grants message access). Requires the
-- APPLIED matters table (04_matters.sql) as its FK target + assignment
-- source of truth (the documents 05 pattern). Participants are generic demo
-- display names (text[], D-MSR3/D-MSG4) — never an identity/availability
-- claim, no real PII by convention. No INSERT/UPDATE/DELETE grant (Q5):
-- mutations and bodies are future reviewed slices.

begin;

-- 6.1 message_threads — org-scoped, matter-scoped, metadata-only (D-MSR1/D-MSR3)
create table public.message_threads (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  matter_id        uuid not null references public.matters (id) on delete cascade,
  title            text not null,       -- generic demo/real title; never PII by convention (D-MSG4)
  participants     text[] not null default '{}',  -- generic demo display names (D-MSR3); never an identity claim
  last_activity_at timestamptz not null default now(),
  message_count    integer not null default 0
    check (message_count >= 0),         -- client MessageThread.messageCount (D-MSR3); CHECK = mapping contract
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- The two read shapes: the org-scoped list read + the per-matter lookup
-- (the FK join and the threads battery both use matter_id).
create index message_threads_org on public.message_threads (organization_id);
create index message_threads_matter on public.message_threads (matter_id);

-- RLS on (default deny: with no policy, all access is denied).
alter table public.message_threads enable row level security;

-- Default-deny baseline: strip the hosting default grants (the 01 pattern).
revoke all on public.message_threads from anon, authenticated;

-- Narrow direct SELECT grant per Q5 (row-scoped reads only; mutations are
-- RPC-only and not part of this slice). Grants alone do nothing without
-- policies; the policy follows in policies/message_threads.sql.
grant select on public.message_threads to authenticated;

commit;
