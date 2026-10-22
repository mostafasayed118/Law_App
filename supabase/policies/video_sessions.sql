-- policies/video_sessions.sql — video-session read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §6
--                + docs/superpowers/plans/2026-10-22-video.md Task 2.
-- Backout: git revert of this policy commit; the table drop in
-- migrations/26_video_sessions.down.sql removes it with the table.
--
-- SELECT: a video_sessions row is readable iff the reader holds an ACTIVE
-- membership in the row's organization. The list/get RPCs re-assert the same
-- gate server-side, and the video-token Edge Function reads under the caller's
-- JWT so this policy is the authorization boundary for token minting.
--
-- No INSERT/UPDATE/DELETE policy: mutations are RPC-only from day one
-- (spec §1 principle 1). Session creation stays partner/attorney-gated inside
-- create_video_session; the read policy itself has no role carve-out.

create policy video_sessions_select_org on public.video_sessions
  for select using (public.is_active_member(organization_id));
