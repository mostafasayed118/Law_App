-- 05_documents.sql — documents read-path migration (REVIEWED & APPLIED — dev project, 2026-08-07)
-- Source of truth: docs/documents_real_data_plan_2026-08-07.md (D-DR1/D-DR3)
--                + docs/documents_rls_gate_review_2026-08-07.md (Q1-Q6).
-- Rollback: 05_documents.down.sql (same directory).
--
-- The second roadmap §14 un-deferral: a real, org-scoped, MATTER-scoped
-- documents table (read path only, METADATA only — no body/content/size/
-- url columns, D-V1). RLS grants a row iff the reader is an active member
-- of the document's organization AND is assigned (client or attorney) on
-- the document's matter (matrix §4 — documents are matter content; an org
-- role alone never grants document access). Requires the APPLIED matters
-- table (04_matters.sql) as its FK target + assignment source of truth.
-- No INSERT/UPDATE/DELETE grant (Q5): mutations and bodies are future
-- reviewed slices.

begin;

-- 5.1 documents — org-scoped, matter-scoped, metadata-only (D-DR1/D-DR3)
create table public.documents (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  matter_id       uuid not null references public.matters (id) on delete cascade,
  title           text not null,       -- generic demo/real title; never PII by convention (D-V4)
  document_type   text not null
    check (document_type in ('contract', 'brief', 'evidence', 'correspondence')),  -- client DocumentType enum-name (D-DR3); CHECK = mapping contract
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- The two read shapes: the org-scoped list read + the per-matter lookup
-- (the FK join and the documents battery both use matter_id).
create index documents_org on public.documents (organization_id);
create index documents_matter on public.documents (matter_id);

-- RLS on (default deny: with no policy, all access is denied).
alter table public.documents enable row level security;

-- Default-deny baseline: strip the hosting default grants (the 01 pattern).
revoke all on public.documents from anon, authenticated;

-- Narrow direct SELECT grant per Q5 (row-scoped reads only; mutations are
-- RPC-only and not part of this slice). Grants alone do nothing without
-- policies; the policy follows in policies/documents.sql.
grant select on public.documents to authenticated;

commit;
