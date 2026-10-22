-- rpc/create_attorney_profile.sql — owner-only directory write (NOT APPLIED)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §2
--                + docs/superpowers/plans/2026-10-22-discovery.md Task 3.
-- Backout: rpc/_down.sql (drop function; the blanket revoke covers the grant).
--
-- PLATFORM-OWNER ONLY. The directory is platform-level, so no org role can
-- create or edit a profile. Validation mirrors the table contract: a trimmed
-- display name of at least two characters; the 120-character bound, the
-- headline/bio/city bounds, the years range, and the status enum stay enforced
-- by the table CHECKs (CHECK = mapping contract, a bad value raises and maps to
-- a generic client error).
--
-- §8 audit: every successful create writes a REDACTED summary ('attorney
-- profile created' — never the name, headline, bio, city, or any contact
-- field), in the same implicit transaction as the insert (a write_audit
-- failure rolls the create back).
--
-- No parameter carries a default (the open PostgREST incident: every RPC
-- parameter must be explicit).

create or replace function public.create_attorney_profile(
  p_display_name     text,
  p_headline         text,
  p_bio              text,
  p_specialties      text[],
  p_languages        text[],
  p_city             text,
  p_years_experience integer,
  p_avatar_url       text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if not public.is_platform_owner() then
    raise exception 'permission denied';
  end if;
  if p_display_name is null or length(trim(p_display_name)) < 2 then
    raise exception 'display name is required';
  end if;

  insert into public.attorney_profiles
    (display_name, headline, bio, specialties, languages, city,
     years_experience, avatar_url, status, created_by)
  values
    (trim(p_display_name), nullif(trim(p_headline), ''), nullif(trim(p_bio), ''),
     coalesce(p_specialties, '{}'), coalesce(p_languages, '{}'),
     nullif(trim(p_city), ''), p_years_experience, nullif(trim(p_avatar_url), ''),
     'active', auth.uid())
  returning id into v_id;

  perform public.write_audit(
    'attorney_profile:create', 'allowed',
    p_resource_type    => 'attorney_profile',
    p_resource_id      => v_id,
    p_redacted_summary => 'attorney profile created'
  );
  return v_id;
end;
$$;

revoke execute on function public.create_attorney_profile(text, text, text, text[], text[], text, integer, text) from public, anon;
grant execute on function public.create_attorney_profile(text, text, text, text[], text[], text, integer, text) to authenticated;
