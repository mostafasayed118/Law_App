# LegalHub — P2 Ephemeral Rehearsal & RLS Policy-Test Plan

> **Record type:** The rehearsal verification plan mandated by the reviewed P2
> migration slice (`supabase/README.md`), `docs/p2_schema_rls_design.md` §7,
> and `docs/rollback_plan.md` §2/§5 — the gate artifact that turns the
> REVIEWED/NOT APPLIED slice (`b5f7e7c`) into an applied-and-proven one.
>
> **Status: DRAFT — for review, not executed.** Running this plan is itself a
> separate approval slice. Nothing here authorizes applying anything to the
> shared dev project; the rehearsal runs in an **ephemeral** environment.
>
> **Date:** 2026-08-01. **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/permission_matrix.md` (every row needs ≥1 positive +
> ≥1 negative test) · `docs/p2_schema_rls_design.md` §6 (org-a/org-b mapping),
> §7 (rollback pairing) · `docs/rollback_plan.md` §1/§2/§5 ·
> `docs/auth_tenant_authorization_contract.md` §7/§9/§11-P2 · `docs/adr/0007`.

---

## 1. Purpose & gate position

This plan proves, against a throwaway environment, that the reviewed slice
**up → verify → down → verify** cleanly and that every permission-matrix row
behaves as signed — before anything touches the dev project. It is the
"rehearsal" the design §7 and rollback_plan §2 require, and it produces the
evidence record the apply-approval gate consumes.

| Gate step | Artifact | Status |
|---|---|---|
| P2 approval recorded | `docs/p0_decision_capture.md` §3 | ✅ Approved 2026-08-01 |
| RLS-gate design review passed | `docs/p2_schema_rls_design.md` §8 (Q1–Q6) | ✅ Passed 2026-08-01 |
| Reviewed migration slice | `supabase/` (`b5f7e7c`) | ✅ Committed & pushed, REVIEWED/NOT APPLIED |
| **Ephemeral rehearsal (this plan)** | `docs/p2_rehearsal_plan.md` | ⏳ **DRAFT — the next gate input** |
| Apply approval for the dev project | explicit owner authorization | ⏳ blocked on rehearsal-pass evidence |

**Conclusion:** the decision-level and review-level preconditions are
satisfied. What remains before any Supabase change is: run this rehearsal
ephemerally, record the evidence, then a separate apply approval.

---

## 2. Environment: ephemeral, throwaway, zero-cost-to-dev

- **Rehearsal target:** an **ephemeral Supabase project** created for this
  rehearsal and torn down after (or `supabase db reset` against the dev
  project **only** if the owner confirms a baseline that is already
  empty-of-P2 and disposable). Default: ephemeral project — never the shared
  dev project.
- **Connectivity:** URL + anon key from the local git-ignored `.env`
  (`--dart-define-from-file` is not involved here — this is SQL-server-side
  only, via `supabase db` / `psql` against the ephemeral project). No
  credential leaves the machine.
- **Baseline confirmation before up:** `TABLE_COUNT=0` (or dev-equivalent
  empty) verified read-only — same probe used at P1 (REST 200,
  `TABLE_COUNT=0`).
- **Rehearsal evidence:** every step's output pasted into the rehearsal
  record (a dated section appended to this document or a linked log file),
  per rollback_plan §1 ("`supabase db diff` … pasted into the PR/commit
  description").
- **Owner fill token:** `03_platform_config_seed.sql`'s `<OWNER_USER_ID>`
  substitution token is filled with the **verified** owner `auth.users.id`
  at up-time (Q1) — verified via a read-only query against the rehearsal
  project, never guessed.

---

## 3. Up sequence — apply the reviewed slice, verifying each step

Each step: apply → `supabase db diff` before/after → confirm only the
expected objects appear.

| Step | Apply | Verify after |
|---|---|---|
| 0 | Baseline check | `TABLE_COUNT=0`; `supabase db diff` clean |
| 1 | `migrations/01_org_schema.sql` | enums `org_role`/`membership_status`/`invitation_status` exist; 6 tables exist; RLS enabled on all six (`\d+` shows `Row security: enabled`); `anon`/`authenticated` have **no** table grants except the narrow ones (`\dp` — profiles select+update(display_name,locale), orgs/memberships/invitations select only, nothing on audit_events/platform_config) |
| 2 | `migrations/02_rls_functions.sql` | 7 security-definer functions exist; `revoke execute from public, anon` held (try `select public.write_audit('x','y')` as anon → **denied**); signup trigger `on_auth_user_created` exists on `auth.users`; `is_platform_owner()` false for everyone (seed not yet applied) |
| 3 | `migrations/03_platform_config_seed.sql` (fill token) | `platform_config` has exactly 1 row; `is_platform_owner()` true **only** for the owner uid; a non-owner returns false |
| 4 | `policies/*.sql` | **5** `create policy` statements exist (profiles ×2 — select/update — plus orgs/memberships/invitations ×1 each); **zero** policies on `audit_events`/`platform_config` (intentional, RPC-only posture) |
| 5 | `rpc/*.sql` | 17 RPCs exist; each granted **only** to `authenticated` (revoked from public/anon); `_down.sql` drops all 17 |

**Step 5 explicit check — the three reviewer assertions:**

1. **auth.users DELETE privilege (delete_my_account / delete_demo_account):**
   create a disposable synthetic user in the rehearsal project, then call
   `delete_my_account()` as that user and `delete_demo_account(uid)` as the
   owner. **Assert both succeed** — if the migration role lacks DELETE on
   `auth.users` in this hosting (auth schema owned by `supabase_auth_admin`),
   the RPC errors and the slice needs a `grant delete on auth.users to
   postgres` (or a service-role path) **recorded before any dev apply**.
   This is the single most environment-dependent line in the slice.
2. **Policy-helper-revoke canary:** after the helper revokes in step 2, run
   the matrix §3 **positive** test "view own org member list" as an active
   member — `select * from memberships where organization_id = org-a` returns
   the roster. If this fails, the revoke broke policy evaluation (it should
   not — policies resolve as the table owner) — investigate before
   continuing, don't assume.
3. **Audit-read self-audit:** a partner's `read_org_audit` and the owner's
   `read_platform_audit` each produce **their own** new audit row (matrix §6
   "the audit read itself is audited").

---

## 4. Policy-test suite — full positive/negative matrix execution

Fixtures (synthetic, `.test`-domain, no real PII): `org-a`, `org-b`;
identities `client@org-a.test`, `attorney@org-a.test`,
`partner@org-a.test`, `compliance@org-a.test`, `client@org-b.test`, one
`removed@org-a.test` and one `suspended@org-a.test` membership, and the
owner account for `platform_owner_admin` rows. Every row = ≥1 positive
(org-a) + ≥1 negative (cross-org or deny), per contract §9.

**Provider-level scope note:** matrix §2's sign-up / sign-in / sign-out and
password-reset rows are GoTrue/session-layer behaviors, not assertable via
`psql` against an ephemeral project. They are covered by the rollback_plan
§1 manual smoke (sign-in/sign-up/reset against the restored schema) and are
**not** asserted in this SQL rehearsal — the plan promises only evidence it
can actually produce.

### §2 Identity & session

| Row | Positive (must pass) | Negative (must deny) |
|---|---|---|
| View own profile | `client@org-a` `select * from profiles` where `user_id = auth.uid()` → 1 row | `client@org-a` reads `client@org-b`'s profile row → 0 rows |
| Edit own profile | Own-row `update profiles set display_name=...` → succeeds | `update` setting `user_id` ≠ `auth.uid()` → denied (RLS WITH CHECK) |
| View another user's profile | **RESOLVED (D-T6):** the matrix §2 partner row was **amended to "❌ deny"** (own-row-only for every non-owner role) via a dated §2 addendum — the default-deny direction, aligning the signed matrix with the approved design (§5.2) and the committed slice. No partner-profile-metadata RPC exists (and none was added — Q5 surface minimality). The rehearsal asserts the **actual** behavior: `profiles_select_own` returns own row only; a partner selecting another user's profile row → 0 rows | `client@org-a` reads another org's profile → 0 rows; **anon** `select` → denied, not empty-success |
| Delete own account | `delete_my_account()` → identity removed, **audit row survives** with `actor_user_id` nulled | `delete_demo_account` by a non-owner → denied; session-token invalidation after deletion → **provider-level check** (GoTrue), covered by the rollback_plan §1 manual smoke, not the SQL rehearsal |

### §3 Organization & membership

| Row | Positive (org-a) | Negative |
|---|---|---|
| View own org member list | any org-a role selects `memberships where organization_id = org-a` → roster | `client@org-a` selects `organization_id = org-b` → 0 rows |
| Invite new member | `partner@org-a` `invite_member(org-a, x@org-b.test, 'client')` → invitation + audit | `client@org-a` / `compliance@org-a` `invite_member` → denied; `partner@org-a` inviting with `role='client'` but passing org-b → denied |
| Resend / revoke pending invite | `partner@org-a` resends → new token hash, 7-day expiry reset; revokes → status `revoked` | `client@org-a` revoke → denied; revoke of an org-b invite by `partner@org-a` → denied (org resolved from invite row) |
| Change member's role | `partner@org-a` `change_member_role(org-a, x, 'attorney')` → succeeds + audit | `partner@org-a` changing an org-b membership's role → denied |
| Suspend / reactivate | `partner@org-a` suspends → status `suspended`; reactivates → `active` | suspended member's stale session reads org data → 0 rows; `client@org-a` suspend → denied |
| Remove a member | `partner@org-a` removes → status `removed` | `partner@org-a` removes self → denied (use `delete_my_account`); remove on org-b → denied |
| Delete synthetic demo account | owner `delete_demo_account(uid)` → removed, audit survives | owner calling on own uid → denied; non-owner → denied |
| Switch active org | identity with memberships in both orgs selects own memberships → 2 rows | selecting org-b context never bypasses `active_membership(org-b)` check on org-b-scoped data |

**Tenant-isolation negative sweep (contract §9):** for **every** action row
above, the org-b variant denies — proven by changing only the
`organization_id` parameter, never by changing the identity.

### §5 platform_owner_admin — explicit boundary

| Capability | Positive | Negative |
|---|---|---|
| List orgs metadata | owner `list_organizations_metadata()` → org list, audited | non-owner → denied |
| List members metadata | owner `list_members_metadata()` → id/name/locale/role/status/timestamps only, audited | owner reading matter/doc content → **denied at the RLS layer** (no such tables in P2 — future-table deny guard asserted as "no raw grant/policy exists", matrix §4) |
| Suspend / reactivate any org | owner `suspend_membership_platform` + `reactivate_membership_platform` (org-b member) → status flips, audited | owner action outside the permitted list (e.g. a role change) → no such RPC exists; owner editing/deleting an audit row → no grant/policy |
| Every owner action audited | each of the above produces an audit row with the owner actor | owner is not audit-exempt — the audit read itself is audited (assertion #3 above) |

### §6 Storage / realtime / audit

| Scenario | Assert |
|---|---|
| Private object via guessed path | **Deferred (Q4):** zero buckets exist. Assert "no bucket policy exists" — the future-facing negative test is recorded, not executed |
| Realtime across orgs | **Deferred (Q4):** zero channels. Same recording |
| Membership/sensitive change produces redacted audit | `invite_member` / `change_member_role` / suspend / remove each produce an audit row; assert `redacted_summary` contains **no** token, password, or content — only reason codes |
| Read the audit table | `partner@org-a` `read_org_audit(org-a)` → org-a rows; `client@org-a` → denied; **direct `select * from audit_events`** by any client role → denied (no grant); owner `read_platform_audit` → cross-org rows, itself audited |
| Audit append-only | direct `update`/`delete` on `audit_events` → denied for every role |

**Cross-cutting asserts:**
- **Invitation token hashing (Q2):** after `invite_member`, assert
  `token_hash` = sha-256 of the returned literal, and that the literal token
  appears nowhere in `invitations` (only the hash).
- **Suspended/removed never authorize (matrix §3):** `active_membership()`
  returns no row for `suspended`/`removed` statuses — asserted via each
  org-scoped read after the status transition.
- **Generic denial (matrix §2):** `accept_invitation` with a wrong,
  expired, or foreign token returns the same "invalid invitation" error with
  no distinguisher (enumeration guard).

---

## 5. Down sequence — rollback proves the pairing

| Step | Apply | Verify after |
|---|---|---|
| 1 | `rpc/_down.sql` | 17 RPCs gone; `\df public.*` empty of the slice's functions |
| 2 | `git revert` the policy commit (or drop the **5** policies) | `\dp` grants back to the narrow set; matrix §2/§3 positive rows no longer pass on the policies (removed) |
| 3 | `migrations/03_platform_config_seed.down.sql` | `is_platform_owner()` false for everyone |
| 4 | `migrations/02_rls_functions.down.sql` | 7 functions gone; trigger gone; `write_audit` no longer callable |
| 5 | `migrations/01_org_schema.down.sql` | tables + enums gone; `supabase db diff` equals the **pre-up baseline** (schema equality, rollback_plan §1) |

**Trigger conditions (rollback_plan §5) — any of these = immediate revert,
never fix-forward:**
- Any negative row in §4 starts **passing** (a denial that should happen,
  doesn't).
- Any credential, token, or PII appears in logs/audit where it shouldn't.
- Cross-tenant data becomes visible in a manual smoke check.

---

## 6. Exit criteria — what "rehearsal passed" means

The rehearsal passes when, against the ephemeral project:
1. The full up sequence (steps 1–5) applied cleanly with the per-step
   `db diff` evidence recorded.
2. Every §4 positive row passed and every §4 negative row denied — recorded
   row by row (matrix §9's ≥1-positive/≥1-negative contract met).
   **Recorded-finding rows** (if any remain) assert the **observed** behavior
   and are logged as findings — they are not treated as must-pass matrix
   promises (their resolution path is tracked before dev apply, not in this
   rehearsal). The matrix-§2-vs-slice row that surfaced one such finding is
   **RESOLVED (D-T6)** by the matrix §2 addendum (2026-08-01).
3. All three reviewer assertions passed (auth.users DELETE, policy-helper
   canary, audit self-audit).
4. The full down sequence restored the pre-up baseline (schema equality).
5. No trigger condition fired.

The pass evidence becomes the input to the separate **apply approval** for
the dev project. A partial pass (e.g. auth.users DELETE needs a grant) is
recorded as a finding with its fix, and the slice is amended before any dev
apply — never applied dev-ward with known failing assertions.

---

## 7. What this plan does NOT authorize

- No apply to the shared dev project, staging, or production — this runs
  ephemeral-only.
- No storage/realtime policy (Q4 deferral), no matter/doc schema (P2+), no
  real data, no service-role usage, no compliance claim.
- The Flutter code (`lib/`) is untouched. `docs/kickoff_prompt.md` remains
  untracked and out of any commit.
- Running this plan requires its own explicit approval; even then, nothing
  reaches the dev project without a further apply approval.
