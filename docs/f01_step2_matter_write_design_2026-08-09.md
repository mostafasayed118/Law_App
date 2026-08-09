# LegalHub — F-01 Step 2 Design: Matter-Creation Slice with Platform-Owner Assignment Refusal (2026-08-09)

> **Record type:** implementation-ready **design** for **F-01 step 2** of
> `docs/p4_findings_register_2026-08-09.md` — the future matter-write slice
> whose matter-creation path must **refuse to assign the platform-owner id**,
> closing the only path that can create the state the Q4 residual warns about
> (content policies WOULD grant an assigned owner). This is the design that
> turns F-01's categorical owner-deny from an *operational invariant* into an
> *enforced guarantee*.
>
> **Status: DESIGN — APPROVED FOR BUILD 2026-08-09; artifacts BUILT and
> r1 REHEARSAL PASSED 2026-08-09 — NOT applied.** The slice was built from
> this design on 2026-08-09: `supabase/rpc/create_matter.sql`,
> `supabase/migrations/11_matter_write.sql` (+ `.down`),
> `supabase/tests/13_matter_write_rls.sql`, harness wiring (13 in the file
> list/loops, 11 in the apply order, §1c/§1d pins), and the battery-table
> row. The r1 rehearsal genuinely executed 2026-08-09 (evidence
> `docs/matter_write_slice_rehearsal_r1_2026-08-09.md`): `--apply` 44/44,
> full battery **82/0/0 ×2** on the ephemeral stack — battery 13's 16 blocks
> (RPC pos/neg, trigger INSERT + UPDATE arms + narrowness, §8 audit pos/neg,
> F2-D5 orphan, cross-org/anon/validation denials) all green, battery 12 no
> regression. **Mechanism/RLS-gate review PASSED 2026-08-09**
> (`docs/matter_write_slice_review_2026-08-09.md`) — findings R-1 (UPDATE
> arm unpinned) and R-2 (F2-D5 unpinned) remediated in-review via
> 13.14/13.15/13.16, then re-rehearsed 82/0/0 ×2.
> The SQL sketches below are now superseded by those rehearsal-ready files
> (which follow this design verbatim). **Apply remains gated**: mechanism/
> RLS-gate review → battery + harness `--check` → ephemeral rehearsal r1 →
> dated apply-approval → apply → matrix §4 addendum (design §8).
>
> **Owner:** Project Owner (github.com/mostafasayed118). **Date:** 2026-08-09.
> **Baseline:** `origin/main` @ `f16586e` + the uncommitted F-01 step 1 slice
> (battery 12, r1 PASSED 2026-08-09).
>
> **Governed by:** `docs/p4_findings_register_2026-08-09.md` (F-01) ·
> `docs/p4_threat_model_2026-08-09.md` (§4.6, §6.10) ·
> `docs/permission_matrix.md` §4/§5 (§7 dated-addendum discipline) ·
> `docs/p2_schema_rls_design.md` (RPC/RLS conventions) ·
> `docs/rollback_plan.md` · `INSTRUCTIONS.md` §2/§3/§4.3.

---

## 1. Problem and outcome

**Problem.** `matters` (04) is read-only today: no INSERT/UPDATE/DELETE grant,
no write policy, no creation RPC. The **first** future matter-write slice
must not open a path that seeds the platform-owner id into
`assigned_client_id`/`assigned_attorney_id` — because every content policy
(`matters_select_assigned` and all derivatives) would then **grant the owner
matter access** (the Q4 residual recorded verbatim in batteries 04.07/08.08).
Battery 12 (F-01 step 1) pins the invariant; this design makes the write path
**refuse it by construction**.

**Outcome.** When the matter-write slice ships, the platform-owner id cannot
be assigned to a matter through **any** path — the creation RPC refuses it
and a table-level trigger refuses it categorically — and the refusal is
pinned by battery rows (positive + negative) plus a §8 audit negative,
exactly per the repo's matrix/§9 contract.

## 2. Scope and non-goals

