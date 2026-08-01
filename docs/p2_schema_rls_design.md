# LegalHub — P2 Schema & RLS Design (Discovery Draft)

> **Record type:** Discovery draft for the **mandatory Supabase/RLS review
> gate** (bootstrap spec §6/§9) and the separate **P2 approval**
> (`docs/p0_decision_capture.md` §3, **recorded 2026-08-01**). **Docs-only.**
> No schema, migration, RLS policy, storage policy, RPC, edge function,
> storage bucket, realtime channel, or production configuration is created,
> applied, or authorized by this document. The SQL here is an *illustrative
> design sketch for review*, not an executable migration.
>
> **Status:** **APPROVED (2026-08-01)** as the RLS-gate review artifact.
> §8 decisions Q1–Q6 are answered below; P2 approval is recorded in
> `docs/p0_decision_capture.md` §3. This still authorizes **no** Supabase
> change — reviewed migrations remain a separate approved slice.
>
> **Date:** 2026-08-01.
>
> **Governed by:** `docs/auth_tenant_authorization_contract.md` §7/§9/§11-P2 ·
> `docs/p0_decision_capture.md` §1 (D-05, D-06, D-10a, D-10b), §3 ·
> `docs/permission_matrix.md` · `docs/rollback_plan.md` §1/§2 ·
> `docs/gate3_decision.md` §5 · `docs/adr/0007`.

---

## 1. Gate position

| Precondition (P2) | Status |
|---|---|
| All §10 blockers relevant to identity/tenant decided (D-02, D-03, D-04, D-07, D-08, D-09) | ✅ Decided (`p0_decision_capture.md` §1, 2026-07-31) |
| P2-specific decisions: retention/deletion (D-05), human authority (D-06), invitation (D-10a), support access (D-10b) | ✅ Decided (2026-07-31) |
| Non-production Supabase project available | ✅ Provisioned (`eu-central-1`, zero tables) |
| Signed permission matrix (positive **and** negative) | ✅ `docs/permission_matrix.md` |
| Retention/deletion/audit documented for touched data | ✅ D-05 + contract §8 |
| Rollback plan for schema/policy/config/client | ✅ `docs/rollback_plan.md` |
| **P1 complete** (the §3 "blocked on P1 completion" precondition) | ✅ **Now satisfied** — Batch 3.1–3.3 committed and pushed (`1042daf`, `b1ae361`/`88c3005`, `cc917b7`/`e8c70b9`/`d18b2c7`) |
| Mandatory Supabase/RLS review gate (bootstrap spec §6/§9) | ✅ **Passed (2026-08-01)** — §8 Q1–Q6 answered; this draft is the review record |
| Explicit P2 approval in `p0_decision_capture.md` §3 | ✅ **Recorded (2026-08-01)** — see §3 |

**Conclusion:** the decision-level preconditions for P2 are fully satisfied.
The RLS-gate review passed on 2026-08-01 (§8 decisions answered) and the P2
approval is recorded in `p0_decision_capture.md` §3. What remains before any
Supabase change is authoring the reviewed migrations as a separate approved
slice.

---

## 2. Scope

