-- 22_attorney_directory.sql — real attorney directory (NOT APPLIED — rehearsal only)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §2
--                + docs/superpowers/plans/2026-10-22-discovery.md Tasks 1-4.
--
-- Replaces the synthetic discovery list with a platform-level directory managed
-- by the platform owner. Professional profile data only: no phone, email,
-- address, credential number, availability, or verification claim. Reads are
-- member-scoped and expose active rows only; every mutation is an owner-only
-- audited RPC (the §1 RPC-only-writes principle).
--
-- The table is default-deny: RLS on, all privileges revoked from anon +
-- authenticated, and exactly one narrow SELECT grant. The read policy lives in
-- supabase/policies/attorney_profiles.sql; the five RPCs live in
-- supabase/rpc/*attorney*.sql; the drops are mirrored in
-- supabase/rpc/_down.sql.
--
-- Rollback: 22_attorney_directory.down.sql (same directory).

begin;

create table public.attorney_profiles (
  id               uuid primary key default gen_random_uuid(),
  display_name     text not null check (length(trim(display_name)) between 2 and 120),
  headline         text check (headline is null or length(headline) <= 160),
  bio              text check (bio is null or length(bio) <= 2000),
  specialties      text[] not null default '{}',
  languages        text[] not null default '{}',
  city             text check (city is null or length(city) <= 120),
  years_experience integer check (years_experience is null
                                  or years_experience between 0 and 80),
  avatar_url       text,
  status           text not null default 'active'
                     check (status in ('active', 'inactive')),
  created_by       uuid references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index attorney_profiles_active
  on public.attorney_profiles (display_name) where status = 'active';

alter table public.attorney_profiles enable row level security;
revoke all on public.attorney_profiles from anon, authenticated;
grant select on public.attorney_profiles to authenticated;

commit;
