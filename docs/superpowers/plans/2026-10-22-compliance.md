# W-C Compliance — Implementation Plan

**Goal:** Replace the synthetic compliance-alert list with persisted,
org-scoped alerts that can be created, acknowledged, and resolved.

**Architecture:** Migration `24_compliance_alerts.sql` (alerts + append-only
events), two active-member read policies, four audited RPCs, and a Flutter
gateway + cubit + list UI. Fake only for env-less builds.

**Spec:** `docs/superpowers/specs/2026-10-22-five-features-design.md` §4.

## Global Constraints

Same as W-A/W-B: RPC-only writes, RLS default-deny + narrow select, no
parameter defaults, redacted `write_audit`, paired `.down.sql`, no live apply,
no push. Org roles: `client | attorney | partner | compliance_officer`.
Create/resolve authority: **partner or compliance_officer**. Acknowledge: any
active member. No automated legal verification is claimed anywhere.

---

### Task 1: Migration + down

`supabase/migrations/24_compliance_alerts.sql`:

```sql
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
```

Down: drop the four RPCs, then events, then alerts.

---

### Task 2: Policies

`supabase/policies/compliance_alerts.sql` and
`supabase/policies/compliance_alert_events.sql`:

```sql
create policy compliance_alerts_select_org on public.compliance_alerts
  for select using (public.is_active_member(organization_id));

create policy compliance_alert_events_select_org on public.compliance_alert_events
  for select using (public.is_active_member(organization_id));
```

Bump the pinned public-policy count by +2.

---

### Task 3: RPCs

Files: `supabase/rpc/create_compliance_alert.sql`,
`acknowledge_compliance_alert.sql`, `resolve_compliance_alert.sql`,
`list_compliance_alerts.sql`; append drops to `_down.sql`.

**Signatures (no defaults):**
- `create_compliance_alert(uuid, uuid, text, text, text, text, timestamptz) returns uuid`
- `acknowledge_compliance_alert(uuid) returns void`
- `resolve_compliance_alert(uuid, text) returns void`
- `list_compliance_alerts(uuid, text, text) returns setof public.compliance_alerts`

**Gates:**
- create: active member; caller is partner **or** compliance_officer; kind,
  severity, title validated; when `p_matter_id` is supplied it must belong to
  the same org. Insert `created_by = auth.uid()`, event `created`, audit
  `compliance_alert:create`.
- acknowledge: alert must be `open`; caller must be an active member of the
  alert's org; sets `acknowledged_by/at`, status `acknowledged`; event; audit
  `compliance_alert:acknowledge`.
- resolve: alert must be `open` or `acknowledged`; caller is partner or
  compliance_officer; sets `resolved_by/at`, status `resolved`, optional note;
  event; audit `compliance_alert:resolve`.
- list: active member of the org; optional exact status and severity filters;
  newest first.

Raise `'permission denied'`, `'compliance alert not found'`,
`'compliance alert is already resolved'`.

---

### Task 4: Battery + harness

`supabase/tests/24_compliance_alert_rls.sql`, at least 15 markers:
partner create + audit; compliance-officer create; client create denied;
cross-org matter denied; suspended/anon denied; member list scoped; cross-org
list denied; member acknowledge positive + event; acknowledge on resolved
denied; client resolve denied; compliance-officer resolve positive; partner
resolve positive; direct DML denied; severity/status filters; final audit/event
count. Rollback. Register in the four lists + `--apply`.

---

### Task 5: Dart data layer

- `AlertSeverity` becomes `{low, medium, high, critical}` (update labels/tile);
  add `AlertStatus {open, acknowledged, resolved}`.
- `ComplianceAlert`: add `organizationId`, `matterId?`, `description?`,
  `status`, `dueAt?`, `acknowledgedAt?`, `resolvedAt?`, `isAcknowledgeable`,
  `isResolvable`.
- `ComplianceAlertsGateway`: `fetchAlerts({AlertStatus? status, AlertSeverity? severity})`,
  `create(ComplianceAlertDraft)`, `acknowledge(String id)`,
  `resolve(String id, {String? note})`; add `ComplianceAlertDraft`.
- New `lib/data/compliance/supabase_compliance_api.dart` + `_impl.dart` +
  `supabase_compliance_gateway.dart`; env-gated seam; mutable fake.
- The gateway takes an org resolver like the approvals gateway.

---

### Task 6: UI

- Filter chips (status + severity), create action for partner/compliance
  officer, acknowledge for any member, resolve for partner/compliance officer,
  detail sheet with description/due date/ack/resolve timestamps.
- Keep the existing list surface and tile; use text + icon for severity, never
  color alone.
- Honest copy: "alerts are recorded for this organization; no automated legal
  verification is performed."

---

### Task 7: l10n + tests + gates + commits

Add en/ar/tr keys, `flutter gen-l10n`, ARB parity. Widget + gateway tests.
Run all gates. Update README + supabase README. Three commits (backend,
client, docs), explicit pathspecs, no push.

**STOP list:** any need to change the role enum; any automatic verification
claim; any live apply; any widen of an existing policy.