**In scope (this design):**
- the `create_matter` RPC contract + its in-function gates (creator role,
  **owner-assignment refusal**, active-member assignee guard);
- the categorical `BEFORE INSERT OR UPDATE` trigger on `matters`;
- the battery file `13_matter_write_rls.sql` (check rows + SQL sketches);
- the harness/docs wiring list; the gate sequence to apply.

**Explicit non-goals (out of scope):**
- any matter **UPDATE** path (status changes, re-assignment, edit) — a future
  slice with the same refusal discipline;
- the client-side matter-creation UI (env-gated client swap — a separate
  approved slice after the server surface applies);
- changing the read policies, the assignment model, or `matters` columns;
- the undefined partner/`compliance_officer` **oversight** mechanism
  (D-MR5/D-DR5 — unchanged, still future work).

## 3. Design decisions

| ID | Decision | Rationale |
|---|---|---|
| **F2-D1** | Creator must be an **active partner of the org** (`has_org_role(org,'partner')`) | Partner owns org oversight (D-06); conservative default; the org id is a routing hint — membership re-derived server-side (D-08). **Flagged for owner confirmation (§9 Q1)** — the general "who may create matters" policy is undefined (D-MR5). |
| **F2-D2** | **Owner-assignment refusal in the RPC** (the F-01 step 2 core): raise unless `assigned_client_id`/`assigned_attorney_id` ≠ `platform_config.owner_user_id`, **derived** (not hardcoded — same self-updating pattern as battery 12) | Directly closes the Q4 state at the RPC boundary. Constant, non-enumerating message (mirrors the `delete_demo_account` self-refusal style). |
| **F2-D3** | **Categorical trigger**: `refuse_platform_owner_assignment()` `BEFORE INSERT OR UPDATE` on `matters` | Converts the invariant into a data-layer guarantee for **every** path — RPC, seeds, future policy INSERT, manual fix. The trigger is narrow (owner-assignment only), so the existing demo-seed path (non-owner assignees) stays viable. EXECUTE revoked from client roles; the function runs via the trigger only (the 02 helper pattern). |
| **F2-D4** | Assignees must be **active members of the org** | An assignee without an active membership creates a *dead assignment* (the read gate is `is_active_member AND assignment`, so a non-member assignee could never read the matter). Mirrors the `invite_member` existing-member guard. **Note:** this check queries `memberships` directly inside the definer body — it must **not** use `is_active_member()` (that helper is `auth.uid()`-self-scoped by the F-11 rule). |
| **F2-D5** | Both assignments **nullable at creation** (schema permits it) | A matter may start with one side unset and be completed by a future update slice; `matters_select_assigned` handles nulls naturally. |

## 4. RPC: `create_matter` (contract + sketch)

