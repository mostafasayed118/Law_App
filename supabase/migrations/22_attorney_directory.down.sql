-- 22_attorney_directory.down.sql — backout for 22_attorney_directory.sql
-- (NOT APPLIED — standby)
-- Clean inverse: drop the slice's RPCs first (so no definer function is left
-- pointing at a missing table), then the attorney_profiles table (its index,
-- inline CHECKs, and read policy die with it). The consolidated rpc/_down.sql
-- drop list is maintained separately for the whole RPC surface; the drops here
-- are idempotent, so running both orders is safe.

begin;

drop function if exists public.list_attorney_profiles(text, boolean, integer);
drop function if exists public.get_attorney_profile(uuid);
drop function if exists public.create_attorney_profile(text, text, text, text[], text[], text, integer, text);
drop function if exists public.update_attorney_profile(uuid, text, text, text, text[], text[], text, integer, text, text);
drop function if exists public.deactivate_attorney_profile(uuid);

drop table if exists public.attorney_profiles;

commit;
