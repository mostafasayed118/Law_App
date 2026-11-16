-- 33_library_user_data.sql — bookmarks, highlights, reading history (NOT APPLIED)
-- Source of truth: docs/adr/0010-library-user-data-bookmarks-highlights-history.md
--
-- Per-user data layered on the global Legal Library (migration 32). Three tables,
-- every row owned by exactly one identity:
--
--   legal_bookmarks        one row per (user, article); optional note
--   legal_highlights       a selected range of an article, with an optional note
--   legal_reading_history  last-read bookkeeping, pruned to the newest 100
--
-- Ownership is the whole security model here. There is no sharing, no org scope
-- and no platform-owner carve-out: a platform owner reading another user's
-- highlights is a privacy breach, not administration. RLS therefore has exactly
-- one predicate — user_id = auth.uid() — and the tables carry a SELECT grant only.
-- Every mutation goes through an RPC below, which derives the caller from
-- auth.uid() and never accepts a user id parameter.
--
-- Highlight integrity: a highlight stores the offsets, a snapshot of the quoted
-- text, and md5() of the article body it was taken from. An amendment changes the
-- body, so the stored hash stops matching and the row is reported as stale rather
-- than being rendered at offsets that now point at different words.
--
-- Rollback: 33_library_user_data.down.sql (same directory).

begin;

-- ---------------------------------------------------------------------------
-- 33.1 Highlight colour slots
-- ---------------------------------------------------------------------------
-- A closed set, not free text: the reader maps each slot to a theme token, so a
-- new value needs a design decision, not a migration.
create type public.legal_highlight_color as enum
  ('yellow', 'green', 'blue', 'pink');

