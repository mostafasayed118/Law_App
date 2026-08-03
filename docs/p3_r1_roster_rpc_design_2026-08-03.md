# LegalHub — Phase 3 R1: Partner-Scoped Member-Metadata RPC (Design, NOT APPROVED)

> **Record type:** The RLS-gate design review artifact for Phase 3, R1 — the
> partner-scoped member-metadata RPC (`list_org_members_metadata`). **Docs
> only.** No schema, RPC, policy, grant, or dev-project change is created,
> applied, or authorized by this document. The SQL here is an *illustrative
> design sketch for review*, not an executable migration. Following the P2
> discipline gate: **design → review → rehearsal → approval → apply →
> verify → close**; this document is step 1 (design, awaiting owner review).
>
> **Status:** **DESIGNED (2026-08-03) — NOT APPROVED, NOT IMPLEMENTED.**
> Owner review pending. Nothing reaches `supabase/` or the dev project until
> the rehearsal plan (`docs/p3_r1_rehearsal_plan_2026-08-03.md`) passes
> against an ephemeral project and the owner records explicit apply
> approval.
>
> **Date:** 2026-08-03.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/features_roadmap_2026-08-03.md` §5 (Phase 3 gate:
> full P2 discipline) · `docs/p2_schema_rls_design.md` §5.1/§5.3/§7/§8 (the
> RPC/RLS pattern, R-4 policy-evaluation grants, rollback pairing) ·
> `docs/permission_matrix.md` §2 (D-T6 addendum, 2026-08-01), §7 (dated
> addendum discipline) · `docs/p3_organization_membership_spec_2026-08-03.md`
> §5 (R1) · `docs/p3_phase2_scope_2026-08-03.md` §3/§5 (R1 extension:
> invitation id) · `docs/rollback_plan.md` §1/§2/§5 ·
> `docs/tracked_deviations.md` (D-T6) · `docs/adr/0007`.

---

## 1. Gate position

| Phase 3 gate step (P2 discipline) | Artifact | Status |
|---|---|---|
| Spec record | R1 in `docs/p3_organization_membership_spec_2026-08-03.md` §5; R1 extension in `docs/p3_phase2_scope_2026-08-03.md` §3/§5 | ✅ Recorded |
| RLS-gate design review | **This document** + matrix §2 addendum (2026-08-03) | ⏳ **Awaiting owner review** |
| Ephemeral rehearsal with evidence (r-series) | `docs/p3_r1_rehearsal_plan_2026-08-03.md` | 📋 Plan written; **not executed** (needs design approval to run) |
| Dated apply-approval record | (none yet) | ⛔ Not started — blocked on rehearsal pass |
| Apply execution with rollback pairing | (none yet) | ⛔ Not started |
| Matrix addendum before it ships | §2 addendum inserted into `docs/permission_matrix.md` (2026-08-03) | ✅ Authored (PROPOSED; takes effect on apply approval) |

**Constraint reminder:** no schema/RPC/policy change on the dev project, no
implementation code, no service-role key, no real data, and **no new RPC
beyond the one reviewed amendment** (Q5 surface minimality) until rehearsal
passes and apply approval is recorded.

---

## 2. Scope: what this amendment is (and absorbs)

One new RPC, which resolves three recorded threads with a single reviewed
surface:

| Recorded thread | Where | Resolution in this design |
|---|---|---|
| **R1** — member-facing roster RPC does not exist (`list_members_metadata` is platform-owner-only) | P3 spec §5 R1 | The new partner-scoped RPC becomes the member-facing roster read for partner sessions |
| **R1 extension** — invited rows and their `invitation_id` are not readable through any member-facing RPC (Phase 2.1 Resend/Revoke are fake-real for partners today) | Phase 2 scope note §3/§5 | The new RPC unions pending `invitations` and exposes `invitation_id` |
| **D-T6 forward hook** — partner display-name access reserved as "a separate reviewed RPC decision" (profiles is own-row-only) | Matrix §2 addendum 2026-08-01; roadmap 3.2 | The new RPC returns `display_name`/`locale` from `profiles` under a single in-body guard — **absorbing roadmap 3.2** (no second RPC; Q5 minimality) |

**Explicitly out of scope:** R2/3.3 invite emails (provider config, separate
slice), deep-link acceptance (Phase 4), any policy change, any other RPC, any
client code. The Phase 3 client slice that consumes this RPC (gateway
mapping, partner-session routing) is a **post-approval** slice and is not
designed here — only the server contract it must consume (§8).

---

## 3. Proposed signature (illustrative sketch — NOT executable)

```sql
-- supabase/rpc/list_org_members_metadata.sql (proposed; naming provisional)
-- Backout: rpc/_down.sql (amended, §9).
--
-- Partner-scoped member-metadata read for ONE organization: members with
-- identity metadata (display_name, locale) + membership metadata (role,
-- status, timestamps) + pending invitations with their invitation id.
-- The read itself is audited. No direct SELECT grant exists on profiles
-- beyond own-row; this RPC is the only widened path (D-T6 pair, §6).

