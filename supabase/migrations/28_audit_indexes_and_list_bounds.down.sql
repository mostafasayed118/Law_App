-- 28_audit_indexes_and_list_bounds.down.sql — explicit inverse of 28
-- (NOT APPLIED).
--
-- 28's own header said no down was added because non-unique indexes are safe
-- to leave in place; this file is the explicit inverse required by the
-- 2026-10-26 audit follow-up, so every index migration in the set has one. It
-- drops exactly the two indexes 28 creates; no data change.

begin;

drop index if exists public.audit_events_org_ts;
drop index if exists public.audit_events_ts;

commit;
