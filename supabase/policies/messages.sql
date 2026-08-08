-- policies/messages.sql — realtime read policy (REHEARSAL-READY — NOT applied, 2026-08-08)
-- Source of truth: docs/realtime_real_data_plan_2026-08-08.md (D-RT1/D-RT2)
--                + docs/realtime_rls_gate_review_2026-08-08.md (§4 deny-rows).
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- SELECT: an individual-message row is readable iff the reader is an
-- ACTIVE MEMBER of the message's organization AND is assigned (client or
-- attorney) on the message's THREAD's MATTER. This enforces the matrix §4
-- contract exactly (messages are matter content — line 143/148), the
-- message_threads_select_assigned gate extended ONE HOP to the rows:
--   - the exists subquery anchors on the row's thread (message_threads t),
--     then the thread's matter (matters m) — the assignment columns live on
--     the matters row itself, so the exists yields the matter gate
--     regardless of whether matters RLS re-applies inside the policy
--     (defense-in-depth either way, the 06-review Q2 property inherited);
--   - the THREE-WAY org equality is load-bearing: messages.organization_id
--     = t.organization_id = m.organization_id — the org gate comes from the
--     matter's AUTHORITATIVE org, never a denormalized column, so a message
--     is never readable when its thread (or matter) is not (the non-vacuous
--     org-mismatch battery row pins it);
--   - "org role alone (no matter assignment)" -> deny, every role;
--   - cross-org denied (is_active_member tests the message's org, and the
--     exists requires the message's org to MATCH the thread's and matter's
--     org);
--   - suspended/removed memberships never authorize (is_active_member is
--     the status = 'active' rule, 02_rls_functions);
--   - platform_owner_admin denied, always (owner accounts are never
--     assigned; no carve-out exists, Q4).
-- No new function surface — is_active_member is already EXECUTE-granted to
-- authenticated (R-4 grants in 02_rls_functions.sql). No INSERT/UPDATE/
-- DELETE policy: this slice is read-only (Q5); live delivery (D-RT6) is a
-- future reviewed slice with its own mechanism review.

create policy messages_select_assigned on public.messages
  for select
  using (
    public.is_active_member(organization_id)
    and exists (
      select 1
      from public.message_threads t
      join public.matters m
        on m.id = t.matter_id
       and m.organization_id = t.organization_id
      where t.id = messages.thread_id
        and messages.organization_id = t.organization_id
        and (
          m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid()
        )
    )
  );
