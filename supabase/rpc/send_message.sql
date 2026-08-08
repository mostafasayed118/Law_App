-- rpc/send_message.sql — audited message send (DESIGN REVIEWED 2026-08-08,
-- rehearsal-ready — NOT applied).
-- Source of truth: docs/send_message_gate_review_2026-08-08.md (Q1–Q6) +
-- docs/send_message_rpc_plan_2026-08-08.md (D-SM1..D-SM3).
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- The realtime-push review-Q6 follow-up: the app's message write path was a
-- policy-gated direct INSERT with NO contract §8 audit (the same posture as
-- the demo seeds). This RPC makes every send audited by construction:
--   D-SM1 — security definer + an explicit in-function gate (RLS does NOT
--           apply inside a definer function, so the gate IS the sole write
--           authorization): is_active_member(org) AND the thread->matter
--           three-way org equality AND assigned client/attorney — the exact
--           messages_insert_assigned authorization re-asserted.
--   Q4   — the org resolution the client previously performed as a pre-read
--           moves into the function (an unreadable thread = typed denial).
--   D-SM3 — when this ships with the T5 apply, the direct-INSERT grant is
--           revoked and messages_insert_assigned is dropped, so this RPC
--           becomes the ONLY write path.
--
-- Author display name (D-RT4 stored-name convention): read from profiles
-- (the handle_new_user mirror of raw_user_meta_data ->> 'display_name' —
-- the same source the client session's displayName comes from), with the
-- generic fallback the client impl uses ('Demo client'); never PII.

create or replace function public.send_message(
  p_thread_id uuid,
  p_body      text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_org        uuid;
  v_author     text;
  v_message_id uuid;
begin
  -- D-SM1 gate: the exact messages_insert_assigned authorization, asserted
  -- inside the function. The thread must resolve through its matter with
  -- the three-way org equality AND the caller must be an active member of
  -- the thread's org AND assigned (client or attorney) on the matter.
  select t.organization_id into v_org
    from public.message_threads t
    join public.matters m on m.id = t.matter_id
      and m.organization_id = t.organization_id
   where t.id = p_thread_id
     and public.is_active_member(t.organization_id)
     and (m.assigned_client_id = auth.uid()
          or m.assigned_attorney_id = auth.uid());
  if v_org is null then
    raise exception 'permission denied';
  end if;

  select display_name into v_author
    from public.profiles
   where user_id = auth.uid();
  v_author := coalesce(nullif(v_author, ''), 'Demo client');

  insert into public.messages
    (organization_id, thread_id, author_display_name, body)
  values
    (v_org, p_thread_id, v_author, p_body)
  returning id into v_message_id;

  -- Q3 — contract §8 audit: every successful send is audited. The summary
  -- is generic (redacted-only — never the body). Same implicit transaction
  -- as the insert: a write_audit failure rolls the send back.
  perform public.write_audit(
    'message:create', 'allowed',
    p_organization_id  => v_org,
    p_resource_type    => 'message',
    p_resource_id      => v_message_id,
    p_redacted_summary => 'message sent'
  );

  return v_message_id;
end;
$$;

revoke execute on function public.send_message(uuid, text) from public, anon;
grant execute on function public.send_message(uuid, text) to authenticated;

-- D-SM3 (gate review Q6): the direct-INSERT surface is revoked so this RPC
-- becomes the ONLY message write path — every write is §8-audited by
-- construction, and no un-audited INSERT path can reappear without an
-- explicit grant re-add. The SELECT policy (messages_select_assigned, the
-- delivery gate) is untouched; the policy count moves 11 -> 10 and the
-- battery pins both halves of the revocation (09.15 privilege-layer deny,
-- 09.16 policy gone). Backout: git-revert of this block (the policy + grant
-- re-add), per the gate review §6 — the _down.sql drop above is the
-- function half of the pairing.
revoke insert on public.messages from authenticated;
drop policy if exists messages_insert_assigned on public.messages;
