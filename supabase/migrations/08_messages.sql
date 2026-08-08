-- 08_messages.sql — realtime read-path migration (REHEARSAL-READY — NOT applied, 2026-08-08)
-- Source of truth: docs/realtime_real_data_plan_2026-08-08.md (D-RT1/D-RT3)
--                + docs/realtime_rls_gate_review_2026-08-08.md (Q1-Q6).
-- Rollback: 08_messages.down.sql (same directory).
--
-- The sixth roadmap §14 un-deferral: a real, org-scoped, THREAD-scoped
-- individual-message table (read path only — the matrix §4 "Read a
-- document/message body" row's first client surface, line 143). RLS grants
-- a row iff the reader is an active member of the message's organization
-- AND is assigned (client or attorney) on the message's THREAD's matter
-- (the thread gate extended one hop — D-RT2). Requires the APPLIED
-- message_threads table (06_message_threads.sql) as FK target + the APPLIED
-- matters table (04_matters.sql) as the assignment source of truth (the
-- documents/messages exists-subquery pattern). This migration ships the
-- FIRST CONTENT COLUMN in the public schema (body) — the deliberate, scoped
-- D-MSG1 consummation (Q5): read path only, no write grant, the shipped
-- MessageThread VO and messaging list stay body-less. Author is a stored
-- display name (D-RT4) — generic demo names by convention, no author_user_id
-- column (identity binding is the future write slice's job via the matters
-- D-MR4 roster seam). No INSERT/UPDATE/DELETE grant (Q5): mutations and
-- live delivery (postgres_changes push, D-RT6) are future reviewed slices.

begin;

-- 8.1 messages — org-scoped, thread-scoped, body-carrying (D-RT1/D-RT3)
create table public.messages (
  id                   uuid primary key default gen_random_uuid(),
  organization_id      uuid not null references public.organizations (id) on delete cascade,
  thread_id            uuid not null references public.message_threads (id) on delete cascade,
  author_display_name  text not null,    -- stored display name (D-RT4); generic demo names, never PII by convention
  body                 text not null
    check (body <> ''),                  -- client Message.body (D-RT3); CHECK = mapping contract — no empty body
  sent_at              timestamptz not null default now(),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- The read shape: one thread's messages in order (the thread-detail fetch
-- + the messages battery both use (thread_id, sent_at)).
create index messages_thread_sent on public.messages (thread_id, sent_at);
create index messages_org on public.messages (organization_id);

-- RLS on (default deny: with no policy, all access is denied).
alter table public.messages enable row level security;

-- Default-deny baseline: strip the hosting default grants (the 01 pattern).
revoke all on public.messages from anon, authenticated;

-- Narrow direct SELECT grant per Q5 (row-scoped reads only; mutations are
-- RPC-only and not part of this slice). Grants alone do nothing without
-- policies; the policy follows in policies/messages.sql.
grant select on public.messages to authenticated;

commit;
