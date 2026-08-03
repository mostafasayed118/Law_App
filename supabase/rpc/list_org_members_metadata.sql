-- rpc/list_org_members_metadata.sql — Phase 3 R1 reviewed RPC (IMPLEMENTED — repo
-- artifact 2026-08-03; NOT APPLIED to any project).
-- Source of truth: docs/p3_r1_roster_rpc_design_2026-08-03.md §3/§4/§6/§9 + matrix
-- §2 addendum (2026-08-03).
-- Backout: rpc/_down.sql (amended, design §9).
--
-- Partner-scoped member-metadata read for ONE organization: members with
-- identity metadata (display_name, locale) + membership metadata (role,
-- status, timestamps) + pending invitations with their invitation id.
-- SECURITY DEFINER with a single in-body guard (has_org_role 'partner'); the
-- D-T6 pair holds — this RPC is the ONLY widened path across profiles, which
-- stays own-row-only. The read itself is audited; denials raise the generic
-- 'permission denied' with no audit row (design §7).

create or replace function public.list_org_members_metadata(p_organization_id uuid)
returns table (
  organization_id uuid,             -- always p_organization_id
  user_id         uuid,             -- members only; NULL for invited rows
  invitation_id   uuid,             -- pending invites only; NULL for members (R1 extension)
  email           text,             -- invited address for invited rows; NULL for members
  display_name    text,             -- profiles.display_name; NULL for invited rows
  locale          text,             -- profiles.locale; NULL for invited rows
  role            public.org_role,
  status          public.membership_status,  -- 'invited' for invitation rows
  created_at      timestamptz,
  updated_at      timestamptz
)
language plpgsql security definer set search_path = public as $$
begin
  if not public.has_org_role(p_organization_id, 'partner') then
    raise exception 'permission denied';
  end if;

  perform public.write_audit(
    'partner:list_org_members', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type => 'membership',
    p_redacted_summary => 'member metadata listing for org'
  );

  return query
    -- members: membership metadata joined with identity metadata (LEFT JOIN +
    -- COALESCE — defensive against orphan memberships: a membership whose
    -- profiles row is missing still appears, with the static fallback name
    -- '(no profile)'/'en', instead of dropping the roster row)
    select m.organization_id, m.user_id, null::uuid as invitation_id, null::text as email,
           coalesce(p.display_name, '(no profile)') as display_name,
           coalesce(p.locale, 'en') as locale,
           m.role, m.status, m.created_at, m.updated_at
      from public.memberships m
      left join public.profiles p on p.user_id = m.user_id
     where m.organization_id = p_organization_id
    union all
    -- pending invitations only: revoked/expired/accepted rows leave the roster
    select i.organization_id, null::uuid, i.id, i.email,
           null::text, null::text, i.role, 'invited'::public.membership_status,
           i.created_at, i.created_at
      from public.invitations i
     where i.organization_id = p_organization_id
       and i.status = 'pending'
   order by organization_id, status, display_name nulls last, email;
end;
$$;

revoke execute on function public.list_org_members_metadata(uuid) from public, anon;
grant execute on function public.list_org_members_metadata(uuid) to authenticated;
