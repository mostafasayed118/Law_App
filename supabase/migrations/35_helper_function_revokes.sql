-- 35_helper_function_revokes.sql — explicit revokes for internal library helpers
-- (F-T4-02; follows migrations 32 and 33; NEVER edit an applied migration).
--
-- Migrations 32/33 created four internal helpers without an explicit REVOKE:
--
--   legal_normalize_ar(text)  pure Arabic normaliser used by search
--   legal_cap(text)           constant cap lookup used by RPC bodies
--   legal_library_touch()     BEFORE INSERT/UPDATE trigger on corpus tables
--   legal_user_data_touch()   BEFORE INSERT/UPDATE trigger on user-data tables
--
-- Postgres grants EXECUTE to PUBLIC by default. These helpers are not RPCs:
-- clients never call them, and the trigger functions are invoked by the
-- database itself. This migration removes the implicit PUBLIC/anon/authenticated
-- EXECUTE so the "all functions revoked from public/anon" claim is literally
-- true for the whole function inventory. No behaviour used by the app changes:
-- RPC bodies and triggers run under their definer/owner.

begin;

revoke all on function public.legal_normalize_ar(text) from public, anon, authenticated;
revoke all on function public.legal_cap(text) from public, anon, authenticated;
revoke all on function public.legal_library_touch() from public, anon, authenticated;
revoke all on function public.legal_user_data_touch() from public, anon, authenticated;

commit;
