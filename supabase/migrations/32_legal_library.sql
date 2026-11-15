-- 32_legal_library.sql — Legal Library slice 1: schema + search (NOT APPLIED)
-- Source of truth: docs/adr/0009-legal-library-scope-and-sample-data.md
--
-- A GLOBAL reference library, not organization-scoped data. It is the first
-- module in the repo whose rows are not owned by a tenant, so it is also the
-- first table set whose read policy does not consult `memberships`: any
-- authenticated user may read, and anon may read nothing.
--
-- Scope of this slice: browse documents/articles and search them. There is no
-- client write path — bookmarks/history/highlights are a later slice and will
-- reference `legal_articles(id)`, which is why the primary key is a stable
-- uuid and the article identity never depends on its position in a document.
--
-- LEGAL ACCURACY: this migration ships NO real statutory text. The bundled
-- seed is deliberately artificial and every such row carries is_sample = true;
-- presentation renders a visible sample badge for it. Real text is imported by
-- the owner through tool/import_legal_library.dart.
--
-- Search: Postgres has no built-in Arabic text-search configuration, so the
-- library uses the `simple` configuration over text normalised by
-- legal_normalize_ar() (tashkeel/tatweel stripped, alef/ya/ta-marbuta folded,
-- Latin lowercased). search_text also carries an Arabic-article-stripped copy
-- of the same text so a query for "ايجار" reaches "الايجار" by prefix match
-- rather than requiring a stemming dictionary this deployment does not have.
-- See the ADR for what this does and does not handle.
--
-- pg_trgm is deliberately NOT used: this deployment's extension allowlist
-- could not be verified without applying to a live project, and none of the
-- slice's acceptance cases require fuzzy matching. Falling back to tsvector
-- only was the documented alternative.
--
-- Rollback: 32_legal_library.down.sql (same directory).

begin;

-- ---------------------------------------------------------------------------
-- 32.1 Enums
-- ---------------------------------------------------------------------------
create type public.legal_source_kind as enum
  ('statute', 'regulation', 'court_ruling');

create type public.legal_category as enum
  ('civil', 'criminal', 'labor', 'commercial', 'family',
   'administrative', 'constitutional', 'other');

create type public.legal_status as enum
  ('in_force', 'amended', 'repealed', 'unknown');

-- ---------------------------------------------------------------------------
-- 32.2 Arabic normalisation
-- ---------------------------------------------------------------------------
-- IMMUTABLE so it can back generated/trigger-maintained columns without the
-- planner having to re-evaluate it per row. Deliberately conservative: it
-- folds orthographic variants and removes decoration, and performs no
-- stemming — an Arabic stemmer is a linguistic decision this slice does not
-- make.
create or replace function public.legal_normalize_ar(p_text text)
returns text
language plpgsql
immutable
parallel safe
as $$
declare
  v_text text;
begin
  v_text := lower(coalesce(p_text, ''));

  -- Tashkeel (harakat) + Quranic annotation marks + superscript alef.
  v_text := regexp_replace(
    v_text,
    '[\u064B-\u065F\u0670\u06D6-\u06ED]',
    '',
    'g'
  );

  -- Tatweel (kashida) is pure decoration.
  v_text := regexp_replace(v_text, '\u0640', '', 'g');

  -- Alef variants (hamza above/below, madda, wasla) fold to bare alef.
  v_text := translate(v_text, '\u0623\u0625\u0622\u0671', '\u0627\u0627\u0627\u0627');

  -- Alef maqsura folds to ya.
  v_text := translate(v_text, '\u0649', '\u064A');

  -- Ta marbuta folds to ha.
  v_text := translate(v_text, '\u0629', '\u0647');

  -- Collapse runs of whitespace so tokenisation is stable.
  return btrim(regexp_replace(v_text, '\s+', ' ', 'g'));
end;
$$;

comment on function public.legal_normalize_ar(text) is
  'Orthographic normalisation for the legal library search index. Not a stemmer.';

