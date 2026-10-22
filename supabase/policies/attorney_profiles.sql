-- policies/attorney_profiles.sql — attorney-directory read policy (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §2
--                + docs/superpowers/plans/2026-10-22-discovery.md Task 2.
-- Backout: git revert of this policy commit; the table drop in
-- migrations/22_attorney_directory.down.sql removes it with the table.
--
-- SELECT: an attorney_profiles row is readable iff it is ACTIVE and the reader
-- holds an ACTIVE membership in ANY organization. The directory is platform-
-- level (not org-scoped) by design: every active member of every org sees the
-- same active professionals, and battery 22.12 pins the cross-org read.
--
-- The policy never exposes an inactive row and never exposes the table to
-- anon. Platform-owner listing (including inactive rows) is RPC-only through
-- list_attorney_profiles — this policy deliberately has no owner carve-out,
-- because the owner holds no membership and reads the full list through the
-- definer RPC gate instead.
--
-- Uses the existing is_active_member() shape inline (one EXISTS over
-- memberships) rather than the org-scoped helper: the directory has no
-- organization_id column, so there is no single org to test. No new function
-- grant is introduced.
-- No INSERT/UPDATE/DELETE policy: mutations are RPC-only from day one.

create policy attorney_profiles_select_active on public.attorney_profiles
  for select
  using (
    status = 'active'
    and exists (
      select 1 from public.memberships m
       where m.user_id = auth.uid()
         and m.status = 'active'
    )
  );
