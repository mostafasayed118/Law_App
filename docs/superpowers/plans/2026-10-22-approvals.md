# W-B Approvals — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development.
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace the synthetic approvals queue with a persisted org-scoped
request/decision workflow.

**Architecture:** One migration (`23_approvals.sql`) with two tables, a read
policy per table, four audited `security definer` RPCs, and a Flutter gateway
matching the existing Cubit + list-surface pattern. Fake stays for env-less
builds only.

**Spec:** `docs/superpowers/specs/2026-10-22-five-features-design.md` §3.

## Global Constraints

Identical to W-A: RPC-only writes, RLS default-deny + narrow select, no RPC
parameter defaults, redacted `write_audit`, paired `.down.sql`, no live apply,
no push, explicit-pathspec commits.

Org roles are `client | attorney | partner | compliance_officer` — there is no
`admin` role. Decision authority is **partner**; the platform owner is not an
org member and is denied.

---

### Task 1: Migration + down

**Files:** Create `supabase/migrations/23_approvals.sql`,
`supabase/migrations/23_approvals.down.sql`.

```sql
-- 23_approvals.sql — org-scoped approval requests (NOT APPLIED — rehearsal only)
-- Source of truth: docs/superpowers/specs/2026-10-22-five-features-design.md §3.
begin;

create table public.approval_requests (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  matter_id       uuid references public.matters (id) on delete set null,
  title           text not null check (length(trim(title)) between 2 and 160),
  description     text check (description is null or length(description) <= 4000),
  kind            text not null check (kind in ('conflict','waiver','filing','expense','other')),
  status          text not null default 'pending'
                    check (status in ('pending','approved','rejected','cancelled')),
  requested_by    uuid references auth.users (id) on delete set null,
  decided_by      uuid references auth.users (id) on delete set null,
  decided_at      timestamptz,
  decision_note   text check (decision_note is null or length(decision_note) <= 2000),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index approval_requests_org_status
  on public.approval_requests (organization_id, status, created_at desc);
create index approval_requests_matter
  on public.approval_requests (matter_id) where matter_id is not null;

create table public.approval_events (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid not null references public.approval_requests (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  action          text not null check (action in ('created','approved','rejected','cancelled')),
  actor_id        uuid references auth.users (id) on delete set null,
  note            text check (note is null or length(note) <= 2000),
  created_at      timestamptz not null default now()
);

create index approval_events_request
  on public.approval_events (request_id, created_at);

alter table public.approval_requests enable row level security;
alter table public.approval_events enable row level security;
revoke all on public.approval_requests from anon, authenticated;
revoke all on public.approval_events from anon, authenticated;
grant select on public.approval_requests to authenticated;
grant select on public.approval_events to authenticated;

commit;
```

Down: drop both tables (events first), after dropping the four RPCs.

---

### Task 2: Policies

**Files:** Create `supabase/policies/approval_requests.sql`,
`supabase/policies/approval_events.sql`.

```sql
create policy approval_requests_select_org on public.approval_requests
  for select using (public.is_active_member(organization_id));

create policy approval_events_select_org on public.approval_events
  for select using (public.is_active_member(organization_id));
```

Update the pinned public-policy count by exactly +2.

---

### Task 3: RPCs

**Files:** Create `supabase/rpc/create_approval_request.sql`,
`decide_approval_request.sql`, `cancel_approval_request.sql`,
`list_approval_requests.sql`; modify `supabase/rpc/_down.sql`.

**Signatures (no defaults):**
- `create_approval_request(uuid, uuid, text, text, text) returns uuid`
- `decide_approval_request(uuid, text, text) returns void`
- `cancel_approval_request(uuid) returns void`
- `list_approval_requests(uuid, text) returns setof public.approval_requests`

