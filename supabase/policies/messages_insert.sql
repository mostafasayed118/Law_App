-- policies/messages_insert.sql — realtime push INSERT policy (REHEARSAL-READY — NOT applied, 2026-08-08)
-- Source of truth: docs/realtime_push_real_data_plan_2026-08-08.md (D-LV1)
--                + docs/realtime_push_gate_review_2026-08-08.md (§4 deny-rows).
-- Backout: git revert of this policy commit (rollback_plan.md design §7).
--
-- INSERT: a message row may be inserted iff the writer is an ACTIVE MEMBER
-- of the message's organization AND is assigned (client or attorney) on
-- the message's THREAD's MATTER — the same gate shape as the read policy
-- (messages_select_assigned, 08), applied as WITH CHECK. This is the
-- D-LV1 minimal write source: the event origin a postgres_changes INSERT
-- channel needs (a push slice with no write source delivers nothing).
-- The gate mirrors the read contract exactly:
--   - the exists subquery anchors on the row's thread (message_threads t),
--     then the thread's matter (matters m) — the assignment columns live on
--     the matters row itself;
--   - the THREE-WAY org equality is load-bearing: messages.organization_id
--     = t.organization_id = m.organization_id — the org gate comes from the
--     matter's AUTHORITATIVE org;
--   - "org role alone (no matter assignment)" -> deny, every role;
--   - cross-org denied (is_active_member tests the message's org, and the
--     exists requires the message's org to MATCH the thread's and matter's
--     org);
--   - suspended/removed memberships never authorize (is_active_member is
--     the status = 'active' rule, 02_rls_functions);
--   - platform_owner_admin denied, always (owner accounts are never
--     assigned; no carve-out exists, Q5).
-- The non-empty body CHECK is schema-level (08) — a policy cannot be
-- bypassed past it. INSERT-ONLY: no UPDATE/DELETE policy (no edit/delete/
-- receipts/attachments — the write-path creep guard). The direct-INSERT
-- path is not contract §8-audited (the demo-seed posture, review Q6 — a
-- future real-write slice should route sends through an audited RPC).

-- The write grant: 08 granted SELECT only (the read slice), so this
-- slice adds the INSERT grant — the policy below is the WITH CHECK gate
-- (a grant without a policy still passes; a policy without a grant never
-- fires — verified live on the rehearsal host 2026-08-08, where the first
-- draft had the policy without the grant and the partner INSERT was
-- permission-denied at the privilege layer).
grant insert on public.messages to authenticated;

create policy messages_insert_assigned on public.messages
  for insert
  with check (
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
