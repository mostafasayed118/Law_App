-- 11_matter_write.down.sql — rollback for 11_matter_write.sql
-- (REVIEWED — rollback standby; not run on dev; rollback pairing per docs/rollback_plan.md).

begin;

drop trigger if exists matters_refuse_owner_assignment on public.matters;
drop function if exists public.refuse_platform_owner_assignment();

commit;
