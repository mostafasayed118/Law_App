-- rpc/list_attorney_profiles.sql — directory listing (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §2
--                + docs/superpowers/plans/2026-10-22-discovery.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- READ-ONLY. Gates, in order:
--   - an ACTIVE membership in ANY organization, or the platform owner. The
--     directory is platform-level (no organization_id column), so the gate is
--     "active member somewhere", not an org-scoped helper;
--   - p_include_inactive is an OWNER-ONLY switch — a non-owner asking for
--     inactive rows is denied rather than silently filtered (an explicit
--     denial is honest; a silent downgrade would hide a caller bug).
--
-- Search: a null/blank query returns the whole visible page. Otherwise the
-- trimmed query is matched case-insensitively against display_name, headline,
-- city, and each specialty. Results are ordered by display_name and bounded
-- server-side to 1..100 rows (the P1.3 cap pattern: a compromised or buggy
-- caller cannot widen the read; a null p_limit defaults to 50).
--
-- No writes, no audit row: this is a read path. No parameter carries a default
-- (the open PostgREST incident).

create or replace function public.list_attorney_profiles(
  p_query            text,
  p_include_inactive boolean,
  p_limit            integer
) returns setof public.attorney_profiles
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(p_include_inactive, false) and not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;
  if not public.is_platform_owner() and not exists (
    select 1 from public.memberships m
     where m.user_id = auth.uid()
       and m.status = 'active'
  ) then
    raise exception 'permission denied';
  end if;

  return query
    select a.*
      from public.attorney_profiles a
     where (coalesce(p_include_inactive, false) or a.status = 'active')
       and (p_query is null or trim(p_query) = ''
            or a.display_name ilike '%' || trim(p_query) || '%'
            or coalesce(a.headline, '') ilike '%' || trim(p_query) || '%'
            or coalesce(a.city, '') ilike '%' || trim(p_query) || '%'
            or exists (
                 select 1 from unnest(a.specialties) s
                  where s ilike '%' || trim(p_query) || '%'))
     order by a.display_name
     limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

revoke execute on function public.list_attorney_profiles(text, boolean, integer) from public, anon;
grant execute on function public.list_attorney_profiles(text, boolean, integer) to authenticated;
