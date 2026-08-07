-- 04_matters.down.sql — backout for 04_matters.sql (REHEARSAL-READY — not run on dev)
-- Clean inverse: drop the table, then the type it depends on.

begin;

drop table if exists public.matters;
drop type if exists public.matter_status;

commit;
