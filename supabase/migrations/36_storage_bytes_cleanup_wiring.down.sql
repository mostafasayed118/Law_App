-- Backout for 36_storage_bytes_cleanup_wiring.sql (file only).
begin;

do $$
begin
  begin
    perform extensions.cron.unschedule('storage-bytes-cleanup');
  exception when others then
    null;
  end;
end $$;

drop function if exists public.enqueue_deleted_user_storage_cleanup();
drop function if exists public.deleted_users_with_orphan_storage();

commit;
