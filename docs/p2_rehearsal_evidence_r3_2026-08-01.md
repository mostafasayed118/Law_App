# LegalHub — P2 Ephemeral Rehearsal Evidence Record, R3 (2026-08-01)

> **Record type:** The dated evidence record mandated by `docs/p2_rehearsal_plan.md`
> §2 and consumed by the **apply-approval gate** (`p0_decision_capture.md` §3 P2 row).
> This is the **re-run on the R-3-amended slice** (`c95dcf4`, revoke `authenticated`
> from the 7 security-definer helpers + `alter default privileges` hardening + down
> pairing), following the r2 PASSED verdict (`docs/p2_rehearsal_evidence_r2_2026-08-01.md`)
> and the R-3 finding surfaced during the dev apply attempt.
> **Status: REHEARSAL NOT PASSED — finding R-4.** The r3 gate's twin assertions were
> exercised live: assertion (a)'s **privilege half passed** (all 7 helpers deny
> `authenticated` EXECUTE; hardening proven), but the **policy surface broke** — the
> blanket revoke denied `authenticated` EXECUTE on the two read-only helpers the RLS
> policies call, so every policy-gated read errors. Assertion (b) (down restores
> `pg_default_acl` byte-equal) **passed**. Nothing was applied to the shared dev
> project (`eutmvevpskerzpqmwplv`) — this ran against a throwaway project created
> and deleted for this record.
> **Owner:** Project Owner (github.com/mostafasayed118), 2026-08-01.

---

## 1. Environment & mechanism (verified)

