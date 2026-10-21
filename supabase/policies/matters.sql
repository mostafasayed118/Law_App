-- policies/matters.sql — matters read policy (REVIEWED & APPLIED — dev project,
-- 2026-08-07; creator carve-out added 2026-10-21 — owner ruling D1)
-- Source of truth: docs/matters_real_data_plan_2026-08-07.md (D-MR1)
--                + docs/matters_rls_gate_review_2026-08-07.md (§4 deny-rows)
--                + the owner ruling D1 (2026-10-21) on device finding F4
--                  (docs/device_e2e_2026-10-21_c835ced.md).
-- Backout: git revert of this policy commit (rollback_plan.md design §7); the
-- ruling-specific backout is in migrations/21_matter_creator.sql (policy →
-- RPC → column, in that order).
--
-- SELECT: a matter row is readable iff the reader is an ACTIVE MEMBER of the
-- matter's organization AND is the assigned client, the assigned attorney, or
-- THE MATTER'S CREATOR.
--
-- The creator arm is the OWNER'S RULING D1 (2026-10-21). Before it, the read
-- gate was assignment-only, so a partner who created a matter WITHOUT
-- assigning anyone received a row they could never read back (device finding
-- F4: matter a457cf53… invisible to its own creator; the same matter with the
-- client assigned WAS visible). D1 rules that the creator of a matter must
-- always be able to read it. The earlier review note on this file ("no
-- carve-out exists, Q4") is RELAXED for exactly this case: the creator
-- carve-out now exists. It is the ONLY arm beyond assignment, and it is
-- derived — created_by = auth.uid(), stamped by the create_matter RPC — so
-- a caller cannot claim authorship of someone else's matter.
--
-- The matrix §4 contract still holds everywhere else:
--   - "org role alone (no matter assignment)"  -> deny, every role (no
--     assignment match AND no creator match -> false);
--   - cross-org denied (membership is tested against THIS org, via
--     is_active_member(organization_id));
--   - suspended/removed memberships never authorize (is_active_member is
--     the status = 'active' rule, 02_rls_functions) — a SUSPENDED creator
--     is denied too, because the membership conjunct still has to hold;
--   - platform_owner_admin denied, always. The carve-out does not reach the
--     owner: it holds no membership (so is_active_member is false), and it can
--     never create a matter either (F2-D1 admits only an active PARTNER of
--     the org), so created_by can never hold the owner id.
--
-- Uses the existing self-scoped is_active_member() helper — already
-- EXECUTE-granted to authenticated (R-4 grants in 02_rls_functions.sql), so
-- no new function grant is introduced.
-- No INSERT/UPDATE/DELETE policy: this slice is read-only (Q5).

-- The policy is REPLACED, not added (the policy COUNT pin stays at fifteen),
-- so the pre-ruling body is dropped first — a no-op on a fresh rehearsal
-- project, required on the live project where the policy already exists.
drop policy if exists matters_select_assigned on public.matters;

create policy matters_select_assigned on public.matters
  for select
  using (
    public.is_active_member(organization_id)
    and (assigned_client_id = auth.uid()
         or assigned_attorney_id = auth.uid()
         or created_by = auth.uid())
  );