```sql
-- rpc/create_matter.sql — REHEARSAL-READY candidate (NOT yet created; this is the design sketch)
-- F-01 step 2 (docs/f01_step2_matter_write_design_2026-08-09.md): F2-D1/D2/D4.
-- Backout: rpc/_down.sql drop; git-revert of the trigger block (design §8).

create or replace function public.create_matter(
  p_organization_id    uuid,
  p_title              text,
  p_practice_area      text,
  p_assigned_client_id   uuid default null,
  p_assigned_attorney_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_owner  uuid;
  v_matter uuid;
begin
  -- F2-D1: active partner of the org (D-08: re-derive, never trust the arg alone).
  if not public.has_org_role(p_organization_id, 'partner') then
    raise exception 'permission denied';
  end if;

  -- F2-D2 (F-01 step 2 core): the platform owner is never assignable.
  select owner_user_id into v_owner from public.platform_config limit 1;
  if p_assigned_client_id = v_owner or p_assigned_attorney_id = v_owner then
    raise exception 'platform owner cannot be assigned to a matter';
  end if;

  -- F2-D4: assignees must be active members of the org (dead-assignment guard;
  -- direct memberships query — is_active_member is auth.uid()-self-scoped, F-11).
  if p_assigned_client_id is not null and not exists (
    select 1 from public.memberships
     where organization_id = p_organization_id
       and user_id = p_assigned_client_id
       and status = 'active'
  ) then
    raise exception 'assigned client must be an active member of the organization';
  end if;
  if p_assigned_attorney_id is not null and not exists (
    select 1 from public.memberships
     where organization_id = p_organization_id
       and user_id = p_assigned_attorney_id
       and status = 'active'
  ) then
    raise exception 'assigned attorney must be an active member of the organization';
  end if;

  -- Title/practice_area validation: title trimmed non-empty (mirror
  -- create_organization); practice_area is enforced by the 04 CHECK
  -- (CHECK = mapping contract; a bad value raises and maps to a generic error).
  if p_title is null or trim(p_title) = '' then
    raise exception 'matter title is required';
  end if;

  insert into public.matters
    (organization_id, title, practice_area, status,
     assigned_client_id, assigned_attorney_id)
  values
    (p_organization_id, trim(p_title), p_practice_area, 'open',
     p_assigned_client_id, p_assigned_attorney_id)
  returning id into v_matter;

  -- §8 audit (contract): redacted summary only — never the title.
  perform public.write_audit(
    'matter:create', 'allowed',
    p_organization_id => p_organization_id,
    p_resource_type   => 'matter',
    p_resource_id     => v_matter,
    p_redacted_summary => 'matter created'
  );

  return v_matter;
end;
$$;

revoke execute on function public.create_matter(uuid, text, text, uuid, uuid) from public, anon;
grant execute on function public.create_matter(uuid, text, text, uuid, uuid) to authenticated;
```

**Contract notes.** Signature returns the new matter id (the audited-send
pattern: the RPC returns the persisted id; the client then reads through the
existing SELECT surface). All refusals are typed raises; the client seam maps
them to localized messages (the `OrganizationGateway` failure-mapping
pattern). The `create_matter` grant is `authenticated`-only; anon denied.

## 5. Categorical hardening: trigger (sketch)

```sql
-- migrations/11_matter_write.sql — REHEARSAL-READY candidate (NOT yet created)
-- F2-D3: the data-layer guarantee — no path can assign the owner to a matter.
-- Rollback: 11_matter_write.down.sql (drop trigger + function).

create or replace function public.refuse_platform_owner_assignment()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid;
begin
  select owner_user_id into v_owner from public.platform_config limit 1;
  if new.assigned_client_id = v_owner or new.assigned_attorney_id = v_owner then
    raise exception 'platform owner cannot be assigned to a matter';
  end if;
  return new;
end;
$$;

-- Trigger-invoked only; never client-callable (the 02 helper pattern).
revoke execute on function public.refuse_platform_owner_assignment() from public, anon, authenticated;

drop trigger if exists matters_refuse_owner_assignment on public.matters;
create trigger matters_refuse_owner_assignment
  before insert or update on public.matters
  for each row execute function public.refuse_platform_owner_assignment();
```

**Why both layers.** The RPC refusal (F2-D2) is the primary, audited path and
gives a clean typed error; the trigger (F2-D3) is the backstop that makes the
guarantee categorical (it fires for the connection role too, so even a
seed/manual INSERT with the owner id fails loudly — exactly the drift battery
12 is designed to catch). Belt-and-braces, in the repo's style (defense-in-
depth the RLS-gate reviews already favor).

## 6. Battery: `13_matter_write_rls.sql` (check rows + sketches)

New battery file, run after `00_fixtures.sql` + 12 (owner derived from
`platform_config`; fixture users: owner `10000000-…-0001`, partner-a
`…-0002`, client-a `…-0003`, attorney-a `…-0004`, org-a `20000000-…-0001`).

