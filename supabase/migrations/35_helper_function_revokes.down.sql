-- Backout for 35_helper_function_revokes.sql: restore the pre-migration
-- default EXECUTE grants for the four internal helpers.

begin;

grant execute on function public.legal_normalize_ar(text) to public, anon, authenticated;
grant execute on function public.legal_cap(text) to public, anon, authenticated;
grant execute on function public.legal_library_touch() to public, anon, authenticated;
grant execute on function public.legal_user_data_touch() to public, anon, authenticated;

commit;
