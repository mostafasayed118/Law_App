-- 01_org_schema.sql — P2 reviewed migration (REVIEWED, NOT APPLIED)
-- Enums, tables, RLS enable, default-deny revokes + narrow grants.
-- Source of truth: docs/p2_schema_rls_design.md §4 (gate-approved 2026-08-01).
-- Rollback: 01_org_schema.down.sql (same directory).

begin;

-- sha-256 token hashing (Q2) and one-time token generation (invite_member).
-- pgcrypto lives in the `extensions` schema on this hosting; the token RPCs
-- qualify extensions.digest/extensions.gen_random_bytes explicitly (R-1
-- amendment, 2026-08-01). gen_random_uuid() below is core Postgres and
-- resolves without qualification.
create extension if not exists pgcrypto;

-- 4.1 Enums (four MVP org roles per D-09/Q3; researchAnalyst/admin excluded)
create type public.org_role as enum
  ('client', 'attorney', 'partner', 'compliance_officer');

create type public.membership_status as enum
  ('invited', 'active', 'suspended', 'removed');

create type public.invitation_status as enum
  ('pending', 'accepted', 'expired', 'revoked');

-- 4.2 profiles — application identity beside auth.users
create table public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  locale       text not null default 'en',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- 4.3 organizations — tenant boundary
create table public.organizations (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_by uuid references public.profiles (user_id) on delete set null,
  created_at timestamptz not null default now()
);

-- 4.4 memberships — identity <-> organization, role + lifecycle
create table public.memberships (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  role            public.org_role not null,
  status          public.membership_status not null default 'active',
  created_by      uuid references auth.users (id) on delete set null, -- actor (audit attribution)
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (organization_id, user_id)
);

-- 4.5 invitations — membership provisioning (D-10a)
create table public.invitations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  email           text not null,                 -- matching key only, never a principal
  role            public.org_role not null,
  status          public.invitation_status not null default 'pending',
  token_hash      text not null,                 -- sha-256 of the one-time token, never the token
  expires_at      timestamptz not null,          -- 7 days (D-10a)
  created_by      uuid references auth.users (id) on delete set null, -- actor
  created_at      timestamptz not null default now(),
  accepted_by     uuid,                          -- bound identity on acceptance
  accepted_at     timestamptz
);

create unique index invitations_pending_org_email
  on public.invitations (organization_id, email)
  where status = 'pending';   -- one pending invite per (org, email)

-- 4.6 audit_events — append-only, redacted (contract §8)
create table public.audit_events (
  id               bigint generated always as identity primary key,
  actor_user_id    uuid references auth.users (id) on delete set null, -- nullable: system events + D-05
  action           text not null,
  outcome          text not null,                -- 'allowed' | 'denied' | ...
  organization_id  uuid,                         -- nullable for identity-level events
  resource_type    text,                         -- 'membership' | 'invitation' | 'profile' | ...
  resource_id      uuid,
  correlation_id   uuid,                         -- request correlation, no secrets
  redacted_summary text,                         -- reason code / short change summary only
  server_timestamp timestamptz not null default now()
);

-- 4.7 platform_config — single-account capability source of truth (Q1)
create table public.platform_config (
  id            boolean primary key default true check (id),  -- single row
  owner_user_id uuid not null references auth.users (id)
);

-- RLS on for every table (default deny: with no policy, all access is denied)
alter table public.profiles      enable row level security;
alter table public.organizations enable row level security;
alter table public.memberships   enable row level security;
alter table public.invitations   enable row level security;
alter table public.audit_events  enable row level security;
alter table public.platform_config enable row level security;

-- Default-deny baseline: strip the Supabase default grants; the narrow client
-- surface is granted explicitly in policies/ + rpc/ (Q5). Nothing here grants
-- anon anything — anon is the deny row in the matrix.
revoke all on public.profiles, public.organizations, public.memberships,
       public.invitations, public.audit_events, public.platform_config
  from anon, authenticated;

-- Narrow direct SELECT grants per design §5.2 / matrix §3 (mutations are
-- RPC-only, Q5). Grants alone do nothing without policies; policies follow
-- in policies/*.sql.
grant select, update (display_name, locale)
  on public.profiles to authenticated;
grant select on public.organizations to authenticated;
grant select on public.memberships to authenticated;
grant select on public.invitations to authenticated;
-- audit_events and platform_config: NO direct grant — reads via RPC only.

commit;
