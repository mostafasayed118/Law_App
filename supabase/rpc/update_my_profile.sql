-- rpc/update_my_profile.sql — owner-scoped display-name edit (ADR-0011)
-- Migration 30 made profiles mutations RPC-only; this is the missing write path.
-- Identity comes from auth.uid(), never from a parameter. The value is never
-- written to the audit summary.
-- Backout: rpc/_down.sql (consolidated) or
--          34_polish_profile_and_deletion.down.sql (targeted).

create or replace function public.update_my_profile(p_display_name text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text := btrim(p_display_name);
begin
  if v_name is null or length(v_name) < 2 or length(v_name) > 120 then
    raise exception 'legal_profile_invalid_display_name' using errcode = '22023';
  end if;
  if v_name ~ '[[:cntrl:]]' then
    raise exception 'legal_profile_invalid_display_name' using errcode = '22023';
  end if;

  update public.profiles
     set display_name = v_name,
         updated_at   = now()
   where user_id = auth.uid();
  if not found then
    raise exception 'legal_profile_not_found' using errcode = 'P0002';
  end if;

  perform public.write_audit(
    'profile:update', 'allowed',
    p_resource_type => 'profile',
    p_resource_id => auth.uid(),
    p_redacted_summary => 'profile display name updated; value not logged'
  );
end;
$$;

revoke execute on function public.update_my_profile(text) from public, anon;
grant execute on function public.update_my_profile(text) to authenticated;