| Item | Value |
|---|---|
| Rehearsal target | **Ephemeral project** `law-app-p2-rehearsal-r3` (ref `seaxwphnzdcccipkhsvx`), org `oouytakxadxxuykbmbof`, region **eu-central-1** (Frankfurt, matches dev) |
| Dev project | `eutmvevpskerzpqmwplv` — **untouched** (read-only probes only, DO-NOT-TOUCH ref) |
| Slice under test | **R-3 amended** `supabase/` from commit `c95dcf4` (revoke `authenticated` on all 7 helpers, `service_role` kept; `alter default privileges … revoke execute on functions from anon, authenticated`; paired `grant` in the down file) |
| Execution vehicle | `supabase db query --linked` (Management API SQL endpoint) — no Docker/psql; role impersonation (`set role authenticated/anon` + `set_config('request.jwt.claims', …)`) is the standard Supabase RLS test pattern |
| Baseline (pre-up) | **`TABLE_COUNT=0`, 0 functions, 0 policies, 0 enums** — confirmed read-only before the up sequence |
| Pre-up `pg_default_acl` snapshot (assertion (b) baseline) | `postgres`/objtype `f`: `{postgres=X/postgres, anon=X/postgres, authenticated=X/postgres, service_role=X/postgres}` — **identical R-3 default to the dev project**, so the hardening is genuinely exercised, not vacuous |
| Session continuity | Single uninterrupted run (project created, rehearsed, down'd, and deleted within one session) |

---

## 2. Up sequence — per-step verification (all GREEN)

| Step | Applied | Verified |
|---|---|---|
| 1 | `migrations/01_org_schema.sql` | ✅ 3 enums; 6 tables; **RLS on all six**; grants per design §5.2 — `authenticated`: `profiles` SELECT + UPDATE `(display_name, locale)`, `organizations`/`memberships`/`invitations` SELECT; **zero `anon` grants**; nothing on `audit_events`/`platform_config` |
| 2 | `migrations/02_rls_functions.sql` (R-3 amended) | ✅ 7 security-definer helpers; signup trigger present; **R-3 assertion (a) privilege half PASSED** — `has_function_privilege('authenticated', …)` = **false on all 7** (incl. `write_audit` with its full 8-arg signature), `anon` = false, `service_role` = true; live probes **denied as `authenticated` and as `anon`**; **hardening proven live**: post-up `pg_default_acl` for `postgres`/`f` = `{postgres=X, service_role=X}` (anon/authenticated default EXECUTE removed; `supabase_admin` row untouched — platform default) |
| 3 | `migrations/03_platform_config_seed.sql` (token filled from verified id) | ✅ exactly **1** `platform_config` row, owner id `e8ef344e-617f-4e47-b9f1-5edfb54ee050` (created in the rehearsal project and read back from `auth.users` — never guessed) |
| 4 | `policies/*.sql` (all 6 files) | ✅ exactly **5** `create policy` statements (`profiles` ×2, `organizations`/`memberships`/`invitations` ×1); **zero** policies on `audit_events`/`platform_config` (RPC-only posture) |
| 5 | `rpc/*.sql` (17 files, excl `_down`) | ✅ **all 17 applied with FAIL=0**; each `has_function_privilege('authenticated', …)` = **true** / `anon` = **false** (explicit grants win over the hardening — client surface intact); **`proowner` check**: all 24 public functions owned by `postgres` (the hardening provably applies to the slice's functions) |

**Harness methodology notes (recorded, not silent):** (1) `has_function_privilege` signatures built from `proargtypes` via `format_type` + ordered `string_agg` — exact ACL signatures without parameter names (the `pg_get_function_identity_arguments` form includes `p_org uuid` names and errors); (2) live probes use a `set role` + `exception when insufficient_privilege` pattern — the FAIL exception propagates if the helper executes, so a clean completion is a genuine denial; (3) the pre-up `pg_default_acl` snapshot is the assertion-(b) comparison baseline, captured before step 1.

---

## 3. Fixtures (synthetic, `.test`-domain, no real PII)

9 deterministic synthetic identities (partner/attorney/compliance/client/removed/suspended
@org-a.test, client/partner@org-b.test, dual@lawapp-rehearsal.test) plus the owner.
org-a and org-b created via `create_organization`; all memberships provisioned through the
**real** `invite_member` → `accept_invitation` flow with matching JWT email claims;
`suspended@org-a` suspended and `removed@org-a` removed via the partner RPCs. Final state
verified: org-a = **7** memberships (incl. removed/suspended/dual), org-b = **3** (incl. dual).

---

## 4. §3 reviewer assertions — 4 PASS / 3 FAIL (the failures ARE the R-4 finding)

| # | Assertion | Result |
|---|---|---|
| 1a | `delete_my_account()` as a disposable user — identity removed, audit row survives (actor FK nulled) | ✅ PASS |
| 1b | `delete_demo_account(uid)` as owner — **auth.users DELETE privilege present**; no grant amendment needed | ✅ PASS |
| 2 | Policy-helper-revoke canary — partner@org-a's org-a roster read (RLS genuinely exercised, `set role authenticated`) | ❌ **FAIL — `permission denied for function is_active_member`** |
| 3a | `read_org_audit` self-audit — the read produced its own new audit row | ✅ PASS |
| 3b | `read_platform_audit` self-audit — the read produced its own new audit row | ✅ PASS |
| **R-2 GATE** | client@org-a reading org-b's roster → 0 rows | ❌ **FAIL — same `is_active_member` permission denial** |
| **R-2 GATE** | partner@org-a reading org-b's roster → 0 rows | ❌ **FAIL — same** |

The 4 PASSes run as postgres or via security-definer RPCs — unaffected by the helper
revokes. The 3 FAILs all share one root cause, diagnosed live (§6).

---

## 5. §4 matrix — remainder NOT EXECUTED (halt rule)

The remaining §4 matrix rows were **not executed**: `docs/p2_rehearsal_plan.md` §5 /
`docs/rollback_plan.md` §5 mandate **immediate revert, never fix-forward** on any anomaly.
The canary failure proved the policy read surface (orgs/memberships/invitations) is broken
by the R-3 revoke scope, so running 30 more rows against a known-broken surface would
produce noise, not evidence. The down sequence ran immediately (§7). The exercised rows
are those in §4 above.

---

## 6. Finding R-4 — root cause (diagnosed live, confirmed by reviewer)

**Root cause:** PostgreSQL RLS policy quals execute as the **querying role**, so function
calls inside them require that role's EXECUTE — `SECURITY DEFINER` changes the function
body's privilege context, **not** the caller's right to invoke. Live `pg_policy`
inspection is definitive:

| Policy | Helper called (runs as the querying role → needs `authenticated` EXECUTE) |
|---|---|
| `organizations_select_active_member` | `is_active_member(id)` |
| `memberships_select_org_roster` | `is_active_member(organization_id)` |
| `invitations_select_partner` | `has_org_role(organization_id, 'partner')` |
| `profiles_select_own` / `profiles_update_own` | none (`auth.uid() = user_id` only — why profiles reads survived) |

The R-3 blanket revoke of `authenticated` from **all 7** helpers broke the entire policy
read surface for orgs/memberships/invitations. **This is a latent design bug in the
original slice** — its comment claimed "policies resolve them as the table owner — no
client grant is needed," which is false for function calls in policy quals. The r2 "38
PASS" masked it because the hosting default ACL *accidentally* granted those EXECUTE
rights; R-3 removed the accident and surfaced the latent bug. **R-3 itself is correct**
(the `write_audit` audit-integrity fix is exactly right) — its scope was too broad.

**Reviewer-endorsed fix (not implemented — pending the owner's separate approval):**
1. Keep the uniform revoke-from-`authenticated` on all 7 (default-deny), then add a
   commented **"policy-evaluation grants"** block granting `authenticated` EXECUTE on
   **exactly two** helpers: `is_active_member(uuid)` and `has_org_role(uuid, public.org_role)`.
   (`active_membership` is **not** granted — it is only invoked from inside
   security-definer bodies, so no client grant is needed.)
2. Correct the false "table owner" comment in `02_rls_functions.sql` in the same amendment.
3. Reword rehearsal-plan assertion (a): denied on `write_audit` + the write/maintenance/
   trigger helpers; **granted** on the two read-only policy-referenced helpers — with a
   canary asserting **both** directions.
4. Mark `c95dcf4` **superseded**; the apply-approval forward hook must eventually point
   at the R-4-amended slice.

---

## 7. Down sequence — rollback pairing proven; assertion (b) PASSED

| Step | Applied | Verified |
|---|---|---|
| 1 | `rpc/_down.sql` | ✅ 17 RPCs dropped |
| 2 | drop the **5** policies | ✅ `remaining_policies = 0` |
| 3 | `03_platform_config_seed.down.sql` | ✅ applied |
| 4 | `02_rls_functions.down.sql` | ✅ applied — **R-3 assertion (b): post-down `pg_default_acl` for `postgres`/`f` = `{postgres=X, anon=X, authenticated=X, service_role=X}` — byte-equal to the pre-up snapshot** (the paired `grant` fully reverted the hardening) |
| 5 | `01_org_schema.down.sql` | ✅ applied; **final baseline: `TABLE_COUNT=0`, 0 functions, 0 policies, 0 enums** — byte-equal to the pre-up baseline (rollback_plan §1 schema equality met) |

---

## 8. Trigger conditions & teardown

- **§5 trigger condition FIRED:** the policy-gated positive rows (canary, R-2 gates) no
  longer execute — a denial/error that should not happen, does. Per `rollback_plan.md` §5,
  this mandates immediate revert (executed in §7), never fix-forward.
- **No credential/token/PII appeared** in logs/audit (redaction checks passed where the
  surface was reachable).
- **Teardown:** ephemeral project `law-app-p2-rehearsal-r3` (`seaxwphnzdcccipkhsvx`)
  **deleted** (`supabase projects delete --yes`, confirmed "Deleted project"). Zero
  residual cloud footprint. Dev project confirmed untouched via `supabase projects list`.
- **Repo state:** working tree pristine except the intentional untracked
  `docs/kickoff_prompt.md`. Harness scripts live in `~/lawapp-p2-rehearsal-tmp/` (outside
  the repo; the random DB password dies with the deleted project).

---

## 9. Rehearsal verdict → next gate

**NOT PASSED (R-4).** Up steps 1–5 all green; assertion (a)'s **privilege half** (all 7
helpers deny `authenticated` EXECUTE, incl. `write_audit`; live probes denied as
`authenticated` **and** `anon`; hardening proven live) **passed**; **assertion (b) passed**
(down restores `pg_default_acl` byte-equal); the rollback pairing held end-to-end. But the
**policy surface broke**: the blanket revoke denied `authenticated` EXECUTE on the two
read-only helpers the RLS policies call (`is_active_member`, `has_org_role`), so every
policy-gated read errors. This is a latent bug in the original slice, exposed by R-3's
correct hardening.

Per `p2_rehearsal_plan.md` §6 exit criteria, the r3 verdict is **NOT PASSED**: the slice
must be amended (R-4 fix: policy-evaluation grants on exactly those two helpers + comment
correction + assertion-(a) reword) and **re-rehearsed (r4)** before the apply-approval
gate (`p0_decision_capture.md` §3 P2 row) can re-unblock the dev apply. Nothing has touched
the dev project, and the rehearsal's throwaway environment is gone.

**Ledger note (forward hook):** `docs/p2_rehearsal_plan.md` (067841f) still reads
"⏳ **r3 PENDING**" in its status header and §1 gate table. This record **is** the r3
execution result (NOT PASSED, R-4) — the plan's r3 status rows must be flipped to
"EXECUTED — r3 NOT PASSED (R-4)" when the R-4 slice amendment lands (same batch or
immediate follow-up), so a reader cross-referencing the plan does not see PENDING
alongside a NOT-PASSED record.
