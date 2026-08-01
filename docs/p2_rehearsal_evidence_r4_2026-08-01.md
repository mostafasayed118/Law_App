# LegalHub — P2 Ephemeral Rehearsal Evidence Record, R4 (2026-08-01)

> **Record type:** The dated evidence record mandated by `docs/p2_rehearsal_plan.md`
> §2 and consumed by the **apply-approval gate** (`p0_decision_capture.md` §3 P2 row).
> This is the **re-run on the R-4-amended slice** (`3704a1d`, policy-evaluation grants
> on `is_active_member`/`has_org_role` + comment correction + plan flipped to
> r4-pending), following the r3 NOT PASSED verdict
> (`docs/p2_rehearsal_evidence_r3_2026-08-01.md`, finding R-4: the R-3 blanket revoke
> broke the policy read surface).
> **Status: REHEARSAL PASSED.** Both twin critical gates held live: the policy-gated
> reads **succeed** with RLS genuinely exercised (canary roster + both R-2 cross-org
> negatives), **and** `write_audit` stays denied to `authenticated`/`anon`. Assertion
> (b) (down restores `pg_default_acl` byte-equal) **passed**. The §4 matrix ran to
> completion: **38 PASS + 2 RECORDED** (the Q4 deferrals), zero matrix failures.
> Nothing was applied to the shared dev project (`eutmvevpskerzpqmwplv`) — this ran
> against a throwaway project created and deleted for this record.
> **Owner:** Project Owner (github.com/mostafasayed118), 2026-08-01.

---

## 1. Environment & mechanism (verified)

