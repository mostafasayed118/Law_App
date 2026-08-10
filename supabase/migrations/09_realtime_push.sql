-- 09_realtime_push.sql — live-delivery publication migration (REVIEWED & APPLIED — dev project, 2026-08-08)
-- Source of truth: docs/realtime_push_real_data_plan_2026-08-08.md (D-LV2)
--                + docs/realtime_push_gate_review_2026-08-08.md (Q1, §5).
-- Rollback: 09_realtime_push.down.sql (same directory).
--
-- The seventh roadmap §14 un-deferral: the D-RT6 recorded follow-up —
-- live delivery of messages rows via postgres_changes. This migration
-- ships the ENABLEMENT layer ONLY: publication membership (exactly the
-- messages table, nothing else). The AUTHORIZATION layer is Realtime RLS:
-- postgres_changes adheres to the underlying table's SELECT policy, so
-- the existing messages_select_assigned (08) IS the delivery gate — no
-- new authorization surface (D-LV3). The event source is the minimal
-- insert-only send path (messages_insert_assigned, policies/messages_insert.sql
-- — D-LV1); the client subscription lifecycle (channel + filter +
-- reconnect + backfill) is the env-gated client slice (D-LV4, plan T7).
-- No new table, no new columns, no RLS change.

begin;

-- The supabase_realtime publication exists by default on Supabase
-- projects (local + hosted); CREATE PUBLICATION has no IF NOT EXISTS
-- form, so the guard is a do-block (verified live on the rehearsal host
-- 2026-08-08 — the first draft's bare guard was a syntax error the
-- rehearsal caught). Membership below is exactly messages, nothing else —
-- the harness forward pin asserts pg_publication_tables = 1 for messages
-- (D-LV5), so adding any other table would trip the pin loudly.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

-- Enable postgres_changes delivery for the messages table. Delivery is
-- then gated by Realtime RLS (the existing messages_select_assigned
-- SELECT policy, 08) — publication membership is enablement only.
alter publication supabase_realtime add table messages;

commit;
