# LegalHub — P2 Ephemeral Rehearsal & RLS Policy-Test Plan

> **Record type:** The rehearsal verification plan mandated by the reviewed P2
> migration slice (`supabase/README.md`), `docs/p2_schema_rls_design.md` §7,
> and `docs/rollback_plan.md` §2/§5 — the gate artifact that turns the
> REVIEWED/NOT APPLIED slice (`b5f7e7c`) into an applied-and-proven one.
>
> **Status: EXECUTED — r1 NOT PASSED · r2 PASSED · r3 NOT PASSED (R-4) · r4 PASSED (2026-08-01)** —
> four ephemeral runs recorded: r1 NOT
> PASSED (`docs/p2_rehearsal_evidence_2026-08-01.md`, `3266c23`), r2 PASSED
> on the amended slice (`docs/p2_rehearsal_evidence_r2_2026-08-01.md`,
> `2c31b27`), and r3 NOT PASSED (`docs/p2_rehearsal_evidence_r3_2026-08-01.md`,
> `38e4832`) — **finding R-4**: the R-3 blanket revoke of `authenticated`
> EXECUTE from all 7 helpers broke the RLS policy surface (policy quals
> execute as the querying role and call `is_active_member`/`has_org_role`);
> the R-3 default-privileges hardening itself held (assertion (b) byte-equal).
> The slice is amended for R-4 (policy-evaluation grants on exactly those two
> helpers, uniform revoke kept) and **r4 PASSED**
> (`docs/p2_rehearsal_evidence_r4_2026-08-01.md`, `d0379d2`) — the twin
> gates held live: policy reads succeed AND `write_audit` stays denied;
> 38 PASS + 2 RECORDED, zero matrix failures; assertion (b) byte-equal.
> **Forward hook (resolved 2026-08-01):** the apply-approval record
> (`docs/p2_apply_approval_2026-08-01.md`, `d9cb842`) slice reference was
> reconciled from `83593c2` to the R-4-amended slice `3704a1d` in the same
> batch as this flip.
> Running this plan was itself a separate approval slice;
> nothing
> in it authorizes applying anything to the shared dev project — the apply
> approval is recorded separately in `docs/p2_apply_approval_2026-08-01.md`.
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
| Reviewed migration slice | `supabase/` (`b5f7e7c`, amended `83593c2` R-1/R-2, `c95dcf4` R-3, `3704a1d` R-4 policy-evaluation grants) | ✅ Committed & pushed, REVIEWED — applied to the dev project 2026-08-01 (execution row below) |
| **Ephemeral rehearsal (this plan)** | `docs/p2_rehearsal_plan.md` | ✅ **EXECUTED 2026-08-01** — r1 NOT PASSED (`docs/p2_rehearsal_evidence_2026-08-01.md`, `3266c23`); r2 PASSED (`docs/p2_rehearsal_evidence_r2_2026-08-01.md`, `2c31b27`); **r3 NOT PASSED — R-4** (`docs/p2_rehearsal_evidence_r3_2026-08-01.md`, `38e4832`); **r4 PASSED** (`docs/p2_rehearsal_evidence_r4_2026-08-01.md`, `d0379d2`) |
| Apply approval for the dev project | explicit owner authorization | ✅ **APPROVED 2026-08-01** — `docs/p2_apply_approval_2026-08-01.md` (slice ref reconciled to the R-4-amended slice `3704a1d`) |
| Apply execution (dev project) | `docs/p2_apply_execution_2026-08-01.md` (`3bcd968`) | ✅ **EXECUTED 2026-08-01** — Up 1–5 applied & verified GREEN on the dev project under §4 conditions 1–4 and 6; §4.5 post-apply smoke PARTIAL — manual smoke pending (evidence §6 forward hook) |

