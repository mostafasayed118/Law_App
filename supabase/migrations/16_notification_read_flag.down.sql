-- 16_notification_read_flag.down.sql — rollback pairing for
-- 16_notification_read_flag.sql (the rollback-pairing contract, plan §4).
-- Drops the D-N6 read-flag write function; the blanket revoke below covers
-- the authenticated EXECUTE grant so no orphaned grant survives the drop.

begin;

revoke execute on function public.mark_notifications_read(uuid[]) from authenticated, anon, public;
drop function if exists public.mark_notifications_read(uuid[]);

commit;
