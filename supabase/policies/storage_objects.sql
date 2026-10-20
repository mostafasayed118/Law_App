-- policies/storage_objects.sql — storage objects read policy (REVIEWED & APPLIED — dev project, 2026-08-08)
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
--     or a non-uuid org segment) finds no matching assigned matter ->
--     denied for every role (matrix §6 row 1; Batch B: the org segment
--     is safe-cast via CASE so a non-uuid yields NULL -> deny, never
--     a 22P02 abort).
-- Path segments compare as canonical lowercase hyphenated uuid::text
-- (review §5 pin). is_active_member is public-schema + EXECUTE-granted to
-- authenticated (R-4); storage policy expressions may call public.*
-- functions + auth.uid() — PROVEN live by the T3/T4 battery, not assumed.
-- Write half (matter-files write slice): files_storage_insert gates the
-- bytes upload with the SAME predicate as the read gate (WITH CHECK), and
-- files_storage_delete gates byte removal with the SAME predicate (USING).
-- No UPDATE policy exists — objects are immutable in this slice; replacing a
-- file is a delete + upload. The public.files metadata row is never written
-- directly (no grant/policy); register_matter_file / delete_matter_file are
-- the RPC-only metadata paths. The bucket stays private (public = false), so
-- anon has no read or write path.

create policy files_storage_select on storage.objects
  for select
  using (
    bucket_id = 'matter-files'
    -- Batch B safe-cast: a non-uuid org segment used to raise 22P02 and
    -- abort the query; the CASE guard yields NULL instead so
    -- is_active_member(NULL) = false -> deny (matrix §6 row 1 holds).
    and public.is_active_member(
      case when (storage.foldername(name))[1] ~
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
        then (storage.foldername(name))[1]::uuid
        else null end
    )
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

-- INSERT: the upload gate — the exact SELECT predicate re-used as WITH CHECK.
-- A writer can only create an object under an org/matter path it can read:
-- active membership in the path org, the path org equal to the matter's
-- authoritative org, and an assignment on that matter. The safe-cast guard
-- keeps a non-uuid org segment a deny (NULL -> false), never a 22P02 abort.
create policy files_storage_insert on storage.objects
  for insert
  with check (
    bucket_id = 'matter-files'
    and public.is_active_member(
      case when (storage.foldername(name))[1] ~
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
        then (storage.foldername(name))[1]::uuid
        else null end
    )
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

-- DELETE: the cleanup gate — the exact SELECT predicate re-used as USING.
-- The metadata row is removed by delete_matter_file first; the storage API
-- then removes bytes through this policy. No UPDATE policy.
create policy files_storage_delete on storage.objects
  for delete
  using (
    bucket_id = 'matter-files'
    and public.is_active_member(
      case when (storage.foldername(name))[1] ~
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
        then (storage.foldername(name))[1]::uuid
        else null end
    )
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