**Conclusion:** the decision-level and review-level preconditions are
satisfied. Four ephemeral runs are recorded: r1 NOT PASSED
(`docs/p2_rehearsal_evidence_2026-08-01.md`, `3266c23`), r2 **PASSED** on
the then-amended slice (`2c31b27`), **r3 NOT PASSED (R-4)** (`38e4832`) — the
R-3 default-privileges hardening held (assertion (b) byte-equal) but the
blanket revoke broke the policy surface — and **r4 PASSED** on the
R-4-amended slice (`d0379d2`) — the twin gates held (policy reads succeed;
`write_audit` stays denied), 38 PASS + 2 RECORDED, assertion (b) byte-equal.
The dev apply was **executed** under the apply-approval record's §4
conditions (slice ref reconciled to `3704a1d`): Up 1–5 applied and verified
GREEN on the dev project — evidence in
`docs/p2_apply_execution_2026-08-01.md` (`3bcd968`). The only remaining P2
item is the §4.5 **manual post-apply smoke** (signup → email-confirm →
sign-in → password-reset with a real inbox), recorded as pending in the
evidence record's §6 forward hook — the apply is not declared *fully*
complete until it runs.

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
| 0 | Baseline check | `TABLE_COUNT=0`; `supabase db diff` clean; **snapshot `pg_default_acl`** (pre-up baseline for assertion (b) byte-equality) |
| 1 | `migrations/01_org_schema.sql` | enums `org_role`/`membership_status`/`invitation_status` exist; 6 tables exist; RLS enabled on all six (`\d+` shows `Row security: enabled`); `anon`/`authenticated` have **no** table grants except the narrow ones (`\dp` — profiles select+update(display_name,locale), orgs/memberships/invitations select only, nothing on audit_events/platform_config) |
| 2 | `migrations/02_rls_functions.sql` | 7 security-definer functions exist; **R-3 assertion (a):** `has_function_privilege('authenticated', 'public.write_audit(text,text,uuid,text,uuid,uuid,text,uuid)', 'EXECUTE')` → **false** — `write_audit` and the write/maintenance/trigger helpers (`expire_stale_invitations`, `handle_new_user`, `is_platform_owner`) deny `authenticated` EXECUTE, as does `active_membership` (read-only but invoked only from inside security-definer bodies — no client grant needed); live probe `select public.write_audit('x','y')` → **denied** as `anon` **and** as `authenticated`; **R-4 policy-evaluation grants (amended):** `is_active_member(uuid)` and `has_org_role(uuid, public.org_role)` are **granted** to `authenticated` (policy quals execute as the querying role) — assert `has_function_privilege` → **true** for both; hardening verified — new public functions do **not** inherit anon/authenticated EXECUTE (`pg_default_acl`); signup trigger `on_auth_user_created` exists on `auth.users`; `is_platform_owner()` false for everyone (seed not yet applied) |
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
2. **Policy-helper-revoke canary (R-4 twin gate):** after the helper revokes
   in step 2, run the matrix §3 **positive** test "view own org member list"
   as an active member — `select * from memberships where organization_id =
   org-a` returns the roster. This now succeeds **only because** the R-4
   policy-evaluation grants re-open `is_active_member`/`has_org_role` to
   `authenticated` (policy quals execute as the querying role — the original
   slice's "policies resolve as the table owner" assumption was false and is
   corrected by the R-4 amendment). If it fails, the policy surface is still
   broken — investigate before continuing, don't assume.
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
| 4 | `migrations/02_rls_functions.down.sql` | 7 functions gone; trigger gone; `write_audit` no longer callable; **R-3 assertion (b):** `pg_default_acl` restored — the `alter default privileges` grant is re-applied, queried and compared to the pre-up snapshot (byte-equal) |
| 5 | `migrations/01_org_schema.down.sql` | tables + enums gone; `supabase db diff` equals the **pre-up baseline** (schema equality **and `pg_default_acl` byte-equal** to the pre-up snapshot — the R-3 hardening is fully reverted, rollback_plan §1) |

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
   canary, audit self-audit) **plus R-3/R-4 assertion (a): `authenticated`
   EXECUTE denied on `write_audit` and the write/maintenance/trigger helpers
   (`expire_stale_invitations`, `handle_new_user`, `is_platform_owner`),
   and on `active_membership` (read-only but invoked only from inside
   security-definer bodies — no client grant needed), AND granted on exactly
   `is_active_member` + `has_org_role` (the two policy-referenced read-only
   helpers) — the canary asserting both directions (policy reads succeed;
   `write_audit` denied).**
4. The full down sequence restored the pre-up baseline — schema equality
   **and `pg_default_acl` byte-equal to the pre-up snapshot (R-3 assertion
   (b); the default-privileges hardening fully reverted)**.
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
