# LegalHub — P2 Reviewed Migration Slice (Supabase)

> **Record type:** The reviewed, gate-approved P2 migration set for the
> non-production Supabase dev project, re-authored from the approved design
> (`docs/p2_schema_rls_design.md`, APPROVED 2026-08-01, §8 Q1–Q6 answered) and
> governed by `docs/auth_tenant_authorization_contract.md` §7/§9/§11-P2 ·
> `docs/permission_matrix.md` · `docs/rollback_plan.md` §1/§2 ·
> `docs/gate3_decision.md` §5 · `docs/adr/0007`.
>
> **Status: REVIEWED & APPLIED (dev project, 2026-08-01).** The slice was
> applied to the shared dev project (`eutmvevpskerzpqmwplv`) under the
> apply-approval record's §4 conditions: Up 1–5 applied and verified GREEN —
> evidence in `docs/p2_apply_execution_2026-08-01.md` (`3bcd968`). The §4.5
> post-apply **manual smoke** (signup loop with a real inbox) remains
> pending. Applying it was a **separate approval slice** requiring (1) the
> ephemeral rehearsal from `docs/rollback_plan.md` §2 and
> `docs/p2_schema_rls_design.md` §7, and (2) explicit owner authorization per
> `INSTRUCTIONS.md` §2.1 gates — both recorded (rehearsal r4 PASSED,
> `docs/p2_rehearsal_evidence_r4_2026-08-01.md`; approval
> `docs/p2_apply_approval_2026-08-01.md`).
>
> **Date:** 2026-08-01. **Owner:** Project Owner (github.com/mostafasayed118).

---

## Directory layout

| Path | Content | Paired backout |
|---|---|---|
| `migrations/01_org_schema.sql` | Enums, 6 tables, RLS enable, default-deny revokes + narrow grants | `migrations/01_org_schema.down.sql` |
| `migrations/02_rls_functions.sql` | Helper functions + signup trigger + expiry cleanup (security definer) | `migrations/02_rls_functions.down.sql` |
| `migrations/03_platform_config_seed.sql` | Q1 owner-uid seed (substitution token, applied only with verified id) | `migrations/03_platform_config_seed.down.sql` |
| `policies/*.sql` | Per-table RLS policies (versioned in git, never edited in dashboard) | `git revert` of the policy commit (design §7) |
| `rpc/*.sql` | Narrow RPC surface (security definer, each audited) | `rpc/_down.sql` (drops the whole surface) |

## Apply order (as executed on the dev project, 2026-08-01)

```
1. migrations/01_org_schema.sql
2. migrations/02_rls_functions.sql
3. migrations/03_platform_config_seed.sql   ← fill OWNER_USER_ID token from verified id first
4. policies/*.sql                           (order irrelevant; all reference 01/02 objects)
5. rpc/*.sql                                (all reference 01/02 objects)
```

Each step verified with `supabase db diff` before/after per `rollback_plan.md` §1.

## Design fidelity & refinements (flagged for the reviewer, not silently encoded)

1. **Q5 "only raw policy is own-profile SELECT/UPDATE"** is read as a
   **mutation-surface** rule (design §5.3 is the complete INSERT/UPDATE/DELETE
   surface). Direct SELECTs follow design §5.2 and matrix §3 (org member list,
   org select, own profile, partner invitations) — encoded as the narrow
   SELECT grants + policies below. No raw INSERT/UPDATE/DELETE grant exists.
2. **Audit reads are RPC-only** (`read_org_audit`, `read_platform_audit`),
   not a raw SELECT policy — this is the only way the matrix §6 requirement
   ("`platform_owner_admin` reading audit is itself an audited action") and
   contract §8's scope-checked-reader rule are both satisfiable. The two
   read RPCs are additions to the design §5.3 list, justified by §5.2/§6.
   Also **`reactivate_membership_platform` was added** to complete matrix §3's
   signed owner row ("Suspend / reactivate a membership | ✅ (any org)")
   which design §5.3's list omitted — flagged so the owner can veto before
   apply; the policy-test suite otherwise could not exercise that positive row.
