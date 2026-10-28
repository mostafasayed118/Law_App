-- 21_matter_creator.down.sql — DESTRUCTIVE inverse of 21 (NOT APPLIED)
--
-- 21 added matters.created_by plus the partial index matters_created_by.
-- This down drops both: creator attribution is permanently lost. The up did
-- not backfill (pre-21 rows were NULL), so only creators recorded after 21
-- lose their attribution.
--
-- PREREQUISITE — restore the read policy and create_matter first. The creator
-- arm in supabase/policies/matters.sql references created_by, so PostgreSQL
-- refuses the column drop while that policy exists. The up file's own backout
-- note gives the order: restore the pre-21 policy / RPC body, then drop the
-- column, then re-create the pre-21 policy. Reverting the RPC is required for
-- a clean forward rebuild, not for the drop itself.
--
-- No separate index drop is needed once the column is gone, but the explicit
-- drop keeps this file a literal inverse when run before the column.

begin;

drop index if exists public.matters_created_by;
alter table public.matters drop column if exists created_by;

commit;
