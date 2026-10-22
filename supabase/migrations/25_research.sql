-- 25_research.sql — persisted River research runs + findings (NOT APPLIED — rehearsal only)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §5
--                + docs/superpowers/plans/2026-10-22-research.md Tasks 1-3.
--
-- Replaces the synthetic research surface with two persisted tables:
--   research_runs     — one row per manual analysis request, org-scoped,
--                       optional matter link, lifecycle running ->
--                       completed | failed;
--   research_findings — the validated structured output of a completed run,
--                       org-scoped via a copied organization_id and ordered
--                       by sort_order.
--
-- Default-deny posture: RLS on, all privileges revoked from anon +
-- authenticated, exactly one narrow SELECT grant per table. Read policies
-- live in supabase/policies/research_runs.sql + research_findings.sql; the
-- four RPCs live in supabase/rpc/*research*.sql. The completion RPC is
-- service-role only.
--
-- Rollback: 25_research.down.sql (same directory).

begin;

create table public.research_runs (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  matter_id       uuid references public.matters (id) on delete set null,
  requested_by    uuid references auth.users (id) on delete set null,
  status          text not null default 'running'
                    check (status in ('running','completed','failed')),
  model           text,
  prompt_summary  text not null check (length(trim(prompt_summary)) between 2 and 500),
  error_code      text,
  created_at      timestamptz not null default now(),
  completed_at    timestamptz
);

create index research_runs_org_created
  on public.research_runs (organization_id, created_at desc);
create index research_runs_matter
  on public.research_runs (matter_id) where matter_id is not null;

create table public.research_findings (
  id              uuid primary key default gen_random_uuid(),
  run_id          uuid not null references public.research_runs (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  headline        text not null check (length(trim(headline)) between 2 and 200),
  summary         text not null check (length(trim(summary)) between 2 and 4000),
  excerpt         text check (excerpt is null or length(excerpt) <= 2000),
  source_type     text not null default 'none'
                    check (source_type in ('document','matter','none')),
  source_id       uuid,
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now()
);

create index research_findings_run
  on public.research_findings (run_id, sort_order);

alter table public.research_runs enable row level security;
alter table public.research_findings enable row level security;
revoke all on public.research_runs from anon, authenticated;
revoke all on public.research_findings from anon, authenticated;
grant select on public.research_runs to authenticated;
grant select on public.research_findings to authenticated;

commit;
