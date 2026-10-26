-- 28_audit_indexes_and_list_bounds.sql — audit read-path indexes (NOT APPLIED)
-- Source of truth: docs/live_apply_2026-10-24_list_bounds.md
--
-- audit_events had no secondary index (only the identity primary key), while
-- read_org_audit filters by organization_id and orders by server_timestamp
-- desc, and read_platform_audit orders the whole table by server_timestamp
-- desc. These two indexes serve those exact shapes.
--
-- Additive and idempotent. Rollback (only if the indexes prove unwanted):
--   drop index if exists public.audit_events_org_ts;
--   drop index if exists public.audit_events_ts;
-- No down migration is added: non-unique indexes are safe to leave in place.

begin;

create index if not exists audit_events_org_ts
  on public.audit_events (organization_id, server_timestamp desc);

create index if not exists audit_events_ts
  on public.audit_events (server_timestamp desc);

commit;
