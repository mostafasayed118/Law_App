-- policies/video_sessions.sql — participant-scoped video-session read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §6
--                + docs/superpowers/plans/2026-10-22-video.md Task 2
--                + docs/live_apply_2026-10-24_audit_remediation.md
-- Backout: restore the pre-27 org-member predicate (see the live-apply doc).
--
-- SELECT: a video_sessions row is readable iff public.can_access_video_session
-- returns true for it: the reader holds an ACTIVE membership in the row's
-- organization AND is a partner of that org, the session creator, a reader of
-- the linked matter (assigned client/attorney, creator, or partner), or the
-- client on the linked booking. An unrelated active member no longer sees the
-- row, so the video-token Edge Function (which reads under the caller's JWT)
-- cannot mint a token for a session the caller is not a participant in.
--
-- The list/get/live RPCs re-assert the same gate server-side. SECURITY DEFINER
-- in can_access_video_session prevents the policy from re-entering itself
-- (video_sessions is not FORCE ROW LEVEL SECURITY).
--
-- No INSERT/UPDATE/DELETE policy: mutations are RPC-only from day one
-- (spec §1 principle 1). Session creation stays partner/attorney-gated inside
-- create_video_session.

drop policy if exists video_sessions_select_org on public.video_sessions;

create policy video_sessions_select_org on public.video_sessions
  for select using (public.can_access_video_session(id));
