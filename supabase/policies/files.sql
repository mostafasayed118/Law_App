-- policies/files.sql — files metadata read policy (REVIEWED & APPLIED — dev project, 2026-08-08)
-- Source of truth: docs/storage_real_data_plan_2026-08-08.md (D-STR1/D-STR2)
--                + docs/storage_rls_gate_review_2026-08-08.md (§4 deny-rows).
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: a files METADATA row is readable iff the reader is an ACTIVE
-- MEMBER of the file's organization AND is assigned (client or attorney)
-- on the file's MATTER. This enforces the matrix §4 contract exactly
-- (files are matter content — line 143/148; the §6 storage rows), the
-- documents/messages select_assigned pattern applied to public.files:
--   - "org role alone (no matter assignment)" -> deny, every role (the
--     exists subquery finds no assignment match);
--   - cross-org denied (is_active_member tests the file's org, and the
--     exists requires the matter's org to MATCH the file's org);
--   - suspended/removed memberships never authorize (is_active_member is
--     the status = 'active' rule, 02_rls_functions);
--   - platform_owner_admin denied, always (owner accounts are never
--     assigned; no carve-out exists, Q4).
-- The matter gate is a plain exists subquery on the APPLIED matters table
-- (D-STR2, the documents D-DR2 pattern): the assignment columns live on
-- the matters row itself, so the exists yields the matter gate regardless
-- of whether matters RLS re-applies inside the policy (defense-in-depth
-- either way). The m.organization_id = files.organization_id clause is
-- load-bearing: the org gate comes from the matter's AUTHORITATIVE org,
-- never the file's denormalized column, so a file is never readable when
-- its matter is not (matrix line 148; the org-mismatch battery row pins
-- it). No new function surface — is_active_member is already
-- EXECUTE-granted to authenticated (R-4 grants in 02_rls_functions.sql).
-- No INSERT/UPDATE/DELETE policy: this slice is read-only (Q5); no
-- content/body/url column exists (D-STR3 — bytes live in storage.objects,
-- gated by policies/storage_objects.sql).

create policy files_select_assigned on public.files
  for select
  using (
    public.is_active_member(organization_id)
    and exists (
      select 1
      from public.matters m
      where m.id = files.matter_id
        and m.organization_id = files.organization_id
        and (
          m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid()
        )
    )
  );