3. **`accept_invitation` uses a generic "invalid invitation" error** for
   every failure mode (not-found, expired, revoked, email mismatch) so no
   enumeration signal leaks (matrix §2 negative).
4. **`delete_my_account` writes the audit row before deleting the identity**
   — the FK is `on delete set null`, so the redacted summary survives with the
   actor reference cleared (D-05 + contract §8).
5. **`invitations.accepted_by`/`accepted_at` stay nullable** and are bound
   only by the security-definer `accept_invitation` RPC, never by the client.
6. **pgcrypto** is required (sha-256 `digest`). The 2026-08-01 ephemeral
   rehearsal confirmed pgcrypto lives in the `extensions` schema on this
   hosting, so the unqualified `gen_random_bytes`/`digest` calls failed under
   the pinned `search_path = public`. **Amended (R-1):** the three token RPCs
   (`invite_member`, `resend_invitation`, `accept_invitation`) now qualify
   `extensions.*` explicitly. Verified in the rehearsal's ephemeral fix; the
   amended slice must be re-rehearsed before apply.
7. **`remove_membership` refuses self-removal** (`auth.uid() = p_user_id` →
   error) — self-deletion belongs to `delete_my_account` (D-05). This is a
   hardening beyond matrix §3's unqualified "Remove a member | ✅ (own org)"
   row; flagged for the owner's awareness, not a silent widening.
8. **`accept_invitation` matches the invited email against the JWT `email`
   claim** (`auth.jwt() ->> 'email'`) — a provider session without that claim
   would make acceptance impossible (generic denial). Known precondition for
   the anon-key GoTrue setup, not a silent failure.

## Rollback pairing (design §7 / rollback_plan §1–§2)

| Forward artifact | Backout | Verification after rollback |
|---|---|---|
| `01_org_schema.sql` | `.down.sql` | `supabase db diff` → schema equality with pre-P2 baseline |
| `02_rls_functions.sql` | `.down.sql` | Function inventory equal; pre-P2 policy expectations still pass |
| `policies/*.sql` | `git revert` of the policy commit | Matrix negative rows still deny; positive rows allow only where pre-approved |
| `rpc/*.sql` | `_down.sql` | RPC grant list returns to the prior set |
| `03_platform_config_seed.sql` | `.down.sql` | `is_platform_owner()` false for everyone |

**Rehearsal requirement:** the full up → down → verify sequence runs in an
ephemeral Supabase project (or `db reset` against the dev project with a
confirmed-empty baseline) before anything is applied to the shared dev
project (contract §11-P2 exit, rollback_plan §2). Any matrix negative row
starting to pass = immediate revert, never fix-forward (rollback_plan §5).

## Phase 3 R1 (applied 2026-08-03)

On 2026-08-03 the reviewed forward artifact `rpc/list_org_members_metadata.sql`
(partner-scoped roster RPC, design `docs/p3_r1_roster_rpc_design_2026-08-03.md`)
and its one-line `rpc/_down.sql` drop were added to the repo. The ephemeral
rehearsal passed (r1 evidence `docs/p3_r1_rehearsal_evidence_r1_2026-08-03.md`,
finding A1 folded in), the owner recorded the dated apply approval, and the
RPC was **applied to the dev project on 2026-08-03** — the applied surface
is now the P2 slice (Up 1–5) **plus** the 18th RPC, with the amended
`_down.sql` drop line as backout.

## What this directory does NOT authorize

- No Supabase change beyond the reviewed + applied slice (Up 1–5, executed
  2026-08-01 on the dev project; §4.5 manual smoke pending) and the
  **applied** Phase 3 R1 slice above (2026-08-03).
- No matter/doc schema, no storage/realtime policy (Q4 deferral), no real
  data, no service-role usage, no compliance claim.
- The Flutter code (`lib/`) is untouched by this slice.
