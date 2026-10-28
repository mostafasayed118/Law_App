-- 30_profiles_mutations_rpc_only.down.sql — restore the pre-30 profiles
-- UPDATE surface (NOT APPLIED).
--
-- Recreates the narrow grant from 01_org_schema.sql:112-113 and the
-- profiles_update_own policy from supabase/policies/profiles.sql:13-16. The
-- drop-if-exists makes a re-run idempotent; the recreated policy definition is
-- the shipped one.

begin;

grant select, update (display_name, locale)
  on public.profiles to authenticated;

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

commit;
