-- 32_legal_library.down.sql — rollback for the Legal Library slice 1
-- Drops in dependency order: RPCs, triggers, trigger function, tables,
-- normaliser, then the enums the tables used.

begin;

drop function if exists public.search_legal_library(text, public.legal_category, integer, integer);
drop function if exists public.get_legal_article(uuid);
drop function if exists public.get_legal_document(uuid, integer);
drop function if exists public.list_legal_documents(public.legal_category, integer, integer);

drop trigger if exists legal_articles_touch  on public.legal_articles;
drop trigger if exists legal_documents_touch on public.legal_documents;
drop trigger if exists legal_sources_touch   on public.legal_sources;

drop function if exists public.legal_library_touch();

drop table if exists public.legal_articles;
drop table if exists public.legal_documents;
drop table if exists public.legal_sources;

drop function if exists public.legal_normalize_ar(text);

drop type if exists public.legal_status;
drop type if exists public.legal_category;
drop type if exists public.legal_source_kind;

commit;
