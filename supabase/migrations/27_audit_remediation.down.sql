-- 27_audit_remediation.down.sql — rollback for the participant read helpers.
-- Run ONLY after the pre-27 policies and RPCs are restored: they reference
-- public.can_read_matter / public.can_access_video_session.

begin;

revoke execute on function public.can_access_video_session(uuid) from authenticated;
revoke execute on function public.can_read_matter(uuid, uuid) from authenticated;

drop function if exists public.can_access_video_session(uuid);
drop function if exists public.can_read_matter(uuid, uuid);

commit;