| Item | Value |
|---|---|
| Rehearsal target | **Ephemeral project** `law-app-p2-rehearsal-r4` (ref `qtftmyvyjziqeqdaewoo`), org `oouytakxadxxuykbmbof`, region **Central EU (Frankfurt, eu-central-1)** — recorded from the live `supabase projects list`, not assumed |
| Dev project | `eutmvevpskerzpqmwplv` — **untouched** (read-only probes only, DO-NOT-TOUCH ref) |
| Slice under test | **R-4 amended** `supabase/` from commit `3704a1d` (uniform revoke from `public, anon, authenticated` on all 7 helpers kept; **policy-evaluation grants** adding `authenticated` EXECUTE on exactly `is_active_member(uuid)` + `has_org_role(uuid, public.org_role)`; false "table owner" comment corrected; `active_membership` NOT granted; `service_role` never revoked; hardening + down pairing unchanged) |
| Execution vehicle | `supabase db query --linked` (Management API SQL endpoint) from a scratch CLI project context (the repo carries no `config.toml`; the harness link was re-established with the stored db password). Role impersonation (`set role authenticated/anon` + `set_config('request.jwt.claims', …)`) is the standard Supabase RLS test pattern |
| Baseline (pre-up) | **`TABLE_COUNT=0`, 0 functions, 0 policies, 0 enums** — confirmed read-only before the up sequence |
| Pre-up `pg_default_acl` snapshot (assertion (b) baseline) | `postgres`/`public`/objtype `f`: `{postgres=X/postgres, anon=X/postgres, authenticated=X/postgres, service_role=X/postgres}` — **identical R-3 default to the dev project**, so the hardening is genuinely exercised, not vacuous |
| Session continuity | Single uninterrupted run (project created, rehearsed, down'd, and deleted within one session) |

**Harness methodology notes (recorded, not silent):** (1) `has_function_privilege`
signatures built from `proargtypes` via `format_type` + ordered `string_agg` — exact
ACL signatures without parameter names; (2) live probes use a `set role` +
`exception when insufficient_privilege` pattern — the FAIL exception propagates if the
helper executes, so a clean completion is a genuine denial; (3) the pre-up
`pg_default_acl` snapshot is the assertion-(b) comparison baseline, captured before
step 1; (4) `is_platform_owner` and owner-gated checks run with `request.jwt.claims`
set explicitly (the R-3 revoke denies `authenticated` direct EXECUTE by design, so the
honest owner-gate assertion is claims-driven, not role-driven); (5) **recorded staleness
finding, not a fix:** the r3 evidence record (`38e4832`) described its rehearsal project
region as "matches dev", but the live `supabase projects list` shows the dev project at
**West Europe (London)** — this r4 record records its own project's region from the live
list and does not repeat the stale claim (region matching was never a rehearsal
requirement; the slice is hosting-agnostic and was rehearsed identically).

---

## 2. Up sequence — per-step verification (all GREEN)

| Step | Applied | Verified |
|---|---|---|
| 1 | `migrations/01_org_schema.sql` | ✅ 3 enums (`org_role`, `membership_status`, `invitation_status`); 6 tables; **RLS on all six**; grants per design §5.2 — `authenticated`: `profiles` SELECT + UPDATE `(display_name, locale)`, `organizations`/`memberships`/`invitations` SELECT; **zero `anon` grants**; nothing on `audit_events`/`platform_config` |
| 2 | `migrations/02_rls_functions.sql` (R-4 amended) | ✅ 7 security-definer helpers; signup trigger present; **R-4 assertion (a) PASSED both directions** — `is_active_member(uuid)` and `has_org_role(uuid, org_role)` **granted** to `authenticated` (`has_function_privilege` = true), while `write_audit` (full 8-arg signature), `expire_stale_invitations`, `handle_new_user`, `is_platform_owner` **deny** `authenticated` (false), `active_membership` correctly un-granted (invoked only from inside definer bodies); `anon` = false on all 7; `service_role` = true on all 7; **live probes**: `write_audit` denied as `authenticated` **and** as `anon`; `is_active_member` **callable** as `authenticated` (grant live); **hardening proven live**: post-up `pg_default_acl` for `postgres`/`f` = `{postgres=X, service_role=X}` (anon/authenticated default EXECUTE removed); `is_platform_owner()` false pre-seed |
| 3 | `migrations/03_platform_config_seed.sql` (token filled from verified id) | ✅ exactly **1** `platform_config` row; owner uid `5573f7c6-907f-4267-91a5-9c202948fe82` (created in the rehearsal project and read back from `auth.users` — never guessed); `is_platform_owner()` true **only** for the owner uid, false for a partner |
| 4 | `policies/*.sql` (all 6 files) | ✅ exactly **5** `create policy` statements (`profiles` ×2 — select/update — plus `organizations`/`memberships`/`invitations` ×1); **zero** policies on `audit_events`/`platform_config` (RPC-only posture) |
| 5 | `rpc/*.sql` (17 files, excl `_down`) | ✅ **all 17 applied with FAIL=0**; each `has_function_privilege('authenticated', …)` = **true** / `anon` = **false** (explicit grants win over the hardening — client surface intact); **`proowner` check**: all 24 public functions owned by `postgres` (the hardening provably applies to the slice's functions) |

---

## 3. Fixtures (synthetic, `.test`-domain, no real PII)

9 deterministic synthetic identities (partner/attorney/compliance/client/removed/suspended
@org-a.test, client/partner@org-b.test, dual@lawapp-rehearsal.test) plus the owner.
org-a and org-b created via `create_organization`; all memberships provisioned through the
**real** `invite_member` → `accept_invitation` flow with matching JWT email claims;
`suspended@org-a` suspended and `removed@org-a` removed via the partner RPCs. Final state
verified: org-a = **7** memberships (incl. removed/suspended/dual), org-b = **3** (incl. dual).

---

## 4. Twin-gate assertions + §3 reviewer assertions — 7/7 PASS (the r3 failures are green)

| # | Assertion | Result |
|---|---|---|
| 1a | `delete_my_account()` as a disposable user — identity removed, audit row survives (actor FK nulled) | ✅ PASS |
| 1b | `delete_demo_account(uid)` as owner — **auth.users DELETE privilege present**; no grant amendment needed | ✅ PASS |
| 2 | **Policy-helper canary (R-4 twin gate, was r3 FAIL):** partner@org-a's org-a roster read (RLS genuinely exercised, `set role authenticated`) | ✅ **PASS — 7 rows** (the R-4 grants re-open `is_active_member`/`has_org_role` to policy quals; the policy read surface works) |
| 3a | `read_org_audit` self-audit — the read produced its own new audit row | ✅ PASS |
| 3b | `read_platform_audit` self-audit — the read produced its own new audit row | ✅ PASS |
| **R-2 GATE** | client@org-a reading org-b's roster → 0 rows (was r3 FAIL) | ✅ **PASS — 0 rows** |
| **R-2 GATE** | partner@org-a reading org-b's roster → 0 rows (was r3 FAIL) | ✅ **PASS — 0 rows** |

**Write-audit twin gate (verified in Up 2, not just asserted):** `write_audit` is denied
to `authenticated` **and** `anon` — by privilege matrix (`has_function_privilege` = false)
**and** by live probes (both roles denied at runtime). The R-3 audit-integrity win is
preserved on the R-4-amended slice.

---

## 5. §4 policy-test matrix — full execution: **38 PASS + 2 RECORDED**, zero failures

The full positive/negative matrix ran to completion (no halt triggered — the r3 halt rule
anomaly is gone). Every row asserted both directions where the contract requires
(≥1 positive + ≥1 negative per `permission_matrix.md`).

### §2 Identity & session — 7/7 PASS

| Row | Result | Detail |
|---|---|---|
| View own profile POS | ✅ PASS | `client@org-a` reads own profile (1 row) |
| View own profile NEG (other user) | ✅ PASS | `client@org-a` reads `client@org-b` profile → 0 rows |
| **View another profile NEG (D-T6)** | ✅ PASS | partner@org-a selects client@org-a profile → **0 rows** (own-row-only, per the matrix §2 addendum) |
| Edit own profile POS | ✅ PASS | own `display_name` update committed |
| Edit own profile NEG (user_id) | ✅ PASS | UPDATE setting foreign `user_id` denied (RLS WITH CHECK) |
| View profile anon NEG | ✅ PASS | anon SELECT denied (denied, not empty-success) |
| Delete demo account NEG (non-owner) | ✅ PASS | non-owner `delete_demo_account` denied |

### §3 Organization & membership — 17/17 PASS

| Row | Result | Detail |
|---|---|---|
| View own org member list POS | ✅ PASS | org-a member reads org-a roster (7 rows) |
| View own org member list NEG (org-b) | ✅ PASS | `client@org-a` selects org-b roster → 0 rows |
| Invite new member POS | ✅ PASS | invitation + audit row created |
| Invite NEG (non-partner) | ✅ PASS | `client@org-a` invite denied |
| Invite NEG (cross-org) | ✅ PASS | partner@org-a invite into org-b denied |
| Resend invite POS | ✅ PASS | resend rotated token + reset 7-day expiry |
| Revoke invite POS | ✅ PASS | invite status → `revoked` |
| Revoke NEG (non-partner) | ✅ PASS | client revoke denied |
| Change role POS | ✅ PASS | role changed to attorney (and restored) |
| Change role NEG (cross-org) | ✅ PASS | cross-org role change denied |
| Suspend/reactivate POS | ✅ PASS | suspend then reactivate → `active` |
| Suspend NEG (non-partner) | ✅ PASS | client suspend denied |
| Suspended member NEG (stale access) | ✅ PASS | suspended member reads org-a org row → 0 rows |
| Remove member POS | ✅ PASS | member removed via real invite→accept→remove flow |
| Remove self NEG | ✅ PASS | self-removal denied (use `delete_my_account`) |
| Delete demo account NEG (owner self) | ✅ PASS | owner self-delete denied (must use `delete_my_account`) |
| Switch active org POS (dual) | ✅ PASS | dual member sees exactly 2 memberships |

### §5 platform_owner_admin — 7/7 PASS

| Capability | Result |
|---|---|
| List orgs metadata POS (owner) | ✅ PASS — 2 orgs, audited |
| List orgs metadata NEG (non-owner) | ✅ PASS — denied |
| List members metadata POS (owner) | ✅ PASS — 11 members, id/name/locale/role/status only, audited |
| List members metadata NEG (non-owner) | ✅ PASS — denied |
| Platform suspend/reactivate POS (owner, cross-org) | ✅ PASS — org-b member suspended + reactivated |
| Platform suspend NEG (non-owner) | ✅ PASS — denied |
| Owner actions audited POS | ✅ PASS — 6 platform audit rows produced |

### §6 Storage / realtime / audit + cross-cutting — 7 PASS + 2 RECORDED

| Scenario | Result | Detail |
|---|---|---|
| Read the audit table — direct SELECT NEG | ✅ PASS | direct `select * from audit_events` denied for every client role |
| Audit append-only — direct UPDATE NEG | ✅ PASS | direct `update audit_events` denied |
| `read_org_audit` POS (partner) | ✅ PASS | partner@org-a reads org-a audit (28 rows) |
| `read_org_audit` NEG (client) | ✅ PASS | client@org-a denied |
| Redacted audit POS | ✅ PASS | `redacted_summary` contains no token/password/credential material |
| Token hashing POS (Q2) | ✅ PASS | `token_hash` = sha-256 of the returned literal; literal appears nowhere |
| Generic denial POS (accept) | ✅ PASS | wrong/foreign token → same "invalid invitation", no distinguisher |
| Storage buckets (Q4 deferral) | **RECORDED** | zero buckets expected; assert "no bucket policy exists" — future-facing negative, not executed |
| Realtime channels (Q4 deferral) | **RECORDED** | zero channels; deferred, not executed |

---

## 6. Down sequence — rollback pairing proven; assertion (b) PASSED

| Step | Applied | Verified |
|---|---|---|
| 1 | `rpc/_down.sql` | ✅ 17 RPCs dropped |
| 2 | drop the **5** policies | ✅ `remaining_policies = 0` |
| 3 | `03_platform_config_seed.down.sql` | ✅ applied |
| 4 | `02_rls_functions.down.sql` | ✅ applied — **R-3/R-4 assertion (b): post-down `pg_default_acl` for `postgres`/`f` = `{postgres=X, anon=X, authenticated=X, service_role=X}` — byte-equal to the pre-up snapshot** (the paired `grant` fully reverted the hardening) |
| 5 | `01_org_schema.down.sql` | ✅ applied; **final baseline: `TABLE_COUNT=0`, 0 functions, 0 policies, 0 enums** — byte-equal to the pre-up baseline (rollback_plan §1 schema equality met) |

---

## 7. Trigger conditions & teardown

- **§5 trigger conditions — NONE fired.** The r3 anomaly (policy-gated reads erroring) is
  resolved by the R-4 grants; every negative row still denied, every positive row
  succeeded, and no credential/token/PII appeared in logs/audit (redaction checks passed).
- **Teardown:** ephemeral project `law-app-p2-rehearsal-r4` (`qtftmyvyjziqeqdaewoo`)
  **deleted** (`supabase projects delete --yes`, confirmed "Deleted project"). Zero
  residual cloud footprint. Dev project confirmed untouched via `supabase projects list`
  (only `law_project` / `eutmvevpskerzpqmwplv` remains).
- **Repo state:** working tree pristine except the intentional untracked
  `docs/kickoff_prompt.md`. Harness scripts live outside the repo (the random DB
  password dies with the deleted project).

---

## 8. Rehearsal verdict → next gate

**PASSED (r4).** The R-4 fix is validated end-to-end on the amended slice
(`3704a1d`): the policy read surface works with RLS genuinely exercised (canary roster,
both R-2 cross-org negatives — the exact three rows that failed in r3), **and**
`write_audit` stays denied to `authenticated`/`anon` (privilege matrix **and** live
probes). Assertion (a) passed in both directions, assertion (b) passed (down restores
`pg_default_acl` byte-equal), the full §4 matrix ran to **38 PASS + 2 RECORDED** with
zero failures, the rollback pairing held end-to-end, and no trigger condition fired.

Per `p2_rehearsal_plan.md` §6 exit criteria, the r4 verdict is **PASSED**: the amended
slice satisfies every exit criterion. The apply-approval gate
(`p0_decision_capture.md` §3 P2 row) is **re-unblocked** subject to the forward hook
below. Nothing has touched the dev project; the rehearsal's throwaway environment is
gone.

**Ledger note (forward hook):** `docs/p2_apply_approval_2026-08-01.md` (`d9cb842`)
still cites the slice at `83593c2`; before any dev apply its §3 decision scope / §4
execution conditions must be reconciled to the **R-4-amended slice** (`3704a1d`) — an
amendment or an explicit re-confirmation at apply time. `docs/p2_rehearsal_plan.md`
(`3704a1d`) still reads "⏳ **r4 PENDING**" in its status header and §1 gate table; this
record **is** the r4 execution result (PASSED) — the plan's r4 status rows must be
flipped to "EXECUTED — r4 PASSED" in the same batch or immediate follow-up, so a reader
cross-referencing the plan does not see PENDING alongside a PASSED record.
