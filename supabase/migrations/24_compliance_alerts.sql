-- 24_compliance_alerts.sql — org-scoped compliance alerts (NOT APPLIED — rehearsal only)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §4
--                + docs/superpowers/plans/2026-10-22-compliance.md Tasks 1-2.
--
-- Replaces the synthetic compliance-alert list with persisted, org-scoped
-- alerts. Two tables:
--   compliance_alerts       — one row per alert, org-scoped, optional matter
--                             link, lifecycle open -> acknowledged -> resolved;
--   compliance_alert_events — append-only status trail (created/acknowledged/
--                             resolved), written by the RPCs in the same
--                             transaction as the state change.
--
-- The tables are default-deny: RLS on, all privileges revoked from anon +
-- authenticated, and exactly one narrow SELECT grant. The read policies live
-- in supabase/policies/compliance_alerts.sql + compliance_alert_events.sql;
-- the four audited RPCs live in supabase/rpc/*compliance_alert*.sql; the
-- drops are mirrored in supabase/rpc/_down.sql and
-- 24_compliance_alerts.down.sql.
--
-- No org role named 'admin' exists (01_org_schema: client | attorney |
-- partner | compliance_officer). Create/resolve authority is partner OR
-- compliance_officer; acknowledge is open to every active member. The
-- platform owner holds no membership and is denied by every gate.
--
-- No automated legal verification is claimed anywhere: alerts are recorded
-- rows, not a certification.
--
-- Rollback: 24_compliance_alerts.down.sql (same directory).

begin;

create table public.compliance_alerts (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  matter_id       uuid references public.matters (id) on delete set null,
  kind            text not null check (kind in ('deadline','conflict','retention','filing','other')),
  severity        text not null check (severity in ('low','medium','high','critical')),
  title           text not null check (length(trim(title)) between 2 and 160),
  description     text check (description is null or length(description) <= 4000),
  status          text not null default 'open'
                    check (status in ('open','acknowledged','resolved')),
  due_at          timestamptz,
  acknowledged_by uuid references auth.users (id) on delete set null,
  acknowledged_at timestamptz,
  resolved_by     uuid references auth.users (id) on delete set null,
  resolved_at     timestamptz,
  created_by      uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index compliance_alerts_org_status
  on public.compliance_alerts (organization_id, status, severity, created_at desc);
create index compliance_alerts_matter
  on public.compliance_alerts (matter_id) where matter_id is not null;

create table public.compliance_alert_events (
  id              uuid primary key default gen_random_uuid(),
  alert_id        uuid not null references public.compliance_alerts (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  action          text not null check (action in ('created','acknowledged','resolved')),
  actor_id        uuid references auth.users (id) on delete set null,
  note            text check (note is null or length(note) <= 2000),
  created_at      timestamptz not null default now()
);

create index compliance_alert_events_alert
  on public.compliance_alert_events (alert_id, created_at);

alter table public.compliance_alerts enable row level security;
alter table public.compliance_alert_events enable row level security;
revoke all on public.compliance_alerts from anon, authenticated;
revoke all on public.compliance_alert_events from anon, authenticated;
grant select on public.compliance_alerts to authenticated;
grant select on public.compliance_alert_events to authenticated;

commit;
