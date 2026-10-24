-- 27_audit_remediation.sql — participant-level read helpers (NOT APPLIED)
-- Source of truth: docs/live_apply_2026-10-24_audit_remediation.md
--
-- Two SECURITY DEFINER helpers let the read policies and the security-definer
-- read RPCs express the participant rule in one place:
--
--   can_read_matter        — the caller is assigned to the matter (client or
--                            attorney), created it, or is a partner of the
--                            matter's organization. A null matter is never
--                            readable.
--   can_access_video_session — the session exists, the caller is an active
--                            member of its organization, and the caller is a
--                            partner, the creator, a reader of the linked
--                            matter, or the client on the linked booking.
--
-- Both are STABLE and pin search_path = public. RLS recursion is avoided by
-- SECURITY DEFINER: the functions read public.matters / public.video_sessions
-- as their owner, and neither table is FORCE ROW LEVEL SECURITY, so the
-- policy that calls the helper does not re-enter itself. auth.uid() still
-- reads the calling request's JWT claims inside the definer body.
--
-- Rollback: 27_audit_remediation.down.sql (drop helpers), to be run only
-- after the pre-27 policies/RPCs are restored (they do not reference these
-- functions).

begin;

create or replace function public.can_read_matter(
  p_matter_id       uuid,
  p_organization_id uuid
) returns boolean
language sql stable security definer set search_path = public as $$
  select p_matter_id is not null
     and exists (
       select 1
         from public.matters m
        where m.id = p_matter_id
          and m.organization_id = p_organization_id
          and (
            m.assigned_client_id = auth.uid()
            or m.assigned_attorney_id = auth.uid()
            or m.created_by = auth.uid()
            or public.has_org_role(p_organization_id, 'partner')
          )
     )
$$;

create or replace function public.can_access_video_session(
  p_session_id uuid
) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.video_sessions s
     where s.id = p_session_id
       and public.is_active_member(s.organization_id)
       and (
         public.has_org_role(s.organization_id, 'partner')
         or s.created_by = auth.uid()
         or public.can_read_matter(s.matter_id, s.organization_id)
         or exists (
           select 1
             from public.consultations c
            where c.id = s.booking_id
              and c.client_user_id = auth.uid()
         )
       )
  )
$$;

-- Same default-deny posture as 02_rls_functions: no PUBLIC/anon EXECUTE, and
-- only authenticated may invoke the helpers (policy quals run as the querying
-- role, so the grant is required for RLS evaluation).
revoke execute on function public.can_read_matter(uuid, uuid) from public, anon;
revoke execute on function public.can_access_video_session(uuid) from public, anon;
grant execute on function public.can_read_matter(uuid, uuid) to authenticated;
grant execute on function public.can_access_video_session(uuid) to authenticated;

commit;
