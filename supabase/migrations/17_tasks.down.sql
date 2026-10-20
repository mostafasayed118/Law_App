-- 17_tasks.down.sql — clean inverse of 17_tasks.sql (rehearsal-only slice).
-- Drops the table; the inline title/status CHECKs + indexes die with it.
-- The tasks_select_assigned policy dies with the table. RPC + battery
-- backout: rpc/_down.sql + git revert of the policy/test commits
-- (rollback_plan.md design §7).

begin;

drop table if exists public.tasks;

commit;
