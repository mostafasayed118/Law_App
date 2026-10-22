-- 26_video_sessions.down.sql — backout for 26_video_sessions.sql (NOT APPLIED — standby)
-- Clean inverse: drop the slice's RPCs first (so no definer function is left
-- pointing at a missing table), then the table. Indexes, inline CHECKs, and
-- the read policy die with the table. The consolidated rpc/_down.sql drop
-- list is maintained separately; the drops here are idempotent, so running
-- both orders is safe.

begin;

drop function if exists public.create_video_session(uuid, uuid, uuid, timestamptz);
drop function if exists public.list_video_sessions(uuid);
drop function if exists public.get_video_session(uuid);
drop function if exists public.mark_video_session_live(uuid);
drop function if exists public.end_video_session(uuid);

drop table if exists public.video_sessions;

commit;
