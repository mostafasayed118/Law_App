-- 15_notification_producer.down.sql — rollback for 15_notification_producer.sql
-- (DRAFT — rollback standby; not run on dev; rollback pairing per docs/rollback_plan.md).

begin;

drop trigger if exists audit_events_mirror_notifications on public.audit_events;
drop function if exists public.mirror_audit_to_notifications();

commit;