-- ---------------------------------------------------------------------------
-- 33.2 Tables
-- ---------------------------------------------------------------------------
create table public.legal_bookmarks (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  article_id uuid not null references public.legal_articles (id) on delete cascade,
  note       text check (note is null or length(note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint legal_bookmarks_user_article_key unique (user_id, article_id)
);

create index legal_bookmarks_user_created
  on public.legal_bookmarks (user_id, created_at desc);

create table public.legal_highlights (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  article_id   uuid not null references public.legal_articles (id) on delete cascade,
  -- 0-based, end-exclusive, counted in CHARACTERS (Postgres substring semantics).
  -- The client converts Flutter's UTF-16 selection offsets to rune offsets first.
  start_offset integer not null check (start_offset >= 0),
  end_offset   integer not null check (end_offset > start_offset),
  quote        text not null check (length(quote) between 1 and 1000),
  -- md5(body_ar) at creation time; the staleness signal when an article is amended.
  body_hash    text not null check (length(body_hash) = 32),
  color        public.legal_highlight_color not null default 'yellow',
  note         text check (note is null or length(note) <= 1000),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint legal_highlights_span_key check (end_offset - start_offset between 1 and 1000),
  constraint legal_highlights_quote_matches_span
    check (length(quote) <= end_offset - start_offset)
);

create index legal_highlights_user_article
  on public.legal_highlights (user_id, article_id, start_offset);

create index legal_highlights_user_created
  on public.legal_highlights (user_id, created_at desc);

create table public.legal_reading_history (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  article_id   uuid not null references public.legal_articles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  read_count   integer not null default 1 check (read_count >= 1),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint legal_reading_history_user_article_key unique (user_id, article_id)
);

create index legal_reading_history_user_recent
  on public.legal_reading_history (user_id, last_read_at desc);

-- ---------------------------------------------------------------------------
-- 33.3 updated_at maintenance
-- ---------------------------------------------------------------------------
-- The library trigger in migration 32 branches on its own table names and writes
-- search columns that do not exist here, so it cannot be reused.
create or replace function public.legal_user_data_touch()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger legal_bookmarks_touch
  before insert or update on public.legal_bookmarks
  for each row execute function public.legal_user_data_touch();

create trigger legal_highlights_touch
  before insert or update on public.legal_highlights
  for each row execute function public.legal_user_data_touch();

create trigger legal_reading_history_touch
  before insert or update on public.legal_reading_history
  for each row execute function public.legal_user_data_touch();

-- ---------------------------------------------------------------------------
-- 33.4 RLS posture
-- ---------------------------------------------------------------------------
-- SELECT only. There is no INSERT/UPDATE/DELETE grant and no write policy, so a
-- direct client write fails at the privilege layer before any policy is
-- consulted — including for the platform owner. The RPCs below are the only
-- write path and they are SECURITY DEFINER.
alter table public.legal_bookmarks       enable row level security;
alter table public.legal_highlights      enable row level security;
alter table public.legal_reading_history enable row level security;

revoke all on public.legal_bookmarks       from anon, authenticated;
revoke all on public.legal_highlights      from anon, authenticated;
revoke all on public.legal_reading_history from anon, authenticated;

grant select on public.legal_bookmarks       to authenticated;
grant select on public.legal_highlights      to authenticated;
grant select on public.legal_reading_history to authenticated;

-- The read policies live in supabase/policies/legal_{bookmarks,highlights,
-- reading_history}.sql.

-- ---------------------------------------------------------------------------
-- 33.5 Caps
-- ---------------------------------------------------------------------------
-- One place per cap so the RPCs and the tests cannot drift apart.
create or replace function public.legal_cap(p_name text)
returns integer
language sql
immutable
as $$
  select case p_name
    when 'bookmarks_per_user'       then 500
    when 'highlights_per_article'   then 50
    when 'highlights_per_user'      then 2000
    when 'history_per_user'         then 100
    else null
  end;
$$;

-- ---------------------------------------------------------------------------
-- 33.6 Bookmarks
-- ---------------------------------------------------------------------------
-- Idempotent by intent: the same call twice returns to the starting state. A note
-- is written on the bookmarking insert and is discarded when the bookmark is
-- removed, which is what "toggle" means to a reader.
create or replace function public.toggle_legal_bookmark(
  p_article_id uuid,
  p_note       text default null
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user  uuid := auth.uid();
  v_count integer;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_note is not null and length(p_note) > 500 then
    raise exception 'legal_bookmark_note_too_long' using errcode = '22023';
  end if;
  if not exists (select 1 from public.legal_articles where id = p_article_id) then
    raise exception 'legal_article_not_found' using errcode = 'P0002';
  end if;

  delete from public.legal_bookmarks
   where user_id = v_user and article_id = p_article_id
  returning 1 into v_count;

  if v_count is not null then
    return false;
  end if;

  select count(*) into v_count
    from public.legal_bookmarks where user_id = v_user;
  if v_count >= public.legal_cap('bookmarks_per_user') then
    raise exception 'legal_bookmark_limit_reached' using errcode = '54000';
  end if;

  insert into public.legal_bookmarks (user_id, article_id, note)
  values (v_user, p_article_id, nullif(btrim(p_note), ''));

  return true;
end;
$$;

create or replace function public.list_my_legal_bookmarks(
  p_limit  integer default 50,
  p_offset integer default 0
)
returns table (
  bookmark_id       uuid,
  article_id        uuid,
  document_id       uuid,
  document_title_ar text,
  article_number    text,
  heading_ar        text,
  note              text,
  article_sample    boolean,
  document_sample   boolean,
  created_at        timestamptz,
  total_count       bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select b.id,
         b.article_id,
         a.document_id,
         d.title_ar,
         a.article_number,
         a.heading_ar,
         b.note,
         a.is_sample,
         d.is_sample,
         b.created_at,
         count(*) over ()
    from public.legal_bookmarks b
    join public.legal_articles a on a.id = b.article_id
    join public.legal_documents d on d.id = a.document_id
   where b.user_id = auth.uid()
   order by b.created_at desc, b.id
   limit least(greatest(coalesce(p_limit, 50), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- ---------------------------------------------------------------------------
-- 33.7 Highlights
-- ---------------------------------------------------------------------------
create or replace function public.create_legal_highlight(
  p_article_id   uuid,
  p_start_offset integer,
  p_end_offset   integer,
  p_quote        text,
  p_color        public.legal_highlight_color,
  p_note         text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user        uuid := auth.uid();
  v_body        text;
  v_span        integer;
  v_per_article integer;
  v_per_user    integer;
  v_id          uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_start_offset is null or p_start_offset < 0 then
    raise exception 'legal_highlight_invalid_range' using errcode = '22023';
  end if;
  if p_end_offset is null or p_end_offset <= p_start_offset then
    raise exception 'legal_highlight_invalid_range' using errcode = '22023';
  end if;
  v_span := p_end_offset - p_start_offset;
  if v_span > 1000 then
    raise exception 'legal_highlight_too_long' using errcode = '22023';
  end if;
  if p_quote is null or length(btrim(p_quote)) = 0 then
    raise exception 'legal_highlight_quote_required' using errcode = '22023';
  end if;
  if p_note is not null and length(p_note) > 1000 then
    raise exception 'legal_highlight_note_too_long' using errcode = '22023';
  end if;

  select body_ar into v_body
    from public.legal_articles where id = p_article_id;
  if v_body is null then
    raise exception 'legal_article_not_found' using errcode = 'P0002';
  end if;

  -- The span must still point at the quoted words. This is the guard that makes
  -- a stale offset impossible to store in the first place.
  if substring(v_body from p_start_offset + 1 for v_span) <> p_quote then
    raise exception 'legal_highlight_quote_mismatch' using errcode = '22023';
  end if;

  select count(*) into v_per_article
    from public.legal_highlights
   where user_id = v_user and article_id = p_article_id;
  if v_per_article >= public.legal_cap('highlights_per_article') then
    raise exception 'legal_highlight_article_limit_reached' using errcode = '54000';
  end if;

  select count(*) into v_per_user
    from public.legal_highlights where user_id = v_user;
  if v_per_user >= public.legal_cap('highlights_per_user') then
    raise exception 'legal_highlight_limit_reached' using errcode = '54000';
  end if;

  insert into public.legal_highlights
    (user_id, article_id, start_offset, end_offset, quote, body_hash, color, note)
  values
    (v_user, p_article_id, p_start_offset, p_end_offset, p_quote,
     md5(v_body), p_color, nullif(btrim(p_note), ''))
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.update_legal_highlight(
  p_id    uuid,
  p_color public.legal_highlight_color default null,
  p_note  text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_rows integer;
begin
  if p_note is not null and length(p_note) > 1000 then
    raise exception 'legal_highlight_note_too_long' using errcode = '22023';
  end if;

  update public.legal_highlights
     set color = coalesce(p_color, color),
         note  = case when p_note is null then note
                      else nullif(btrim(p_note), '') end
   where id = p_id and user_id = auth.uid();
  get diagnostics v_rows = row_count;

  if v_rows = 0 then
    raise exception 'legal_highlight_not_found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.delete_legal_highlight(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_rows integer;
begin
  delete from public.legal_highlights
   where id = p_id and user_id = auth.uid();
  get diagnostics v_rows = row_count;

  if v_rows = 0 then
    raise exception 'legal_highlight_not_found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.list_my_legal_highlights(
  p_article_id uuid default null,
  p_limit      integer default 50,
  p_offset     integer default 0
)
returns table (
  highlight_id      uuid,
  article_id        uuid,
  document_id       uuid,
  document_title_ar text,
  article_number    text,
  start_offset      integer,
  end_offset        integer,
  quote             text,
  color             public.legal_highlight_color,
  note              text,
  is_stale          boolean,
  article_sample    boolean,
  document_sample   boolean,
  created_at        timestamptz,
  total_count       bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select h.id,
         h.article_id,
         a.document_id,
         d.title_ar,
         a.article_number,
         h.start_offset,
         h.end_offset,
         h.quote,
         h.color,
         h.note,
         h.body_hash <> md5(a.body_ar) as is_stale,
         a.is_sample,
         d.is_sample,
         h.created_at,
         count(*) over ()
    from public.legal_highlights h
    join public.legal_articles a on a.id = h.article_id
    join public.legal_documents d on d.id = a.document_id
   where h.user_id = auth.uid()
     and (p_article_id is null or h.article_id = p_article_id)
   order by h.created_at desc, h.id
   limit least(greatest(coalesce(p_limit, 50), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- ---------------------------------------------------------------------------
-- 33.8 Reading history
-- ---------------------------------------------------------------------------
-- Upsert + prune in one call: the history is bookkeeping, and a reader opening an
-- article must not be able to make it grow without bound.
create or replace function public.record_legal_reading(p_article_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not exists (select 1 from public.legal_articles where id = p_article_id) then
    raise exception 'legal_article_not_found' using errcode = 'P0002';
  end if;

  insert into public.legal_reading_history (user_id, article_id, last_read_at, read_count)
  values (v_user, p_article_id, now(), 1)
  on conflict (user_id, article_id) do update
    set last_read_at = now(),
        read_count   = public.legal_reading_history.read_count + 1;

  delete from public.legal_reading_history
   where user_id = v_user
     and id not in (
       select id from public.legal_reading_history
        where user_id = v_user
        order by last_read_at desc, id
        limit public.legal_cap('history_per_user')
     );
end;
$$;

create or replace function public.list_my_legal_history(
  p_limit  integer default 50,
  p_offset integer default 0
)
returns table (
  history_id        uuid,
  article_id        uuid,
  document_id       uuid,
  document_title_ar text,
  article_number    text,
  heading_ar        text,
  last_read_at      timestamptz,
  read_count        integer,
  article_sample    boolean,
  document_sample   boolean,
  total_count       bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select h.id,
         h.article_id,
         a.document_id,
         d.title_ar,
         a.article_number,
         a.heading_ar,
         h.last_read_at,
         h.read_count,
         a.is_sample,
         d.is_sample,
         count(*) over ()
    from public.legal_reading_history h
    join public.legal_articles a on a.id = h.article_id
    join public.legal_documents d on d.id = a.document_id
   where h.user_id = auth.uid()
   order by h.last_read_at desc, h.id
   limit least(greatest(coalesce(p_limit, 50), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create or replace function public.clear_my_legal_history()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_rows integer;
begin
  delete from public.legal_reading_history where user_id = auth.uid();
  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- 33.9 Execute grants: authenticated only
-- ---------------------------------------------------------------------------
revoke all on function public.toggle_legal_bookmark(uuid, text) from public, anon;
revoke all on function public.list_my_legal_bookmarks(integer, integer) from public, anon;
revoke all on function public.create_legal_highlight(uuid, integer, integer, text, public.legal_highlight_color, text) from public, anon;
revoke all on function public.update_legal_highlight(uuid, public.legal_highlight_color, text) from public, anon;
revoke all on function public.delete_legal_highlight(uuid) from public, anon;
revoke all on function public.list_my_legal_highlights(uuid, integer, integer) from public, anon;
revoke all on function public.record_legal_reading(uuid) from public, anon;
revoke all on function public.list_my_legal_history(integer, integer) from public, anon;
revoke all on function public.clear_my_legal_history() from public, anon;

grant execute on function public.toggle_legal_bookmark(uuid, text) to authenticated;
grant execute on function public.list_my_legal_bookmarks(integer, integer) to authenticated;
grant execute on function public.create_legal_highlight(uuid, integer, integer, text, public.legal_highlight_color, text) to authenticated;
grant execute on function public.update_legal_highlight(uuid, public.legal_highlight_color, text) to authenticated;
grant execute on function public.delete_legal_highlight(uuid) to authenticated;
grant execute on function public.list_my_legal_highlights(uuid, integer, integer) to authenticated;
grant execute on function public.record_legal_reading(uuid) to authenticated;
grant execute on function public.list_my_legal_history(integer, integer) to authenticated;
grant execute on function public.clear_my_legal_history() to authenticated;

commit;