**In scope (contract §11 P2 — "only the approved identity/profile,
organization, membership, invitation, and audit concepts"):**

- `profiles` — application identity/profile data beside `auth.users`.
- `organizations` — the tenant boundary.
- `memberships` — identity ↔ organization with org-scoped role + lifecycle.
- `invitations` — membership provisioning.
- `audit_events` — append-only, redacted access/change record.
- RLS, narrow RPCs, and policy tests proving cross-tenant denial.

**Explicitly out of scope for the P2 schema:**

- Matters, documents, messages, payments, conflicts, filings, AI/analytics —
  these are P2+ per `permission_matrix.md` §4 (scaffolded there for
  completeness, but no table is proposed in P2).
- Storage buckets and realtime channels — **none exist** on the dev project
  (zero tables verified 2026-08-01). The *policy posture* for them is
  specified in §5 so the first bucket/channel ships with default-deny
  policies, but no bucket/channel policy is created now (deferral confirmed,
  Q4).
- Real client/legal data, production config, service-role usage, or any
  compliance claim.

---

## 3. Vocabulary reconciliation (code ↔ schema)

The schema must map onto the already-shipped domain shapes so the client
boundary and the server boundary agree.

| Domain type (code) | Schema target |
|---|---|
| `Session.userId` | `auth.users.id` (never an email — contract §3.1) |
| `Session.memberships` | `memberships` rows joined by `user_id` |
| `Session.expiresAt` | Provider session expiry (GoTrue), not a table column |
| `OrganizationMembership {organizationId, organizationName, role, status}` | `memberships` row; `organizationName` derived via join to `organizations.name` |
| `MembershipStatus {invited, active, suspended, removed}` | `membership_status` enum — **same four values** |
| `UserRole.client/attorney/partner/complianceOfficer` | `org_role` enum — **four MVP values** (D-09) |
| `UserRole.researchAnalyst, admin` | **Not org roles in MVP** (D-09); remain code-candidate vocabulary, excluded from the matrix and the schema enum |
| `platform_owner_admin` (p0 Addendum) | **Not a table role** — a single-account capability, source of truth in `platform_config.owner_user_id` (§4), enforced by RLS function |

**Reconciliation flag:** `lib/core/roles/user_role.dart` still declares all
six enum values including `researchAnalyst` and `admin`. That is fine today
(UX vocabulary, not authorization — the file's own doc comment says so), but
the P2 schema enum will contain **four** values. This mismatch is intentional
and documented here; it must not be "fixed" by adding non-MVP roles to the
schema, and the code-side capability map remains UX-only until P3.

---

## 4. Proposed schema sketch (illustrative, NOT executable)

> These DDL snippets exist **only to be reviewed**. They are not migrations,
> have not been run, and will be re-authored as reviewed migration files only
> after P2 approval. Naming is provisional.

### 4.1 Enums

```sql
create type public.org_role as enum
  ('client', 'attorney', 'partner', 'compliance_officer');

create type public.membership_status as enum
  ('invited', 'active', 'suspended', 'removed');

create type public.invitation_status as enum
  ('pending', 'accepted', 'expired', 'revoked');
```

### 4.2 `profiles` — application identity beside `auth.users`

```sql
create table public.profiles (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  locale       text not null default 'en',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
```

- Row is created by a **security-definer signup trigger** on `auth.users`
  (the client cannot insert an arbitrary profile — contract §7 INSERT rule).
- RLS: `select`/`update` **own row only** (`auth.uid() = user_id`). No
  cross-user read except the narrow metadata paths in §5.

### 4.3 `organizations` — tenant boundary

```sql
create table public.organizations (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_by uuid references public.profiles (user_id) on delete set null,
  created_at timestamptz not null default now()
);
```

- `created_by` is server-derived from `auth.uid()` (D-08: the first member to
  create the org becomes its initial `partner`). It is an **attribution
  reference, not ownership**: `on delete set null` so D-05's hard-delete of
  an identity never fails on the FK, while the org survives with the creator
  attribution cleared (audit retains the redacted actor).
- RLS: `select` if the session has an **active** membership in the org.

### 4.4 `memberships` — identity ↔ organization, role + lifecycle

```sql
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
```

- **The client never supplies `role`, `status`, or `created_by`** — all are
  server-derived (contract §2 #2, §7). `created_by` records the acting
  partner for auditability (contract §3.3) and is `on delete set null` so an
  actor's account deletion never blocks D-05's hard-delete.
- `role` changes and `status` transitions go through a **narrow RPC**
  (§5.3) that records an audit event — the client has no direct
  UPDATE/DELETE on this table.

### 4.5 `invitations` — membership provisioning (D-10a)

```sql
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
  where status = 'pending';   -- one pending invite per (org, email); re-invite only after expired/revoked
```

- Invite role and organization are **server-owned** (contract §6); a client
  cannot choose a stronger role.
- Only the literal token (returned to the inviter once) can be redeemed —
  via a narrow security-definer RPC that binds the authenticated identity to
  `accepted_by` and creates the membership (contract §6).

### 4.6 `audit_events` — append-only, redacted (contract §8)

```sql
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
```

- **Append-only:** no UPDATE/DELETE policies exist, ever; rows are written by
  security-definer RPCs/triggers only. `actor_user_id` is **nullable and
  `on delete set null`** for two reasons: system events (signup trigger,
  expired-invitation cleanup) have no authenticated actor, and contract §8
  says account deletion (D-05) does **not** delete audit rows — the actor
  reference clears while `redacted_summary` and the correlation id survive.
- `platform_owner_admin` reading the audit table is itself an audited action
  (§5.2).

### 4.7 `platform_config` — single-account capability source of truth

```sql
create table public.platform_config (
  id            boolean primary key default true check (id),  -- single row
  owner_user_id uuid not null references auth.users (id)
);
```

- The p0 Addendum capability is bound to **one** authenticated identity.
  Keeping it in a single-row table (rather than a hardcoded constant inside a
  function body) makes it auditable and changeable via a **reviewed, audited
  migration** — the change path is deliberate, not a runtime backdoor
  (Q1).
- RLS: no client access at all; read only by security-definer functions.

---

## 5. RLS design (default deny)

### 5.1 Helper functions (security definer, pinned search_path)

Every policy funnels through these so the "active membership" rule is
defined in **one** place (contract §3.3: one unambiguous active-membership
rule; suspended/removed never authorize anything):

```sql
create function public.active_membership(p_org uuid)
returns public.memberships
language sql stable security definer set search_path = public as $$
  select * from public.memberships
  where organization_id = p_org
    and user_id = auth.uid()
    and status = 'active'
  limit 1
$$;

create function public.is_active_member(p_org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.active_membership(p_org))
$$;

create function public.has_org_role(p_org uuid, p_role public.org_role)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.active_membership(p_org)
                 where role = p_role)
$$;

create function public.is_platform_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_config where owner_user_id = auth.uid())
$$;
```

### 5.2 Policy intent per table

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `profiles` | Own row only; `platform_owner_admin` may read **metadata** (name, locale) via narrow RPC, never via table scan | Signup trigger only (security definer) — no client INSERT | Own row only; no authority fields | No direct DELETE (account deletion via `delete_my_account` RPC, D-05) |
| `organizations` | `is_active_member(org)`; `platform_owner_admin` may list orgs (metadata RPC) | `create_organization` RPC only (server sets `created_by` = `auth.uid()`, creator becomes `partner`) | `partner` of org, via RPC with audit | No direct DELETE (org deletion is not an MVP action) |
| `memberships` | `is_active_member(org)` (members see their org's roster); own row always; `platform_owner_admin` metadata-only via RPC | RPC only (invite-acceptance, org creation) — never raw INSERT | **No direct UPDATE** — role/status changes via RPC (actor + audit) | **No direct DELETE** — via RPC with audit (D-06 authority) |
| `invitations` | `partner` of org | `partner` of org (D-10a) | `partner` of org (resend/revoke) via RPC with audit | No direct DELETE (status transitions instead) |
| `audit_events` | Scope-checked per reader (below) | Security-definer RPC/trigger only | **Never** | **Never** |
| `platform_config` | None (function-only access) | Migration-time only | Migration-time only | Never |

**Tenant isolation rule (contract §2 #3):** every policy that touches
org-scoped data resolves the organization from the **authenticated
membership**, never from a client-supplied `organization_id`. A guessed or
cross-tenant id yields the same denial as a nonexistent row (contract §3.4).

**Audit reader scope (contract §8):** `partner` reads their org's audit
rows; `platform_owner_admin` reads cross-org audit rows, and doing so is
itself audited; no other role reads audit.

### 5.3 Narrow RPC surface (proposed)

Each is security-definer, pins `search_path`, validates inputs, and writes
an audit event. This is the complete client-reachable surface — no raw
table mutation reaches the client:

- `create_organization(name)` → org + creator `partner` membership.
- `accept_invitation(token)` → validates hash/expiry/status, binds identity,
  creates membership (role server-owned).
- `invite_member(org, email, role)` / `resend_invitation(id)` /
  `revoke_invitation(id)` → `partner`-gated, audit each.
- `change_member_role(org, user_id, role)` / `suspend_membership` /
  `reactivate_membership` / `remove_membership` → `partner`-gated
  (D-06), audit each.
- `delete_my_account()` → cascade per D-05; **audit retained** (the actor
  FK is `on delete set null`, so identity hard-deletes while audit rows and
  their `redacted_summary` survive). Because `organizations.created_by` and
  the actor columns are `on delete set null`, no FK blocks the hard-delete
  for users who created orgs or acted on memberships.
- Platform metadata reads (`list_organizations_metadata`,
  `list_members_metadata`, `suspend_membership_platform`,
  `delete_demo_account`) → `platform_owner_admin`-gated, each audited.

**Negative test requirement (matrix §4):** `platform_owner_admin` must be
denied at the RLS layer on any matter/document/message content — there are
no such tables in P2, so this becomes a **deny-all-on-future-tables** guard
in the policy-test suite, not a row.

### 5.4 Storage / realtime posture (no objects yet)

Contract §7 requires storage and realtime to enforce the same scope as table
reads. Since the dev project has **zero buckets and zero channels**, P2 ships
no storage/realtime policy. Instead:

- The design commits the **pattern**: every future bucket's policies must be
  reviewed against this matrix before creation (Q4 confirmed), and
  signed URLs are short-lived, issued only after server-side scope
  validation (contract §7).
- The **policy-test suite** includes the future-facing negative tests
  ("guessed private object path denied", "realtime subscription across orgs
  delivers nothing") as executable checks once objects exist (matrix §6).

---

## 6. Positive / negative permission-matrix mapping

Contract §9: every matrix row needs ≥1 positive and ≥1 negative test with
synthetic identities and **at least two organizations** (`org-a`, `org-b`).
The P2 policy-test suite is organized as the matrix's execution plan:

| Matrix section | Representative row | Positive test (org-a) | Negative test |
|---|---|---|---|
| §2 Identity/session | View own profile | `client@org-a` reads own `profiles` row → 1 row | `client@org-a` reads `client@org-b`'s profile → 0 rows / deny |
| §2 | Edit own profile | Own row UPDATE succeeds | UPDATE with `user_id` ≠ `auth.uid()` → denied |
| §3 Org/membership | View own org member list | `client@org-a` selects memberships where `organization_id = org-a` | `client@org-a` selects with `organization_id = org-b` → 0 rows |
| §3 | Invite new member | `partner@org-a` calls `invite_member` → invitation + audit row | `client@org-a` calls `invite_member` → RPC denies |
| §3 | Change member's role | `partner@org-a` `change_member_role` succeeds + audit | `partner@org-a` `change_member_role` on a `org-b` membership → denied |
| §3 | Suspend/reactivate | `partner@org-a` suspends → membership `status = suspended` | Suspended membership's owner cannot read org data (stale client session notwithstanding) |
| §3 | Switch active org | Identity with memberships in both orgs selects own memberships | Selecting `org-b` context never bypasses `active_membership(org-b)` check |
| §4 Matter/doc (P2+) | Org role alone grants nothing | (no tables yet) | Future-table deny guard: any org role alone → denied on matter/doc reads |
| §5 `platform_owner_admin` | Metadata administration | Owner lists orgs/members metadata via RPC; each action audited | Owner reads matter/doc content → **denied**; owner action not in the permitted list → denied; the audit read itself is audited |
| §6 Storage/audit | Audit table read | `partner@org-a` reads `org-a` audit rows | `client@org-a` reads audit → denied; audit UPDATE/DELETE → denied for everyone |

Every positive has a paired negative; every row is enforceable server-side
only (matrix header note). The suite runs against `org-a`/`org-b` synthetic
fixtures with removed/suspended memberships per contract §11 P2.

---

## 7. Migration + policy rollback pairing

Per `docs/rollback_plan.md` §1/§2, extended to the P2 slice. The principle:
**every forward artifact ships with its backout, and rollback is rehearsed
in an ephemeral environment before any shared deployment** (contract §11 P2
exit).

| Forward artifact | Paired backout | Verification that rollback restored prior state |
|---|---|---|
| Migration `01_org_schema.sql` (enums, tables) | `01_org_schema.down.sql` (drop tables, enums) | `supabase db diff` before/after; schema equality |
| Migration `02_rls_functions.sql` (helpers) | `.down.sql` (drop functions) | Function inventory equal; policy suite still passes pre-P2 expectations |
| Policy files `policies/*.sql` (per-table, versioned in git, never edited in dashboard) | `git revert` of the policy commit | `permission_matrix.md` negative rows still deny; positive rows still allow only where pre-approved |
| RPCs (`rpc/*.sql`) | `.down.sql` (drop functions) | RPC grant list returns to prior set |
| `platform_config` seed (owner uid) | `.down.sql` (delete row) | `is_platform_owner()` false for everyone |

**Rehearsal:** before any shared/staging deployment, the full
up→down→verify sequence runs in an ephemeral Supabase project (or `db reset`
against the dev project with a confirmed-empty baseline), matching the
matrix §7 sign-off discipline. Trigger conditions from `rollback_plan.md` §5
apply: any negative row starting to pass = immediate revert, don't fix
forward.

---

## 8. Gate-review decisions (Q1–Q6, answered 2026-08-01)

Decisions recorded by the RLS-gate review. Owner for all:
`Project Owner (github.com/mostafasayed118)`, decided 2026-08-01.

1. **Q1 — `platform_config.owner_user_id` seeding: RESOLVED.** Seed by
   **migration with the verified owner `auth.users` id**, audited; no
   first-run RPC (keeps the client-reachable surface minimal). Subsequent
   changes require a reviewed migration — the deliberate path, not a
   runtime backdoor.
2. **Q2 — Invitation token hashing: RESOLVED.** Store a **sha-256 hash** of
   the one-time token; the literal token is shown to the inviter exactly
   once and never stored or logged in plaintext; 7-day expiry, single-use
   (D-10a).
3. **Q3 — `researchAnalyst`/`admin` code enum: RESOLVED.** The **four-value
   `org_role` enum is the MVP shape** (D-09). `researchAnalyst` and `admin`
   are not org roles and must not be added to the schema; the code-side
   enum stays as UX-only candidate vocabulary. Tracked as **D-T5** in
   `docs/tracked_deviations.md`.
4. **Q4 — Storage/realtime deferral: RESOLVED.** P2 ships **table RLS +
   audit only**; the first bucket/channel must pass a matrix review before
   creation (zero objects exist to protect).
5. **Q5 — No direct table mutation from the client: RESOLVED.** The entire
   client-reachable surface is the §5.3 RPC list; the only raw policy is
   own-profile SELECT/UPDATE. No MVP action needs a broader raw
   INSERT/UPDATE/DELETE.
6. **Q6 — System-actor audit convention: RESOLVED.** Machine-generated
   records (signup trigger, invitation-expiry cleanup) use a **null
   `actor_user_id` with a `system:` action prefix** (e.g.
   `system:profile_created`) to distinguish them from human actions; human
   actions always carry the authenticated actor.

---

## 9. What this draft does NOT authorize

- No Supabase project change, migration, policy, RPC, trigger, bucket,
  channel, or config — nothing here has been or will be run.
- No P2 "done" status: `p0_decision_capture.md` §3 P2 row stays `_OPEN_`
  until this review passes and the owner records approval.
- No P3/P4 work, no matter/doc schema, no real data, no service-role usage,
  no compliance claim.
- The code (`lib/`) is untouched by this document.

**Next step:** author the reviewed migrations (`01_org_schema.sql` +
paired `.down.sql`, RLS functions, policies, RPCs, seed) as a separate
approved slice — still nothing is applied to Supabase without a further gate.
