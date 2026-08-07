-- 07_storage.sql — storage read-path migration (REHEARSAL-READY — NOT applied, 2026-08-08)
-- Source of truth: docs/storage_real_data_plan_2026-08-08.md (D-STR1/D-STR3/D-STR4)
--                + docs/storage_rls_gate_review_2026-08-08.md (Q1-Q6).
-- Rollback: 07_storage.down.sql (same directory).
--
-- The fourth roadmap §14 un-deferral: a real, org-scoped, MATTER-scoped
-- file-storage surface (read path only, METADATA + bytes). Two layers:
--   1. a private `matter-files` bucket (this migration) whose objects are
--      stored at `{org_id}/{matter_id}/{filename}` — the byte-level read
--      is gated by the storage.objects RLS policy in
--      policies/storage_objects.sql (D-STR2, matrix §6);
--   2. a `public.files` METADATA table (this migration) — the list read,
--      gated by policies/files.sql (the documents/messages exists-subquery
--      pattern). No content/body/url column: bytes live ONLY in
--      storage.objects, never in the table (D-V1 line held, D-STR3).
-- Requires the APPLIED matters table (04_matters.sql) as FK target +
-- assignment source of truth (the documents 05 pattern) and the platform
-- storage schema (present on the dev project and any supabase start host —
-- the P2 Q4 "zero buckets" deferral is consummated here).
-- No INSERT/UPDATE/DELETE grant (Q5): uploads and writes are future
-- reviewed slices.

begin;

-- 7.1 Private bucket (D-STR4) — column list VERIFIED against the dev
-- project's storage schema on 2026-08-08 (read-only information_schema
-- probe): id, name, owner, created_at, updated_at, public,
-- avif_autodetection, file_size_limit, allowed_mime_types, owner_id, type.
-- The insert uses the minimal version-proof set (id, name, public) —
-- `owner` is the deprecated column (superseded by owner_id in current
-- storage versions) and is deliberately omitted; file_size_limit /
-- allowed_mime_types stay default (unlimited demo posture). `on conflict
-- (id) do nothing` keeps the harness --apply loop idempotent. The `type`
-- (USER-DEFINED enum) and `avif_autodetection` columns' nullability /
-- defaults were NOT probed (information_schema shows types, not
-- defaults) — the bare insert is verified against the rehearsal host
-- first (verify-don't-guess, T4) before the T5 apply; if the host's
-- schema demands `type`, the apply adds it from the rehearsal-proven
-- column list.
insert into storage.buckets (id, name, public)
values ('matter-files', 'matter-files', false)
on conflict (id) do nothing;

-- 7.2 files — org-scoped, matter-scoped, metadata-only (D-STR1/D-STR3)
create table public.files (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  matter_id        uuid not null references public.matters (id) on delete cascade,
  name             text not null,       -- generic demo/real filename; never PII by convention
  mime_type        text not null default 'application/octet-stream',
  size_bytes       bigint not null default 0
    check (size_bytes >= 0),            -- client FileMetadata.sizeBytes (D-STR3); CHECK = mapping contract
  storage_path     text not null,       -- single source of truth linking the row to its object
                                       -- `{org_id}/{matter_id}/{filename}`, canonical lowercase
                                       -- hyphenated uuid::text (review §5 pin — T2/T3 cannot drift)
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- The two read shapes: the org-scoped list read + the per-matter lookup
-- (the FK join and the files battery both use matter_id).
create index files_org on public.files (organization_id);
create index files_matter on public.files (matter_id);

-- RLS on (default deny: with no policy, all access is denied).
alter table public.files enable row level security;

-- Default-deny baseline: strip the hosting default grants (the 01 pattern).
revoke all on public.files from anon, authenticated;

-- Narrow direct SELECT grant per Q5 (row-scoped reads only; mutations are
-- RPC-only and not part of this slice). Grants alone do nothing without
-- policies; the policy follows in policies/files.sql. On storage.objects
-- no direct grants are added — the bucket is private and the storage
-- objects RLS policy is the only read surface (Q5).
grant select on public.files to authenticated;

commit;
