-- rpc/create_matter.sql — matter-creation RPC (REHEARSAL-READY — NOT applied, 2026-08-09)
-- Source of truth: docs/f01_step2_matter_write_design_2026-08-09.md (F2-D1/F2-D2/F2-D4)
--                + docs/p4_findings_register_2026-08-09.md (F-01 step 2).
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- The FIRST matter-write surface (the matters table, 04, is read-only today).
-- F-01 step 2 core (F2-D2): the platform-owner id is never assignable to a
-- matter — derived from platform_config (self-updating, not hardcoded; the
-- battery-12 pattern), so the Q4 residual state (an assigned owner WOULD be
-- granted by every content policy) cannot be created through this RPC. The
-- categorical backstop is the BEFORE INSERT OR UPDATE trigger
-- (migrations/11_matter_write.sql — F2-D3), which refuses the same state at
-- the data layer for ANY path, this RPC included.
--
-- Gates (in order):
--   F2-D1 — the caller must be an ACTIVE PARTNER of the org
--           (has_org_role(org,'partner')); the org id is a routing hint and
--           membership is re-derived server-side (D-08). Conservative default
--           for the undefined matter-authoring policy (D-MR5); owner can
--           widen in a future slice.
--   F2-D2 — neither assignee may be the platform owner (see above).
--   F2-D4 — an assignee must be an ACTIVE MEMBER of the org (dead-assignment
--           guard — a non-member assignee could never read the matter, since
--           the read gate is is_active_member(org) AND assignment). This
--           queries public.memberships directly inside the definer body — it
--           deliberately does NOT use is_active_member(), which is
--           auth.uid()-self-scoped (the F-11 rule).
--   validation — title trimmed non-empty (mirror create_organization);
--           practice_area is enforced by the 04 CHECK (CHECK = mapping
--           contract; a bad value raises and maps to a generic client error).
--
-- §8 audit: every successful create writes a redacted summary ('matter
-- created' — never the title), same implicit transaction as the insert (a
-- write_audit failure rolls the create back).

create or replace function public.create_matter(
  p_organization_id    uuid,
  p_title              text,
  p_practice_area      text,
  p_assigned_client_id   uuid default null,
  p_assigned_attorney_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_owner  uuid;
  v_matter uuid;
begin
  -- F2-D1: active partner of the org (D-08: re-derive, never trust the arg alone).
  if not public.has_org_role(p_organization_id, 'partner') then
    raise exception 'permission denied';
  end if;

  -- F2-D2 (F-01 step 2 core): the platform owner is never assignable.
  select owner_user_id into v_owner from public.platform_config limit 1;
  if p_assigned_client_id = v_owner or p_assigned_attorney_id = v_owner then
    raise exception 'platform owner cannot be assigned to a matter';
  end if;

  -- F2-D4: assignees must be active members of the org (dead-assignment guard).
  if p_assigned_client_id is not null and not exists (
    select 1 from public.memberships
     where organization_id = p_organization_id
       and user_id = p_assigned_client_id
       and status = 'active'
  ) then
    raise exception 'assigned client must be an active member of the organization';
  end if;
  if p_assigned_attorney_id is not null and not exists (
    select 1 from public.memberships
     where organization_id = p_organization_id
       and user_id = p_assigned_attorney_id
       and status = 'active'
  ) then
    raise exception 'assigned attorney must be an active member of the organization';
  end if;

  if p_title is null or trim(p_title) = '' then
    raise exception 'matter title is required';
  end if;

  insert into public.matters
    (organization_id, title, practice_area, status,
     assigned_client_id, assigned_attorney_id)
  values
    (p_organization_id, trim(p_title), p_practice_area, 'open',
     p_assigned_client_id, p_assigned_attorney_id)
  returning id into v_matter;

  -- §8 audit (contract): redacted summary only — never the title.
  perform public.write_audit(
    'matter:create', 'allowed',
    p_organization_id  => p_organization_id,
    p_resource_type    => 'matter',
    p_resource_id      => v_matter,
    p_redacted_summary => 'matter created'
  );

  return v_matter;
end;
$$;

revoke execute on function public.create_matter(uuid, text, text, uuid, uuid) from public, anon;
grant execute on function public.create_matter(uuid, text, text, uuid, uuid) to authenticated;