| Check | Mode | Asserts |
|---|---|---|
| **13.01** POS | `authenticated` (partner-a) | `create_matter` with non-owner assignees (client-a/attorney-a, both active members of org-a) → returns an id; the row is then visible to the assigned reader via `matters_select_assigned` (count 1); in-transaction, rolled back |
| **13.02** NEG | `authenticated` (partner-a) | owner as `p_assigned_client_id` → raises `platform owner cannot be assigned to a matter`; **no** new `matters` row |
| **13.03** NEG | `authenticated` (partner-a) | owner as `p_assigned_attorney_id` → same refusal; no row |
| **13.04** NEG (trigger layer) | connection role | direct `insert into public.matters` with the owner id in an assignment column → the trigger raises; **no** row (proves the categorical backstop even off the RPC path) |
| **13.05** POS (trigger narrowness) | connection role | direct INSERT with non-owner assignees succeeds (the demo-seed path stays viable; the trigger refuses owner assignments only); rolled back |
| **13.06** NEG (§8) | `authenticated` (partner-a) | a denied create (owner assignee) writes **no** `matter:create` audit row (the 10.09 pattern) |
| **13.07** POS (§8) | `authenticated` (partner-a) | an allowed create writes a `matter:create` row with a **redacted** summary (observed via `read_org_audit` as partner-a); rolled back |

Sketches (style = the existing batteries):

```sql
-- 13.02 (representative NEG; role impersonation + expectation)
do $$
begin
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
  perform set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002"}', false);
  begin
    perform public.create_matter(
      '20000000-0000-4000-8000-000000000001', 'F-01 probe', 'corporate',
      '10000000-0000-4000-8000-000000000001', null); -- owner as client
    raise exception 'POLICY-BATTERY FAIL 13.02: owner assignment accepted by create_matter';
  exception when others then
    if sqlerrm <> 'platform owner cannot be assigned to a matter' then
      raise exception 'POLICY-BATTERY FAIL 13.02: unexpected error (want the refusal): %', sqlerrm;
    end if;
  end;
end $$;
```

```sql
-- 13.04 (representative trigger-layer NEG; runs as the connection role)
begin;
do $$
begin
  begin
    insert into public.matters
      (organization_id, title, practice_area, assigned_client_id)
    values
      ('20000000-0000-4000-8000-000000000001', 'F-01 probe', 'corporate',
       '10000000-0000-4000-8000-000000000001'); -- owner id
    raise exception 'POLICY-BATTERY FAIL 13.04: direct INSERT with owner assignment bypassed the trigger';
  exception when others then
    if sqlerrm <> 'platform owner cannot be assigned to a matter' then
      raise exception 'POLICY-BATTERY FAIL 13.04: unexpected error (want the trigger refusal): %', sqlerrm;
    end if;
  end;
end $$;
rollback;
```

**Harness wiring (when the slice is approved and built):** add
`13_matter_write_rls.sql` to `BATTERY_FILES`, the static UUID scan, the
FAIL-marker loop (≥10 named blocks — the table above has 7 rows, so the real
file adds the org-mismatch/cross-org/anon deny rows to reach ≥10), and
`run_battery`; the selftest glob (`1[0-9]_*.sql`) already covers 13;
`supabase/README.md` battery table gains a 13 row; `scripts/README.md` is
touched only if its battery description needs the count.

## 7. What changes when approved (file map)

| File | Change | Layer |
|---|---|---|
| `supabase/rpc/create_matter.sql` | **NEW** (REHEARSAL-READY; `_down.sql` drop added) | RPC |
| `supabase/migrations/11_matter_write.sql` (+ `.down`) | **NEW** — trigger function + trigger | migration |
| `supabase/tests/13_matter_write_rls.sql` | **NEW** — the 13 battery | test |
| `scripts/verify_policy_tests.sh` | 13 into file list/loops/header | harness |
| `supabase/README.md` | battery-table 13 row | doc |
| `docs/permission_matrix.md` | **dated §4 addendum**: new "Create a matter" row (partner creates; assignees active members; owner never assignable) + §5 consummation note that the categorical deny is now enforced (F-01 step 2) | doc |
| `docs/current_applied_surface_2026-08-08.md` | post-apply update (13th table unchanged; RPC 19→20; triggers 1) | doc |

