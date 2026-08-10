-- 09_realtime_push.down.sql — backout for 09_realtime_push.sql (REVIEWED — rollback standby; not run on dev)
-- Clean inverse: drop the messages membership from the supabase_realtime
-- publication. Idempotent guard: ALTER PUBLICATION ... DROP TABLE has no
-- IF EXISTS form, so the check runs first (the messages table stays —
-- this down only removes the live-delivery enablement, never the table
-- or its RLS; the INSERT policy backout is the git-revert of its commit).

begin;

do $$
begin
  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime drop table messages;
  end if;
end $$;

commit;
