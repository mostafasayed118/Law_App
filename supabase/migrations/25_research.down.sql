-- 25_research.down.sql — backout for 25_research.sql (NOT APPLIED — standby)
-- Clean inverse: drop the slice's RPCs first (so no definer function is left
-- pointing at a missing table), then the findings table (FK child) and the
-- runs table. Indexes, inline CHECKs, and read policies die with their
-- tables. The consolidated rpc/_down.sql drop list is maintained separately;
-- the drops here are idempotent, so running both orders is safe.

begin;

drop function if exists public.start_research_run(uuid, uuid, text);
drop function if exists public.complete_research_run(uuid, text, text, text, jsonb);
drop function if exists public.list_research_runs(uuid);
drop function if exists public.list_research_findings(uuid);

drop table if exists public.research_findings;
drop table if exists public.research_runs;

commit;