**Gates:**
- create: `is_active_member(p_organization_id)`; kind in the enum list; title
  trimmed 2–160; if `p_matter_id` is not null, the matter must exist in the
  same org and the caller must be assigned client/attorney, the creator, or a
  partner. Insert `requested_by = auth.uid()`, event `created`, audit
  `approval:create`.
- decide: request must be `pending`; caller must be a partner of the request's
  org; caller must not be `requested_by`; decision in `approved|rejected`;
  `rejected` requires a note of at least 2 characters. Update
  `status/decided_by/decided_at/decision_note/updated_at`; event; audit
  `approval:decide` with outcome = decision.
- cancel: request must be `pending`; caller is `requested_by` or a partner;
  update to `cancelled`; event; audit `approval:cancel`.
- list: `is_active_member(p_organization_id)`; `p_status` null → all, else the
  exact status; order `created_at desc`.

Each RPC: `security definer set search_path = public`, explicit revoke/grant,
raise `'permission denied'` / `'approval request not found'` /
`'approval request is not pending'` / `'a rejection note is required'`.

---

### Task 4: Battery + harness

**Files:** Create `supabase/tests/23_approval_rls.sql`; modify
`scripts/verify_policy_tests.sh` (four lists + `--apply`).

At least 15 markers: partner create positive + audit; client create on a
readable matter positive; cross-org matter denied; suspended/anon denied;
list scoped to the org; cross-org list denied; partner decide positive +
event + audit; self-decision denied; client decide denied; non-pending decide
denied; rejection without a note denied; requester cancel positive; other
client cancel denied; direct INSERT/UPDATE denied. Rollback the battery.

---

### Task 5: Dart data layer

**Files:**
- Modify `lib/features/approvals/domain/pending_approval.dart` — add
  `description`, `decidedAt`, `decisionNote`, `isDecidable`; add
  `ApprovalStatus.cancelled`; map DB `rejected` → `ApprovalStatus.denied`.
- Modify `lib/features/approvals/domain/approvals_gateway.dart`:
  `fetchApprovals({ApprovalStatus? status})`,
  `create(ApprovalDraft)`, `decide(String id, {required bool approve, String? note})`,
  `cancel(String id)`; add `ApprovalDraft` (organizationId, matterId?, title,
  kind, description?).
- Create `lib/data/approvals/supabase_approval_api.dart` + `_impl.dart` +
  `supabase_approval_gateway.dart` (copy the matter api pattern).
- Modify `lib/features/approvals/data/fake_approvals_gateway.dart` to an
  in-memory mutable list (create/decide/cancel work; still synthetic rows).
- Register `_registerSeam<ApprovalsGateway>`; remove the unconditional fake
  registration.

---

### Task 6: UI

**Files:** `lib/features/approvals/presentation/**`, router only if a detail
route is needed.

- Keep `ApprovalsScreen` on `CubitListSurface`; add status filter chips
  (all/pending/approved/denied/cancelled), a create FAB, and a detail sheet
  showing title, kind, description, status, decision note/time.
- Decide actions visible only when the session's active-org role is partner;
  cancel visible to the requester. The server is the authority; a denied call
  renders the typed error, never a success.
- Create form: title (required, 2–160), kind dropdown, optional matter picker
  (reuse the matter list gateway), optional description.
- Empty/error states and honest copy ("requests are stored for this
  organization").

---

### Task 7: l10n + tests + gates

- Add en/ar/tr keys for every new string; `flutter gen-l10n`;
  `verify_arb_parity.sh` PASS.
- Widget tests: list renders, filter switches, create validation, decide
  success/denial, cancel; gateway unit tests for mapping and error paths.
- Gates: format, analyze, full `flutter test`, ledger, ARB, policy `--check`.
- Update `README.md` counts + feature paragraph, `supabase/README.md` layout /
  apply order / battery table.
- Commits: backend, client, docs (explicit pathspecs, no push).

**STOP list:** any need to widen an existing policy; any decision authority
other than partner; any change to the `matters` schema; live apply.
