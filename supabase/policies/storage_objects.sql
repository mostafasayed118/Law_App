-- policies/storage_objects.sql — storage objects read policy (REHEARSAL-READY — NOT applied, 2026-08-08)
-- Source of truth: docs/storage_real_data_plan_2026-08-08.md (D-STR2/D-STR4)
--                + docs/storage_rls_gate_review_2026-08-08.md (§3 Q2/Q4, §4 deny-rows).
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: an object in the private `matter-files` bucket is readable iff
-- the reader is an ACTIVE MEMBER of the object's org (path segment 1) AND
-- is assigned (client or attorney) on the MATTER named by path segment 2.
-- The object path encodes `{org_id}/{matter_id}/{filename}` (D-STR4) and
-- the policy derives the gate from the segments via storage.foldername:
--   - the ACTIVE-MEMBERSHIP ARM IS LOAD-BEARING on this layer exactly as
--     on public.files (the plan reviewer fold bad9641): a suspended-but-
--     still-assigned user must be denied on storage.objects too — the
--     fixture matter 6 (assigned attorney = suspended-a) pins it;
--   - org-role-alone / cross-org / unassigned / platform_owner_admin deny
--     exactly as files_select_assigned (Q4: no owner carve-out);
--   - the path-org segment must equal the matter's AUTHORITATIVE org
--     (m.organization_id::text = segment 1) — the org-mismatch invariant,
--     path-encoded, so an object is never readable when its matter is not;
--   - a GUESSED PATH (unknown/foreign matter id, mismatched org segment,
--     or a non-uuid org segment whose ::uuid cast fails) finds no matching
--     assigned matter -> denied for every role (matrix §6 row 1).
-- Path segments compare as canonical lowercase hyphenated uuid::text
-- (review §5 pin). is_active_member is public-schema + EXECUTE-granted to
-- authenticated (R-4); storage policy expressions may call public.*
-- functions + auth.uid() — PROVEN live by the T3/T4 battery, not assumed.
-- No INSERT/UPDATE/DELETE policy: this slice is read-only (Q5); the bucket
-- is private (public = false) so anon has no public read path.

create policy files_storage_select on storage.objects
  for select
  using (
    bucket_id = 'matter-files'
    and public.is_active_member((storage.foldername(name))[1]::uuid)
    and exists (
      select 1
      from public.matters m
      where m.id::text = (storage.foldername(name))[2]
        and m.organization_id::text = (storage.foldername(name))[1]
        and (
          m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid()
        )
    )
  );
