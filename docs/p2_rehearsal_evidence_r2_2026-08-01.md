# LegalHub — P2 Ephemeral Rehearsal Evidence Record, R2 (2026-08-01)

> **Record type:** The dated evidence record mandated by `docs/p2_rehearsal_plan.md`
> §2 and consumed by the **apply-approval gate** (`p0_decision_capture.md` §3 P2 row).
> This is the **re-run on the amended slice** (`83593c2`, R-1/R-2 fixes) following the
> first rehearsal's NOT PASSED verdict (`docs/p2_rehearsal_evidence_2026-08-01.md`,
> which recorded findings R-1 pgcrypto qualification + R-2 `active_membership` SETOF).
> **Status: REHEARSAL PASSED.** Nothing was applied to the shared dev project
> (`eutmvevpskerzpqmwplv`) — this ran against a throwaway project created and
> deleted for this record.
> **Owner:** Project Owner (github.com/mostafasayed118), 2026-08-01.

---

## 1. Environment & mechanism (verified)

| Item | Value |
|---|---|
| Rehearsal target | **Ephemeral project** `law-app-p2-rehearsal-r2` (ref `oowhkfopegtnfmhlfifr`), org `oouytakxadxxuykbmbof` (mustafasayed111's Org — the account that owns the dev project), region **eu-central-1** (Frankfurt, matches dev) |
| Dev project | `eutmvevpskerzpqmwplv` — **untouched** (read-only probes only, DO-NOT-TOUCH ref) |
| Slice under test | **Amended** `supabase/` from commit `83593c2` (R-1: `extensions.*` qualification in the 3 token RPCs; R-2: `active_membership` returns `setof public.memberships`) |
| Execution vehicle | `supabase db query --linked` (Management API SQL endpoint) — no Docker/psql; role impersonation (`set role authenticated/anon` + `set_config('request.jwt.claims', …)`) is the standard Supabase RLS test pattern |
| Baseline (pre-up) | **`TABLE_COUNT=0`, 0 functions, 0 policies, 0 enums** — confirmed read-only before the up sequence |
| Session interruption | Freebuff restarted mid-rehearsal (after up step 5 + fixtures). State verified on resume: project ACTIVE_HEALTHY, link intact, up steps 1–5 objects present (6 tables / 24 definer fns / 5 policies / 3 enums), all 10 fixture identities present. No work was repeated; the harness continued from fixtures. |

---

## 2. Up sequence — per-step verification (all GREEN, amended slice)

| Step | Applied | Verified |
|---|---|---|
| 1 | `migrations/01_org_schema.sql` | ✅ 3 enums; 6 tables; **RLS on all six**; grants per design §5.2 — `authenticated`: `profiles` SELECT + UPDATE `(display_name, locale)` (column-level verified), `organizations`/`memberships`/`invitations` SELECT; **zero `anon` grants**; nothing on `audit_events`/`platform_config` |
| 2 | `migrations/02_rls_functions.sql` (amended) | ✅ 7 security-definer helpers; EXECUTE revoked from `public`/`anon`; signup trigger present; `is_platform_owner()` false pre-seed; **`active_membership` return type confirmed `SETOF memberships` in the live DB (R-2 fix at object level)** |
| 3 | `migrations/03_platform_config_seed.sql` (token filled from verified id) | ✅ exactly **1** `platform_config` row, owner id `cf0d7676-ea75-4844-8656-e022f6afc561` (read back from `auth.users`); `is_platform_owner()` true for owner / false for non-owner (claim-impersonated) |
| 4 | `policies/*.sql` (all 6 files) | ✅ exactly **5** `create policy` statements (`profiles` ×2, `organizations`/`memberships`/`invitations` ×1); **zero** policies on `audit_events`/`platform_config` (RPC-only posture) |
| 5 | `rpc/*.sql` (17 files, excl `_down`) | ✅ **all 17 applied with FAIL=0 — the R-1 `extensions.*` qualification resolved at apply time** (in the first rehearsal the unqualified forms failed here); EXECUTE granted to `authenticated` only, zero `anon`/`PUBLIC` |

---

## 3. Fixtures (synthetic, `.test`-domain, no real PII)

10 identities: owner + `client/attorney/partner/compliance/removed/suspended@org-a.test`,
`client/partner@org-b.test`, `dual@lawapp-rehearsal.test`. org-a (id `e3850af1-4bf7-4b7d-9203-04f6452774b4`)
and org-b (id `02dea2ed-d067-442d-9ccc-6a5d910bc6e5`) created via `create_organization`; all memberships
provisioned through the **real** `invite_member` → `accept_invitation` flow with matching JWT email claims;
`suspended@org-a` suspended and `removed@org-a` removed via the partner RPCs. Final state verified:
org-a = 7 memberships (incl. removed/suspended/dual), org-b = 3 (incl. dual).

---

## 4. §3 reviewer assertions (7/7 PASS)

| # | Assertion | Result |
|---|---|---|
| 1a | `delete_my_account()` as a disposable user — identity removed, audit row survives (actor FK nulled) | ✅ PASS |
| 1b | `delete_demo_account(uid)` as owner — **auth.users DELETE privilege present**; no grant amendment needed | ✅ PASS |
| 2 | Policy-helper-revoke canary — after the step-2 revokes, partner@org-a's org-a roster read returned 7 rows with RLS genuinely exercised (`set role authenticated` — not the vacuous first-run form) | ✅ PASS |
| **R-2 GATE** | **client@org-a reading org-b's roster → 0 rows** (the exact negative that FAILED with 3 rows in the first run — now holds with the SETOF fix) | ✅ **PASS** |
| **R-2 GATE** | **partner@org-a reading org-b's roster → 0 rows** | ✅ **PASS** |
| 3a | `read_org_audit` self-audit — the read produced its own new audit row | ✅ PASS |
| 3b | `read_platform_audit` self-audit — the read produced its own new audit row | ✅ PASS |

**Harness methodology notes (recorded, not silent):** (1) results table writes happen only after
`reset role` to the session's postgres — an impersonated role has no INSERT on the postgres-owned
temp table (observed 42501 in a first draft; fixed with the capture-reset-write pattern); (2) the
audit self-audits and owner-audit counts run as postgres with claims set because `audit_events` has
zero `authenticated` grants (RPC-only posture); (3) the harness is idempotent via a postgres preamble
(state reset for the platform suspend/reactivate fixture + revoking stale pending harness invites —
never DELETE, honoring the invitation audit-trail discipline).

---

## 5. §4 matrix — executed rows

### §2 Identity & session — **7/7 PASS** (role-impersonated, RLS genuinely applied)

| Row | Result |
|---|---|
| View own profile (positive) | ✅ client@org-a reads own profile → 1 row |
| View own profile (negative) | ✅ client@org-a reads client@org-b's profile → 0 rows |
| Edit own profile (positive) | ✅ own-row `display_name` update committed |
| Edit own profile (negative) | ✅ UPDATE setting foreign `user_id` denied |
| View another user's profile (D-T6) | ✅ partner@org-a selecting client@org-a's profile → 0 rows (own-row-only) |
| anon SELECT | ✅ denied, not empty-success |
| `delete_demo_account` by non-owner | ✅ denied |

### §3 Organization & membership — **17/17 PASS** (the rows the first run HALTED on)

| Row | Result |
|---|---|
| View own org member list POS / NEG | ✅ org-a roster (7 rows) / org-b → 0 rows |
| Invite new member POS | ✅ invitation + audit created |
| Invite NEG (non-partner) / NEG (cross-org) | ✅ client@org-a denied; partner@org-a into org-b denied |
| Resend / revoke pending invite POS | ✅ token rotated + 7-day expiry reset; status → revoked |
| Revoke NEG (non-partner) | ✅ client@org-a denied |
| Change member's role POS / NEG (cross-org) | ✅ changed to attorney (+ restored); org-b change denied |
| Suspend / reactivate POS | ✅ suspend → reactivate → active |
| Suspend NEG (non-partner) | ✅ client@org-a denied |
| Suspended member stale-session NEG | ✅ suspended@org-a reads org-a org row → 0 rows |
| Remove a member POS | ✅ real invite→accept→remove flow → status `removed` |
| Remove self NEG | ✅ partner@org-a self-removal denied |
| Delete demo account NEG (owner self) | ✅ owner deleting own uid denied |
| Switch active org POS (dual) | ✅ dual sees exactly 2 memberships |

### §5 platform_owner_admin — **7 PASS**

| Row | Result |
|---|---|
| List orgs metadata POS / NEG | ✅ owner → 2 orgs / non-owner denied |
| List members metadata POS / NEG | ✅ owner → 11 members / non-owner denied |
| Suspend/reactivate any org POS | ✅ owner suspended + reactivated an org-b member (cross-org) |
| Platform suspend NEG (non-owner) | ✅ denied |
| Every owner action audited | ✅ 12 `platform:%` audit rows with owner actor |

### §6 Audit / storage / realtime — **5 PASS + 2 RECORDED (Q4 deferrals)**

| Scenario | Result |
|---|---|
| Storage buckets (Q4) | ✅ RECORDED — 0 objects; deferred, not executed |
| Realtime channels (Q4) | ✅ RECORDED — `realtime.subscription` not present on this hosting generation; deferred |
| Redacted audit | ✅ no token/password/credential material in `redacted_summary` |
| Read the audit table — partner POS | ✅ partner `read_org_audit` → 32 org-a rows |
| Read the audit table — client NEG | ✅ `read_org_audit` denied for non-partner |
| Read the audit table — direct SELECT NEG | ✅ **direct `select` on `audit_events` denied (no grant)** |
| Audit append-only | ✅ direct `update` on `audit_events` denied |

### Cross-cutting — **2 PASS**

| Assert | Result |
|---|---|
| Invitation token hashing (Q2) | ✅ `token_hash` = sha-256 of the returned literal; literal token nowhere in `invitations` |
| Generic denial (no enumeration) | ✅ `accept_invitation` with a bogus token → identical `invalid invitation` error |

---

## 6. Down sequence — rollback pairing proven (baseline restored)

| Step | Applied | Verified |
|---|---|---|
| 1 | `rpc/_down.sql` | ✅ 17 RPCs dropped |
| 2 | drop the **5** policies | ✅ `remaining_policies = 0` (one drop initially used a wrong policy name; corrected to `invitations_select_partner`, then 0 remained) |
| 3 | `03_platform_config_seed.down.sql` | ✅ applied |
| 4 | `02_rls_functions.down.sql` | ✅ applied (after the policy fix cleared the `has_org_role` dependency) |
| 5 | `01_org_schema.down.sql` | ✅ applied; **final baseline: `TABLE_COUNT=0`, 0 functions, 0 policies, 0 enums** — byte-equal to the pre-up baseline (rollback_plan §1 schema equality met) |

---

## 7. Trigger conditions & teardown

- **No §5 trigger condition fired** — every negative row denied (the R-2 cross-org roster negative now
  holds), no credential/token/PII appeared in logs/audit (redaction checks passed).
- **Teardown:** ephemeral project `law-app-p2-rehearsal-r2` (`oowhkfopegtnfmhlfifr`) **deleted**
  (`supabase projects delete --yes`, confirmed "Deleted project"). Zero residual cloud footprint.
- **Repo state:** working tree pristine except the intentional untracked `docs/kickoff_prompt.md`.
  Harness scripts/keys live in `~/lawapp-p2-rehearsal-tmp/` (outside the repo; the random DB password
  dies with the deleted project).

---

## 8. Rehearsal verdict → apply-approval gate input

**PASSED.** The amended slice (`83593c2`) applied cleanly up→verify→down on a throwaway project:
up steps 1–5 green (incl. R-1 `extensions.*` resolution and R-2 SETOF confirmed at object level),
§3 reviewer assertions 7/7, §4 matrix **38 pass + 2 RECORDED-Q4** with zero failures, rollback
restored the exact pre-up baseline, and no trigger condition fired.

Per `p2_rehearsal_plan.md` §6 exit criteria, the apply-approval gate (`p0_decision_capture.md` §3 P2
row) is now **unblocked on the rehearsal evidence** — the remaining step before anything touches the
dev project is a **separate explicit apply approval** by the owner (contract §11-P2 exit). Nothing has
touched the dev project, and the rehearsal's throwaway environment is gone.
