-- rpc/get_attorney_profile.sql — single-profile read (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §2
--                + docs/superpowers/plans/2026-10-22-discovery.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- READ-ONLY. Gates:
--   - an ACTIVE membership in ANY organization, or the platform owner
--     ('permission denied');
--   - the row must be ACTIVE, unless the caller is the platform owner;
--     otherwise 'attorney profile not found' — a non-owner learns nothing
--     about an inactive profile, not even that it exists.
--
-- Returns the full public profile row (professional fields only; the table
-- carries no contact data). No audit row: read path. No parameter defaults.

create or replace function public.get_attorney_profile(p_id uuid)
returns public.attorney_profiles
language plpgsql security definer set search_path = public as $$
declare
  v_owner boolean := public.is_platform_owner();
  v_row   public.attorney_profiles;
begin
  if not v_owner and not exists (
    select 1 from public.memberships m
     where m.user_id = auth.uid()
       and m.status = 'active'
  ) then
    raise exception 'permission denied';
  end if;

  select a.* into v_row
    from public.attorney_profiles a
   where a.id = p_id;

  if not found or (v_row.status <> 'active' and not v_owner) then
    raise exception 'attorney profile not found';
  end if;

  return v_row;
end;
$$;

revoke execute on function public.get_attorney_profile(uuid) from public, anon;
grant execute on function public.get_attorney_profile(uuid) to authenticated;
