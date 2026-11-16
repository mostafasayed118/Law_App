-- 33_library_user_data.down.sql — rollback for per-user library data
-- Drops in dependency order: RPCs, cap helper, triggers, trigger function,
-- tables, then the colour enum.

begin;

drop function if exists public.clear_my_legal_history();
drop function if exists public.list_my_legal_history(integer, integer);
drop function if exists public.record_legal_reading(uuid);
drop function if exists public.list_my_legal_highlights(uuid, integer, integer);
drop function if exists public.delete_legal_highlight(uuid);
drop function if exists public.update_legal_highlight(uuid, public.legal_highlight_color, text);
drop function if exists public.create_legal_highlight(uuid, integer, integer, text, public.legal_highlight_color, text);
drop function if exists public.list_my_legal_bookmarks(uuid, integer, integer);
drop function if exists public.toggle_legal_bookmark(uuid, text);

drop function if exists public.legal_cap(text);

drop trigger if exists legal_reading_history_touch on public.legal_reading_history;
drop trigger if exists legal_highlights_touch        on public.legal_highlights;
drop trigger if exists legal_bookmarks_touch         on public.legal_bookmarks;

drop function if exists public.legal_user_data_touch();

drop table if exists public.legal_reading_history;
drop table if exists public.legal_highlights;
drop table if exists public.legal_bookmarks;

drop type if exists public.legal_highlight_color;

commit;