create or replace function public.list_org_members_metadata(p_organization_id uuid)
returns table (
  organization_id uuid,             -- always p_organization_id
  user_id         uuid,             -- members only; NULL for invited rows
  invitation_id   uuid,             -- pending invites only; NULL for members (R1 extension)
  email           text,             -- invited address for invited rows; NULL for members
  display_name    text,             -- profiles.display_name; NULL for invited rows
  locale          text,             -- profiles.locale; NULL for invited rows
  role            public.org_role,
  status          public.membership_status,  -- 'invited' for invitation rows
  created_at      timestamptz,
  updated_at      timestamptz
)
language plpgsql security definer set search_path = public as $$
begin
  if not public.has_org_role(p_organization_id, 'partner') then
    raise exception 'permission denied';
  end if;

  perform public.write_audit(
    'partner:list_org_members', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type => 'membership',
    p_redacted_summary => 'member metadata listing for org'
  );

  return query
    -- members: membership metadata joined with identity metadata (LEFT JOIN +
    -- COALESCE — defensive against orphan memberships: a membership whose
    -- profiles row is missing still appears, with a static fallback name,
    -- instead of dropping the roster row)
    select m.organization_id, m.user_id, null::uuid, null::text,
           coalesce(p.display_name, 'Unknown member'), coalesce(p.locale, 'en'),
           m.role, m.status, m.created_at, m.updated_at
      from public.memberships m
      left join public.profiles p on p.user_id = m.user_id
     where m.organization_id = p_organization_id
    union all
    -- pending invitations only: revoked/expired/accepted rows leave the roster
    select i.organization_id, null::uuid, i.id, i.email,
           null::text, null::text, i.role, 'invited'::public.membership_status,
           i.created_at, i.created_at
      from public.invitations i
     where i.organization_id = p_organization_id
       and i.status = 'pending'
   order by organization_id, status, display_name nulls last, email;
end;
$$;

