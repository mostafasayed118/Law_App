-- rpc/update_attorney_profile.sql — owner-only directory write (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §2
--                + docs/superpowers/plans/2026-10-22-discovery.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- PLATFORM-OWNER ONLY, full-row replace of the editable profile fields. A NULL
-- p_status keeps the current status; any other value must be 'active' or
-- 'inactive' (the table CHECK is the backstop). A missing id raises
-- 'attorney profile not found' — the RPC never silently succeeds.
--
-- §8 audit: redacted summary only ('attorney profile updated' — never any
-- profile field). Same implicit transaction as the update.

create or replace function public.update_attorney_profile(
  p_id               uuid,
  p_display_name     text,
  p_headline         text,
  p_bio              text,
  p_specialties      text[],
  p_languages        text[],
  p_city             text,
  p_years_experience integer,
  p_avatar_url       text,
  p_status           text
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_cnt bigint;
begin
  if not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;
  if p_display_name is null or length(trim(p_display_name)) < 2 then
    raise exception 'display name is required';
  end if;
  if p_status is not null and p_status not in ('active', 'inactive') then
    raise exception 'invalid status';
  end if;

  update public.attorney_profiles
     set display_name     = trim(p_display_name),
         headline         = nullif(trim(p_headline), ''),
         bio              = nullif(trim(p_bio), ''),
         specialties      = coalesce(p_specialties, '{}'),
         languages        = coalesce(p_languages, '{}'),
         city             = nullif(trim(p_city), ''),
         years_experience = p_years_experience,
         avatar_url       = nullif(trim(p_avatar_url), ''),
         status           = coalesce(p_status, status),
         updated_at       = now()
   where id = p_id;
  get diagnostics v_cnt = row_count;
  if v_cnt = 0 then
    raise exception 'attorney profile not found';
  end if;

  perform public.write_audit(
    'attorney_profile:update', 'allowed',
    p_resource_type    => 'attorney_profile',
    p_resource_id      => p_id,
    p_redacted_summary => 'attorney profile updated'
  );
end;
$$;

revoke execute on function public.update_attorney_profile(uuid, text, text, text, text[], text[], text, integer, text, text) from public, anon;
grant execute on function public.update_attorney_profile(uuid, text, text, text, text[], text[], text, integer, text, text) to authenticated;
