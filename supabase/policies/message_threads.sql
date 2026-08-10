-- policies/message_threads.sql — messages read policy (REVIEWED & APPLIED — dev project, 2026-08-07)
-- Source of truth: docs/messages_real_data_plan_2026-08-07.md (D-MSR1/D-MSR2)
--                + docs/messages_rls_gate_review_2026-08-07.md (§4 deny-rows).
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: a message-thread row is readable iff the reader is an ACTIVE
-- MEMBER of the thread's organization AND is assigned (client or attorney)
-- on the thread's MATTER. This enforces the matrix §4 contract exactly
-- (messages are matter content — line 143/148), the documents
-- documents_select_assigned pattern applied to message_threads:
--   - "org role alone (no matter assignment)" -> deny, every role (the
--     exists subquery finds no assignment match);
--   - cross-org denied (is_active_member tests the thread's org, and the
--     exists requires the matter's org to MATCH the thread's org);
--   - suspended/removed memberships never authorize (is_active_member is
--     the status = 'active' rule, 02_rls_functions);
--   - platform_owner_admin denied, always (owner accounts are never
--     assigned; no carve-out exists, Q4).
-- The matter gate is a plain exists subquery on the APPLIED matters table
-- (D-MSR2, the documents D-DR2 pattern): the assignment columns live on the
-- matters row itself, so the exists yields the matter gate regardless of
-- whether matters RLS re-applies inside the policy (defense-in-depth either
-- way). The m.organization_id = message_threads.organization_id clause is
-- load-bearing: the org gate comes from the matter's AUTHORITATIVE org,
-- never the thread's denormalized column, so a thread is never readable
-- when its matter is not (matrix line 148; the org-mismatch battery row
-- pins it). No new function surface — is_active_member is already
-- EXECUTE-granted to authenticated (R-4 grants in 02_rls_functions.sql).
-- No INSERT/UPDATE/DELETE policy: this slice is read-only (Q5); no body
-- column exists (D-MSG1).

create policy message_threads_select_assigned on public.message_threads
  for select
  using (
    public.is_active_member(organization_id)
    and exists (
      select 1
      from public.matters m
      where m.id = message_threads.matter_id
        and m.organization_id = message_threads.organization_id
        and (
          m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid()
        )
    )
  );