-- ---------------------------------------------------------------------------
-- 32.3 Tables
-- ---------------------------------------------------------------------------
create table public.legal_sources (
  id            uuid primary key default gen_random_uuid(),
  name_ar       text not null check (length(btrim(name_ar)) between 1 and 200),
  name_en       text check (name_en is null
                            or length(btrim(name_en)) between 1 and 200),
  kind          public.legal_source_kind not null default 'statute',
  jurisdiction  text not null default 'EG'
                  check (jurisdiction ~ '^[A-Z]{2}$'),
  is_sample     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index legal_sources_jurisdiction on public.legal_sources (jurisdiction);

create table public.legal_documents (
  id              uuid primary key default gen_random_uuid(),
  source_id       uuid not null
                    references public.legal_sources (id) on delete restrict,
  title_ar        text not null check (length(btrim(title_ar)) between 1 and 400),
  title_en        text check (title_en is null or length(title_en) <= 400),
  official_number text check (official_number is null
                              or length(btrim(official_number)) between 1 and 80),
  year            integer check (year is null or year between 1800 and 2200),
  category        public.legal_category not null default 'other',
  status          public.legal_status not null default 'unknown',
  summary_ar      text check (summary_ar is null or length(summary_ar) <= 4000),
  published_at    date,
  is_sample       boolean not null default false,
  -- Maintained by the trigger below, never written by clients.
  search_text     text not null default '',
  search_tsv      tsvector not null default ''::tsvector,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index legal_documents_category_year
  on public.legal_documents (category, year desc nulls last, title_ar);

create index legal_documents_source on public.legal_documents (source_id);

create index legal_documents_search_tsv
  on public.legal_documents using gin (search_tsv);

create table public.legal_articles (
  id             uuid primary key default gen_random_uuid(),
  document_id    uuid not null
                   references public.legal_documents (id) on delete cascade,
  -- Text, not integer: citations include "5 bis", "12 مكرر" and similar.
  article_number text not null check (length(btrim(article_number)) between 1 and 40),
  -- Position within the document, used for ordering and prev/next navigation.
  ordinal        integer not null check (ordinal >= 1),
  heading_ar     text check (heading_ar is null or length(heading_ar) <= 400),
  body_ar        text not null check (length(btrim(body_ar)) > 0),
  body_en        text check (body_en is null or length(body_en) <= 20000),
  is_sample      boolean not null default false,
  search_text    text not null default '',
  search_tsv     tsvector not null default ''::tsvector,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint legal_articles_document_ordinal_key
    unique (document_id, ordinal),
  constraint legal_articles_document_number_key
    unique (document_id, article_number)
);

create index legal_articles_document_ordinal
  on public.legal_articles (document_id, ordinal);

create index legal_articles_search_tsv
  on public.legal_articles using gin (search_tsv);

-- ---------------------------------------------------------------------------
-- 32.4 Search index maintenance
-- ---------------------------------------------------------------------------
-- A generated column cannot reference another generated column, and search_tsv
-- is derived from search_text; a trigger keeps both in lockstep in one place
-- instead of duplicating the normalisation expression twice per table.
create or replace function public.legal_library_touch()
returns trigger
language plpgsql
as $$
begin
  if tg_table_name = 'legal_documents' then
    new.search_text := public.legal_normalize_ar(
        coalesce(new.title_ar, '') || ' ' ||
        coalesce(new.title_en, '') || ' ' ||
        coalesce(new.official_number, '') || ' ' ||
        coalesce(new.summary_ar, '')
      )
      || ' ' ||
      public.legal_normalize_ar(
        regexp_replace(
          coalesce(new.title_ar, '') || ' ' || coalesce(new.summary_ar, ''),
          '\m\u0627\u0644',
          '',
          'g'
        )
      );
  elsif tg_table_name = 'legal_articles' then
    new.search_text := public.legal_normalize_ar(
        coalesce(new.article_number, '') || ' ' ||
        coalesce(new.heading_ar, '') || ' ' ||
        coalesce(new.body_ar, '')
      )
      || ' ' ||
      public.legal_normalize_ar(
        regexp_replace(
          coalesce(new.heading_ar, '') || ' ' || coalesce(new.body_ar, ''),
          '\m\u0627\u0644',
          '',
          'g'
        )
      );
  end if;

  -- legal_sources has no search columns; the trigger exists there only to keep
  -- updated_at honest.
  if tg_table_name in ('legal_documents', 'legal_articles') then
    new.search_tsv := to_tsvector('simple', new.search_text);
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger legal_sources_touch
  before insert or update on public.legal_sources
  for each row execute function public.legal_library_touch();

create trigger legal_documents_touch
  before insert or update on public.legal_documents
  for each row execute function public.legal_library_touch();

create trigger legal_articles_touch
  before insert or update on public.legal_articles
  for each row execute function public.legal_library_touch();

-- ---------------------------------------------------------------------------
-- 32.5 RLS posture
-- ---------------------------------------------------------------------------
-- Default-deny at the privilege layer, then exactly the grants the policies
-- are written against. Reads are open to every authenticated user because this
-- is global reference data; writes are platform-owner only. There is no client
-- write path in this slice, so the write grants exist to let the boundary be
-- tested (and to keep the importer's option open) rather than to be used.
alter table public.legal_sources   enable row level security;
alter table public.legal_documents enable row level security;
alter table public.legal_articles  enable row level security;

revoke all on public.legal_sources   from anon, authenticated;
revoke all on public.legal_documents from anon, authenticated;
revoke all on public.legal_articles  from anon, authenticated;

grant select, insert, update, delete on public.legal_sources   to authenticated;
grant select, insert, update, delete on public.legal_documents to authenticated;
grant select, insert, update, delete on public.legal_articles  to authenticated;

-- The read policies and the owner-only write policies live in
-- supabase/policies/legal_{sources,documents,articles}.sql.

-- ---------------------------------------------------------------------------
-- 32.6 Read RPCs
-- ---------------------------------------------------------------------------
-- All SECURITY DEFINER with a pinned search_path: the RPC is the audited
-- surface, and anon holds no EXECUTE grant on any of them.
create or replace function public.list_legal_documents(
  p_category public.legal_category default null,
  p_limit    integer default 50,
  p_offset   integer default 0
)
returns table (
  id              uuid,
  source_id       uuid,
  source_name_ar  text,
  source_kind     public.legal_source_kind,
  title_ar        text,
  title_en        text,
  official_number text,
  year            integer,
  category        public.legal_category,
  status          public.legal_status,
  summary_ar      text,
  published_at    date,
  is_sample       boolean,
  article_count   bigint,
  total_count     bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select d.id,
         d.source_id,
         s.name_ar,
         s.kind,
         d.title_ar,
         d.title_en,
         d.official_number,
         d.year,
         d.category,
         d.status,
         d.summary_ar,
         d.published_at,
         d.is_sample,
         (select count(*) from public.legal_articles a
           where a.document_id = d.id) as article_count,
         count(*) over ()             as total_count
    from public.legal_documents d
    join public.legal_sources s on s.id = d.source_id
   where p_category is null or d.category = p_category
   order by d.year desc nulls last, d.title_ar, d.id
   limit least(greatest(coalesce(p_limit, 50), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create or replace function public.get_legal_document(
  p_id             uuid,
  p_article_limit  integer default 200
)
returns table (
  document_id     uuid,
  source_id       uuid,
  source_name_ar  text,
  source_kind     public.legal_source_kind,
  title_ar        text,
  title_en        text,
  official_number text,
  year            integer,
  category        public.legal_category,
  status          public.legal_status,
  summary_ar      text,
  published_at    date,
  document_sample boolean,
  article_id      uuid,
  article_number  text,
  ordinal         integer,
  heading_ar      text,
  body_ar         text,
  body_en         text,
  article_sample  boolean,
  article_total   bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select d.id,
         d.source_id,
         s.name_ar,
         s.kind,
         d.title_ar,
         d.title_en,
         d.official_number,
         d.year,
         d.category,
         d.status,
         d.summary_ar,
         d.published_at,
         d.is_sample,
         a.id,
         a.article_number,
         a.ordinal,
         a.heading_ar,
         a.body_ar,
         a.body_en,
         a.is_sample,
         (select count(*) from public.legal_articles x
           where x.document_id = d.id) as article_total
    from public.legal_documents d
    join public.legal_sources s on s.id = d.source_id
    left join lateral (
      select *
        from public.legal_articles a
       where a.document_id = d.id
       order by a.ordinal
       limit least(greatest(coalesce(p_article_limit, 200), 1), 200)
    ) a on true
   where d.id = p_id
   order by a.ordinal nulls last;
$$;

create or replace function public.get_legal_article(p_id uuid)
returns table (
  article_id      uuid,
  document_id     uuid,
  article_number  text,
  ordinal         integer,
  heading_ar      text,
  body_ar         text,
  body_en         text,
  article_sample  boolean,
  document_title_ar text,
  document_title_en text,
  document_sample boolean,
  prev_article_id uuid,
  next_article_id uuid,
  article_total   bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with neighbour as (
    select a.id,
           a.document_id,
           a.article_number,
           a.ordinal,
           a.heading_ar,
           a.body_ar,
           a.body_en,
           a.is_sample,
           lag(a.id)  over (partition by a.document_id order by a.ordinal) as prev_id,
           lead(a.id) over (partition by a.document_id order by a.ordinal) as next_id,
           count(*)   over (partition by a.document_id) as total
      from public.legal_articles a
  )
  select n.id,
         n.document_id,
         n.article_number,
         n.ordinal,
         n.heading_ar,
         n.body_ar,
         n.body_en,
         n.is_sample,
         d.title_ar,
         d.title_en,
         d.is_sample,
         n.prev_id,
         n.next_id,
         n.total
    from neighbour n
    join public.legal_documents d on d.id = n.document_id
   where n.id = p_id;
$$;

create or replace function public.search_legal_library(
  p_query    text,
  p_category public.legal_category default null,
  p_limit    integer default 20,
  p_offset   integer default 0
)
returns table (
  article_id      uuid,
  document_id     uuid,
  document_title_ar text,
  document_title_en text,
  official_number text,
  year            integer,
  category        public.legal_category,
  status          public.legal_status,
  article_number  text,
  heading_ar      text,
  snippet         text,
  article_sample  boolean,
  document_sample boolean,
  rank            real,
  total_count     bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_normalized text;
  v_tsquery    tsquery;
  v_limit      integer;
  v_offset     integer;
begin
  -- Empty or whitespace-only input is a valid "nothing asked yet" state, not
  -- an error: the surface renders its no-query arm.
  if p_query is null or length(btrim(p_query)) = 0 then
    return;
  end if;

  if length(p_query) > 200 then
    raise exception 'legal_search_query_too_long'
      using errcode = '22023',
            hint = 'Search queries are capped at 200 characters.';
  end if;

  v_normalized := public.legal_normalize_ar(p_query);

  -- Tokenise, strip anything that is not alphanumeric, and require every
  -- token as a prefix match. Prefix matching is what lets a bare "ايجار"
  -- reach "الايجار" through the article-stripped half of search_text.
  select to_tsquery('simple', string_agg(term || ':*', ' & '))
    into v_tsquery
    from (
      select distinct regexp_replace(t, '[^[:alnum:]]', '', 'g') as term
        from unnest(string_to_array(v_normalized, ' ')) as t
    ) s
   where term <> '';

  if v_tsquery is null then
    return;
  end if;

  v_limit  := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  return query
  select a.id,
         d.id,
         d.title_ar,
         d.title_en,
         d.official_number,
         d.year,
         d.category,
         d.status,
         a.article_number,
         a.heading_ar,
         ts_headline(
           'simple',
           a.body_ar,
           v_tsquery,
           'StartSel=[[, StopSel=]], MaxFragments=1, MaxWords=22, MinWords=8'
         ),
         a.is_sample,
         d.is_sample,
         ts_rank_cd(a.search_tsv, v_tsquery)
           + case when a.search_text like '%' || v_normalized || '%'
                  then 0.1 else 0 end,
         count(*) over ()
    from public.legal_articles a
    join public.legal_documents d on d.id = a.document_id
   -- Two arms on purpose. The tsvector arm is the indexed, ranked matcher.
   -- The substring arm exists because Postgres classifies Arabic letters as
   -- word characters only when the database locale says they are alphabetic;
   -- on a `C`-locale database the tsvector arm silently tokenises to nothing
   -- and a library that returns no results looks broken rather than empty.
   -- The substring arm is unindexed: fine for a reference corpus of this
   -- size, and the first thing to revisit if the corpus grows.
   where (a.search_tsv @@ v_tsquery
          or a.search_text like '%' || v_normalized || '%')
     and (p_category is null or d.category = p_category)
   -- Stable ordering: rank, then a deterministic tiebreak, so paging never
   -- repeats or skips a row.
   order by ts_rank_cd(a.search_tsv, v_tsquery)
              + case when a.search_text like '%' || v_normalized || '%'
                     then 0.1 else 0 end desc,
            d.title_ar,
            a.ordinal,
            a.id
   limit v_limit
  offset v_offset;
end;
$$;

-- ---------------------------------------------------------------------------
-- 32.7 Execute grants: authenticated only, never anon, never PUBLIC
-- ---------------------------------------------------------------------------
revoke all on function public.list_legal_documents(public.legal_category, integer, integer)
  from public, anon;
revoke all on function public.get_legal_document(uuid, integer) from public, anon;
revoke all on function public.get_legal_article(uuid) from public, anon;
revoke all on function public.search_legal_library(text, public.legal_category, integer, integer)
  from public, anon;

grant execute on function public.list_legal_documents(public.legal_category, integer, integer)
  to authenticated;
grant execute on function public.get_legal_document(uuid, integer) to authenticated;
grant execute on function public.get_legal_article(uuid) to authenticated;
grant execute on function public.search_legal_library(text, public.legal_category, integer, integer)
  to authenticated;

commit;