revoke execute on function public.list_org_members_metadata(uuid) from public, anon;
grant execute on function public.list_org_members_metadata(uuid) to authenticated;
```

Design choices embodied in the sketch:

- **`status = 'invited'`** maps `invitations` onto the client's existing
  `MembershipStatus.invited` — the roster shape is unchanged for the client;
  invited rows are distinguished by `invitation_id IS NOT NULL`, not by
  status alone.
- **Pending invites only** — matches the Phase 2.1 behavior (revoke removes
  the invited row; accepted invites become memberships; expired invites are
  not roster rows).
- **No token material** — `invitations.token_hash` and the literal one-time
  token are never in the output (Q2 discipline untouched).
- **No `is_platform_owner()` OR-branch** — the guard is exactly
  `has_org_role(..., 'partner')`. The owner capability deliberately does not
  widen this RPC; the owner surface stays `list_members_metadata` (audited
  separately). Two distinct surfaces, no capability creep.
- **Audit on success only** — the guard failure raises
  `'permission denied'` with no audit row, identical to every applied RPC;
  the allowed read writes one redacted audit row.
- **Orphan-membership defense** — the member branch is a **LEFT JOIN** with
  **COALESCE** on `profiles` (`'Unknown member'` / `'en'` fallbacks): a
  membership row is never dropped from the roster over a missing profile
  row, and the fallback is a static, redaction-safe string (no uuid, no
  email — ADR-0003). The signup trigger normally guarantees the profile
  row; this is belt-and-braces, not a new identity surface.

---

## 4. SECURITY DEFINER or not — decision and justification

**Decision: SECURITY DEFINER**, matching every other client-reachable RPC in
the applied surface (§5.3 of the gate-approved design).

**Why definer (not invoker):**

1. **The D-T6 boundary makes invoker impossible without a policy widening.**
   `profiles` is own-row-only by gate-approved design and matrix amendment.
   A security-invoker body's `join profiles` would return NULL
   `display_name` for every member except the caller — or, to fix that, we
   would have to widen the `profiles` policy, which is precisely what D-T6
   forbade. The D-T6 resolution direction is a *reviewed RPC* crossing
   profiles under an in-body guard — that IS a definer function.
2. **Invoker semantics would silently widen the roster read.** The
   `memberships` policy (`is_active_member(organization_id) or auth.uid() =
   user_id`) would let ANY active member read the raw roster through this
   RPC, defeating the partner-only scope the amendment requires.
3. **Audit write needs definer context** (`write_audit` is not callable by
   `authenticated`; the R-3/R-4 grant surface must not change, §5).
4. **Consistency:** the entire §5.3 client-reachable surface is security
   definer with pinned `search_path` + explicit in-body guard. A lone
   invoker RPC would be a new pattern in the review surface for no gain.

**Definer risk mitigation (the guard is the entire boundary, so it must be
single-point and self-scoped):**

- Single guard, one helper: `has_org_role(p_org, 'partner')` — the same
  helper the `invitations` policy uses; no duplicated logic.
- Self-scoped by construction: `active_membership` resolves the caller's
  role from `auth.uid()` + `status = 'active'` — a caller cannot assert any
  role or org other than their own live membership (contract §3.3; the
  suspended/removed-never-authorize rule is built into the helper).
- Org-bounded: the client-supplied `p_organization_id` is accepted only when
  it matches the caller's own active partner membership; a cross-org or
  nonexistent id yields the same `'permission denied'` (contract §3.4 —
  no enumeration).
- No dynamic SQL, pinned `search_path = public`, no `SECURITY DEFINER` with
  owner rights beyond the four tables the body reads.

**R-4 lesson — policy-evaluation grants (why none are needed here):** the
R-4 rehearsal finding was that RLS policy quals execute as the *querying*
role, so `is_active_member`/`has_org_role` needed `authenticated` EXECUTE
for policy-gated reads to work. That lesson does **not** create new grant
requirements for this RPC: it is security definer, so its internal calls to
`has_org_role` and `write_audit` execute in **definer context** — the caller
never invokes them. The only new grant in this amendment is
`authenticated` EXECUTE on the one new function. The policy-evaluation grant
inventory is asserted **byte-equal** before/after in the rehearsal (§6).

**R-3 hardening interplay:** `alter default privileges` already revoked
anon/authenticated EXECUTE on new public functions, so the new function
inherits **no implicit grant**. The explicit
`revoke ... from public, anon; grant ... to authenticated` pair is the
entire grant surface; `service_role` retains EXECUTE (trusted backend),
unchanged.

---

## 5. Grants (default-deny)

| Role | EXECUTE on the new RPC | Notes |
|---|---|---|
| `anon` | ❌ denied | explicit revoke + no public grant |
| `authenticated` | ✅ granted | the **only** grant (every client session reaches the guard; the guard decides) |
| `service_role` | ✅ (trusted backend) | unchanged from hosting defaults — never used by the client |
| `public` | ❌ denied | explicit revoke |
| RLS policy-evaluation grants (`is_active_member`, `has_org_role`) | unchanged | byte-equal assertion in rehearsal; R-4 surface untouched |
| Table grants (`\dp`) | unchanged | no policy change; no new table grant |

---

## 6. RLS analysis

**Who may call:** any `authenticated` session whose **active** membership in
`p_organization_id` carries role `partner`. That is the complete allow set.

**Default-deny:** nothing else — not anon, not non-partner members, not the
owner, not a suspended/removed partner.

### Negative cases (each must deny; each is a rehearsal row)

| Case | Why it denies |
|---|---|
| `client`/`attorney`/`compliance_officer` (active, org-a) | guard: `has_org_role(org-a, 'partner')` false. **Own-row-only does not apply — the RPC denies them entirely** (their §3 own-org roster read remains the raw-policy path, unchanged) |
| Cross-org: `partner@org-a` with `p_organization_id = org-b` | guard resolves the org from the caller's own membership; org-b is not their partner org → same `'permission denied'` as a nonexistent org (no enumeration) |
| Suspended partner (org-a) | `active_membership` filters `status = 'active'` — suspended never authorizes, stale client session notwithstanding |
| Removed partner (org-a) | same — removed never authorizes |
| anon / expired session | no EXECUTE grant → denied before the guard |
| `platform_owner_admin` with no partner membership in org-a | `is_platform_owner()` is deliberately not part of the guard (§3); the owner surface stays `list_members_metadata` |
| Invitation rows of another org | the union is bounded by `where organization_id = p_organization_id`, which is already partner-guarded — cross-org invites are unreachable |

### Positive cases (each must pass; each is a rehearsal row)

| Case | Expected output |
|---|---|
| `partner@org-a` calls with org-a | full roster: members (display_name, locale, role, status, timestamps) + pending invites (invitation_id, email, role `invited`) |
| Invitation ids present | every invited row carries `invitation_id`; every member row carries NULL (R1 extension) |
| Invited email ≠ profile data | invited rows carry `email`; display_name/locale NULL (no fabricated identity) |
| The caller's own row | present in the roster (partner is a member) |
| Orphan-membership defense (LEFT JOIN + COALESCE) | a membership whose `profiles` row is missing still appears, with the static fallback `'Unknown member'`/`'en'` — no row dropped, no error, no uuid/email leakage |

**No policy change — the D-T6 pair (the pivotal assertion):**
`profiles` stays own-row-only **and** the RPC returns other members' names.
The rehearsal asserts both sides of the pair:

1. `partner@org-a`: `select * from profiles where user_id = <other member>` →
   **0 rows** (raw table still own-row-only).
2. `partner@org-a` calls `list_org_members_metadata(org-a)` → the other
   member's `display_name` **is present** in the RPC output.

The RPC is thus proven to be the **only** widened path — the exact
"separate reviewed RPC decision" the 2026-08-01 matrix addendum reserved.

---

## 7. Audit

- Allowed read → one `audit_events` row: `action = 'partner:list_org_members'`,
  `outcome = 'allowed'`, org-scoped, `redacted_summary` is a static reason
  string (no names, no tokens, no PII — ADR-0003).
- Denied call → `'permission denied'` exception, no audit row (parity with
  every applied RPC; denials are not enumerated into audit).

---

## 8. Client contract (recorded forward hook — NOT implemented here)

The Phase 3 client slice (post-approval) must map this contract:

| Row kind | `user_id` | `invitation_id` | `email` | `display_name` | Client mapping |
|---|---|---|---|---|---|
| Member | uuid | NULL | NULL | profile name | existing `OrgMember` mapping (unchanged) |
| Invited | **NULL** | uuid | invited address | NULL | map by `invitation_id`/`email`; roster status chip `invited`; Phase 2.1 Resend/Revoke target `invitation_id` (becomes **real** for partners against production) |

- Partner sessions route `OrganizationGateway.listMembers` to this RPC;
  non-partner sessions keep today's behavior (fake-real — unchanged, per
  this amendment's scope); owner sessions keep `list_members_metadata`
  (unchanged).
- **Denial mapping (confirmed for the client slice):** the RPC raises the
  same generic `'permission denied'` text as every applied RPC, and the
  client must map it through the existing `_kindFor` convention to the
  generic **`denied`** `AppError` kind (the established P3 mapping — P3
  spec §3 "Error mapping"; no new failure kind is introduced by this RPC).
  The denial is non-enumerating by construction (§4): cross-org,
  non-partner, suspended/removed, and owner-no-bypass are
  indistinguishable to the caller.
- The current fake's invited-row convention (`userId = email`) is a client
  mapping detail to reconcile in that slice; it does not constrain the
  server contract above.

---

## 9. Rollback pairing and trigger conditions

| Forward artifact | Paired backout | Verification that rollback restored prior state |
|---|---|---|
| `supabase/rpc/list_org_members_metadata.sql` | `rpc/_down.sql` amended with `drop function if exists public.list_org_members_metadata(uuid);` (the file's blanket `revoke execute on all functions in schema public from authenticated` already covers the grant) | RPC inventory returns to 17; `has_function_privilege('authenticated', ..., 'EXECUTE')` on the dropped name → false; `\df public.*` back to the P2 set; `pg_default_acl` byte-equal; policy reads still work (R-4 canary) |

**Trigger conditions (rollback_plan §5 + this amendment's own):** any of
these = immediate revert, never fix-forward:

- Any negative row in §6 starts **passing** (a denial that should happen,
  doesn't).
- Any credential, token, or PII appears in logs/audit where it shouldn't —
  including the one-time invite token or `token_hash` in RPC output.
- Cross-tenant data becomes visible (e.g. org-b rows in org-a's output).
- **Q5 minimality trigger (this design):** if rehearsal reveals a need for a
  **second** RPC or any policy change, the run stops and a **new amendment
  review** is required — the reviewed amendment is not expanded
  fix-forward.

---

## 10. Owner review checklist

Confirm, then record the design review result (approve → run rehearsal;
reject → amend this doc):

1. Signature, return shape, and the invited-row mapping (§3).
2. SECURITY DEFINER justification and the R-4 non-impact analysis (§4).
3. Grant surface: authenticated EXECUTE only; no new policy-evaluation
   grants; no table-grant or policy change (§5).
4. Negative cases complete: non-partner denied, cross-org denied,
   suspended/removed never authorize, owner no-bypass, anon denied (§6).
5. The D-T6 pair is asserted in rehearsal (names via RPC only; profiles
   stays own-row-only) (§6, rehearsal plan §4).
6. Rollback pairing + trigger conditions, including the Q5 minimality
   trigger (§9).
7. The matrix §2 addendum (2026-08-03) and roadmap update
   (`docs/features_roadmap_2026-08-03.md`: Phase 3 → DESIGNED) reflect this
   design exactly.

---

## 11. What this document does NOT authorize

- No Supabase project change, migration, RPC, policy, grant, or config —
   nothing here has been or will be run.
- No implementation code (`supabase/`, `lib/`, `test/` untouched).
- No dev-project change of any kind until the rehearsal
   (`docs/p3_r1_rehearsal_plan_2026-08-03.md`) passes against an ephemeral
   project and the owner records dated apply approval.
- No second RPC, no policy widening, no invite emails (R2), no deep links
   (Phase 4), no real data, no service-role key, no compliance claim.

**Next step:** owner review of this design + the matrix §2 addendum +
rehearsal plan. On approval, the rehearsal plan runs ephemeral-only and
produces the r-series evidence; apply to the dev project happens only under
a separate dated apply-approval record.