## 8. Gate sequence (mandatory before apply)

1. **This design → owner approval** (Gate 3 spec approval; the F-01 register's
   step 2 flips from DESIGNED to APPROVED). ✅ **DONE 2026-08-09.**
2. **Mechanism/RLS-gate review** (the `send_message` mechanism-review
   pattern — Q&A over F2-D1 creator role, F2-D2 refusal, F2-D3 trigger,
   F2-D4 guard, §8 audit, and the F-11 note that the definer body queries
   `memberships` directly rather than widening the self-scoped helpers).
   ✅ **PASS 2026-08-09** — `docs/matter_write_slice_review_2026-08-09.md`;
   R-1 (UPDATE arm) + R-2 (F2-D5) remediated in-review via
   13.14/13.15/13.16.
3. **Rehearsal-ready artifacts** per §7 (RPC + migration + battery + harness).
   ✅ **BUILT 2026-08-09** (uncommitted, working tree).
4. **Battery + harness** static `--check` green (and the drift selftest).
   ✅ **73/0/0 PASS** + selftest 6/6.
5. **Ephemeral rehearsal r1** — the F-01-step-1 stack pattern
   (scratch project on isolated ports, `--apply`, full battery) → dated
   evidence record. ✅ **r1 PASSED 2026-08-09** — `--apply` 44/44, battery
   **82/0/0 ×2** (`docs/matter_write_slice_rehearsal_r1_2026-08-09.md`).
6. **Dated apply-approval → apply to the dev project** (never unapproved;
   `rollback_plan.md` pairing: `_down.sql` for the RPC + migration drop).
   ⏳ **Record PREPARED 2026-08-09** (`docs/matter_write_apply_approval_2026-08-09.md`)
   — **pending owner signature**; on signature, the execution record follows.
7. **Matrix §4 addendum** (dated, per §7 discipline) — extends, never
   silently widens.
8. **Env-gated client swap** (separate approval; the `MatterWriteGateway`
   seam/fake gains `createMatter`, the screen ships behind
   `env.isConfigured`). ✅ **DESIGNED 2026-08-09** —
   `docs/matter_write_client_slice_design_2026-08-09.md` (Gate 3, pending
   owner approval; decisions C-D1…C-D8, open questions Q1–Q5).

## 9. Open questions (owner)

1. **F2-Q1 — creator role:** partner-only (design default) vs any
   active member with a defined role policy? (The general matter-authoring
   policy is undefined — D-MR5; this design takes the conservative default.)
2. **F2-Q2 — assignments at creation:** nullable (design default, F2-D5) vs
   required-both? (Required would add a validation the schema does not
   impose today.)
3. **F2-Q3 — practice_area:** keep the fixed CHECK enum (design default) vs
   make it configurable in a later slice?
4. **F2-Q4 — refusal message wording:** the design uses the constant
   `platform owner cannot be assigned to a matter` (non-enumerating; reveals
   no owner identity). Owner may prefer a generic wording for consistency
   with `permission denied` — a copy decision, not a security one.

## 10. Traceability

- Findings register: `docs/p4_findings_register_2026-08-09.md` **F-01**
  (step 1 SHIPPED + r1 PASSED; step 2 = this design; step 3 optional R-4
  policy-arm remains open and is **superseded in spirit** by F2-D3's
  trigger — the trigger achieves the categorical guarantee without widening
  the client-probe surface, so step 3 may be dropped on owner decision).
- Threat model: `docs/p4_threat_model_2026-08-09.md` §4.6 (owner capability
  creep) + §6.10 (consummation note).
- Step 1 evidence: `docs/owner_assignment_battery_rehearsal_r1_2026-08-09.md`
  (battery 12 — the invariant this slice refuses to break).
- Prior art: `supabase/rpc/create_organization.sql` (creator-becomes-owner),
  `supabase/rpc/send_message.sql` (in-function gate + audit + return-id),
  `supabase/rpc/invite_member.sql` (existing-member guard), batteries
  03/10/12 (refusal + §8-negative patterns).
