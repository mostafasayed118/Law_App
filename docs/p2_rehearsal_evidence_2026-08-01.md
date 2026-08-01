# LegalHub — P2 Ephemeral Rehearsal Evidence Record (2026-08-01)

> **Record type:** The dated evidence record mandated by `docs/p2_rehearsal_plan.md`
> §2 ("every step's output pasted into the rehearsal record") and consumed by the
> **apply-approval gate** (`p0_decision_capture.md` §3 P2 row).
> **Status: REHEARSAL RUN — NOT PASSED.** Two findings recorded (R-1, R-2). The
> slice must be amended and re-rehearsed before any dev apply. **Nothing was applied
> to the shared dev project** (`eutmvevpskerzpqmwplv`) — rehearsal ran against a
> throwaway project that was created and deleted for this record.
> **Owner:** Project Owner (github.com/mostafasayed118), 2026-08-01.

---

## 1. Environment & mechanism (verified)

| Item | Value |
|---|---|
| Rehearsal target | **Ephemeral project** `law-app-p2-rehearsal` (ref `yfknoaiutdncbdextrsl`), org `oouytakxadxxuykbmbof` (mustafasayed111's Org — the account that owns the dev project; the CLI was re-logged to the correct account after the free-slot error), region **eu-central-1** (Frankfurt, matches dev) |
| Dev project | `eutmvevpskerzpqmwplv` — **untouched** (read-only probes only, DO-NOT-TOUCH ref) |
| Execution vehicle | `supabase db query --linked` (Management API SQL endpoint) — **no Docker, no psql** available on the machine, so the plan's `supabase db`/`psql` mechanics were executed via the Management API with **role impersonation** (`set role authenticated/anon` + `set_config('request.jwt.claims', …)`) — the standard Supabase RLS test pattern. Policies are exercised through the same evaluation path as production. |
| Key-format note | The project exposes modern keys (`sb_publishable_…`/`sb_secret_…`); legacy `anon` JWT and the publishable key both returned REST 401 at probe time on the brand-new project (provisioning lag; `auth/v1/health` returned 200 with the same key). The SQL path (`TABLE_COUNT`) was the substantive baseline and worked throughout. |
| Baseline (pre-up) | REST probe 401-at-time (provisioning note above); **`TABLE_COUNT=0`** via SQL — confirmed. |

**Mechanism note (recorded, not silently deviated):** the plan §2 said "URL + anon key from the local git-ignored `.env`" — that `.env` holds the **dev project's** credentials and is project-scoped (would not authenticate against the ephemeral project), so the rehearsal used the **ephemeral project's own** anon/publishable key, fetched via the Management API and never committed. No credential from the dev `.env` was used against the ephemeral project, and no credential left the machine.

---

## 2. Up sequence — per-step verification (all GREEN)

| Step | Applied | Verified |
|---|---|---|
| 1 | `migrations/01_org_schema.sql` | ✅ 3 enums (`org_role`, `membership_status`, `invitation_status`); 6 tables; **RLS enabled on all six**; grants exactly per design §5.2 — `authenticated`: `profiles` SELECT + UPDATE `(display_name, locale)` (column-level verified), `organizations`/`memberships`/`invitations` SELECT; **zero `anon` grants**; nothing on `audit_events`/`platform_config` |
| 2 | `migrations/02_rls_functions.sql` | ✅ 7 security-definer helpers; EXECUTE revoked from `public`/`anon` (empty grant query = held); signup trigger `on_auth_user_created` on `auth.users`; `is_platform_owner()` false pre-seed |
| 3 | `migrations/03_platform_config_seed.sql` (token filled) | ✅ exactly **1** `platform_config` row with the **verified** owner id (`8f3c6791-4043-4cd9-9ab0-4dbeb35af902` — read back from `auth.users`, never guessed); `is_platform_owner()` true for owner, false for non-owner |
| 4 | `policies/*.sql` (all 6 files) | ✅ exactly **5** `create policy` statements (`profiles` ×2, `organizations`/`memberships`/`invitations` ×1); **zero** policies on `audit_events`/`platform_config` (RPC-only posture) |
| 5 | `rpc/*.sql` (17 files, excluding `_down`) | ✅ 17 RPCs (excl. the 7 helpers); **EXECUTE granted to `authenticated` only** — zero `anon`/`PUBLIC` rows in the grant query |

---

## 3. Finding R-1 — pgcrypto qualification (confirmed the slice's own flag)

**What:** `invite_member`, `resend_invitation`, `accept_invitation` call `gen_random_bytes(32)` and `digest(...)` **unqualified** under `set search_path = public`. On this hosting, pgcrypto lives only in the `extensions` schema, so the calls fail at runtime:
```
ERROR: function gen_random_bytes(integer) does not exist
```
**This is exactly the risk `supabase/README.md` refinement #6 flagged** ("qualify as `extensions.digest` at apply time if needed. Flagged, not silently handled").

**Rehearsal action:** applied the qualification fix (`extensions.gen_random_bytes` / `extensions.digest`) to the **ephemeral project only** via temp copies (`~/lawapp-p2-rehearsal-tmp/rpc-fixed/`); the committed slice (`supabase/rpc/*.sql`) is **unchanged**. After the fix, the 17-RPC surface worked end-to-end (fixtures provisioned through the real RPC flow).

**Required slice amendment before any dev apply:** qualify as `extensions.*` in those three RPC files (or add `extensions` to the pinned `search_path` after review). Re-rehearse after amending.

---

## 4. Fixtures (synthetic, `.test`-domain, no real PII)

10 identities created in `auth.users` (signup trigger → profiles + audit): owner, `client/attorney/partner/compliance/removed/suspended@org-a.test`, `client/partner@org-b.test`, `dual@lawapp-rehearsal.test` (member of both orgs). org-a and org-b created via `create_organization`; all memberships provisioned through the **real** `invite_member` → `accept_invitation` flow (matching JWT email claims); `suspended@org-a` suspended and `removed@org-a` removed via the partner RPCs. Final membership state verified (org-a: partner/client/attorney/compliance active + removed + suspended; org-b: partner/client; dual in both).

---

## 5. §3 reviewer assertions (5/5 PASS)

| # | Assertion | Result |
|---|---|---|
| 1a | `delete_my_account()` as a disposable user — identity removed, audit row survives (actor FK nulled) | ✅ PASS |
| 1b | `delete_demo_account(uid)` as owner — **auth.users DELETE privilege present** in this hosting; no grant amendment needed | ✅ PASS |
| 2 | Policy-helper-revoke canary — after the step-2 `revoke execute from public, anon`, an active member's org-a roster read still returned the roster (7 rows) with RLS genuinely exercised (`set role authenticated`) | ✅ PASS |
| 3a | `read_org_audit` self-audit — the read produced its own new audit row | ✅ PASS |
| 3b | `read_platform_audit` self-audit — the read produced its own new audit row | ✅ PASS |

**Canary methodology correction (recorded):** the first canary run omitted `set role authenticated`, so as the Management API's superuser session it would have bypassed RLS (vacuous). Re-run with role impersonation — PASS above reflects the genuine RLS path.

---

## 6. §4 matrix — executed rows

### §2 Identity & session — **7/7 PASS** (role-impersonated, RLS genuinely applied)

| Row | Result |
|---|---|
| View own profile (positive) | ✅ client@org-a reads own profile → 1 row |
| View own profile (negative) | ✅ selecting client@org-b's profile → 0 rows |
| Edit own profile (positive) | ✅ own-row `display_name` update committed |
| Edit own profile (negative) | ✅ UPDATE setting foreign `user_id` denied |
| View another user's profile (D-T6) | ✅ partner@org-a selecting client@org-a's profile → 0 rows (own-row-only, amended matrix holds) |
| anon SELECT | ✅ denied, not empty-success (`permission denied for table profiles`) |
| `delete_demo_account` by non-owner | ✅ denied |

### §3 Organization & membership — **HALTED at the tenant-isolation negative → Finding R-2 (see §7)**

The §3 canary negative (client@org-a reading org-b's roster must be **0 rows**) **FAILED: returned 3 rows**. Per `p2_rehearsal_plan.md` §5 trigger conditions ("any negative row starts passing = immediate revert, never fix-forward"), the remaining §3/§5/§6 rows were **not** executed; the down sequence ran instead.

---

## 7. Finding R-2 (CRITICAL) — `is_active_member()` always returns true → cross-tenant SELECT leak

**Atomic diagnostic (single result set, role-impersonated):**
```
session_role       = authenticated          ← RLS genuinely applied (harness sound)
effective_uid      = client@org-a           ← claims impersonation correct
is_active_member(org-b) = TRUE              ← THE BUG
has_client_role_org_b  = false              ← has_org_role (WHERE-guarded) is correct
org_b_rows_visible = 3                      ← cross-tenant roster leak
```

**Root cause (mechanism probe):** `active_membership(p_org)` is declared `returns public.memberships` — a **single composite**, not `SETOF`. In `is_active_member`:
```sql
select exists (select 1 from public.active_membership(p_org))
```
`select 1 from <composite-returning-fn>()` always yields exactly **one row** — even when the composite is `NULL` (probe: `returned_user_id = NULL`, `returned_null = true`, `exists_sees_row = true`, `real_active_rows = 0`). So `exists(...)` is **always true**, hence `is_active_member()` is true for every caller and every org.

**Impact:** the two SELECT policies using it leak cross-tenant reads to any authenticated user:
- `memberships_select_org_roster` — `using (public.is_active_member(organization_id) or auth.uid() = user_id)` → any member reads **any org's roster**
- `organizations_select_active_member` — `using (public.is_active_member(id))` → any authenticated user reads **any org row**

**Not affected:** `has_org_role` filters `where role = …` inside the exists, which removes the NULL row → correct (confirmed `has_client_role_org_b = false`); all RPC gates (`invite_member`, `change_member_role`, audit reads, etc.) therefore behaved correctly, which is why the breach surfaced only at the policy layer.

**Required slice amendment (blocking, before any dev apply):** fix `active_membership` to return `setof public.memberships` (so `exists` sees zero rows when no match) **or** rewrite `is_active_member`/the policies to check `active_membership(p_org) is not null` / use an explicit `exists(select 1 from memberships where organization_id=p_org and user_id=auth.uid() and status='active')`. Amend the slice, then **re-run the entire rehearsal** — R-2 alone blocks the apply approval.

---

## 8. Down sequence — rollback pairing proven (baseline restored)

| Step | Applied | Verified |
|---|---|---|
| 1 | `rpc/_down.sql` | ✅ 17 RPCs dropped |
| 2 | drop the 5 policies | ✅ `remaining_policies = 0` |
| 3 | `03_platform_config_seed.down.sql` | ✅ applied |
| 4 | `02_rls_functions.down.sql` | ✅ applied |
| 5 | `01_org_schema.down.sql` | ✅ applied; **final baseline: `TABLE_COUNT=0`, 0 policies, 0 slice functions, 0 enums** (rollback_plan §1 schema equality met) |

The one table present mid-down was the harness's own `rehearsal_results` table (not slice state); dropped, reaching true `TABLE_COUNT=0`.

---

## 9. Trigger conditions & teardown

- **§5 trigger fired:** §4 negative row (`memberships` cross-org roster) started passing → **immediate revert executed** (down sequence §8), no fix-forward.
- No credential/token/PII appeared in any log/audit (redacted summaries verified in the audit self-audit rows).
- **Teardown:** ephemeral project `law-app-p2-rehearsal` (`yfknoaiutdncbdextrsl`) **deleted** (`supabase projects delete --yes`, confirmed "Deleted project"). Zero residual cloud footprint.
- **Repo state:** working tree pristine except the intentional untracked `docs/kickoff_prompt.md`. All rehearsal scripts/keys live in `~/lawapp-p2-rehearsal-tmp/` (outside the repo; the random DB password dies with the deleted project).

---

## 10. Rehearsal verdict → apply-approval gate input

**NOT PASSED.** Up sequence clean, §3 assertions 5/5, §2 matrix 7/7, down/rollback proven — but **Finding R-2 (critical cross-tenant SELECT leak)** and **Finding R-1 (pgcrypto qualification)** both require slice amendments. Per plan §6, a partial pass is recorded with its fixes and the slice is amended before any dev apply — **never applied dev-ward with known failing assertions**. The apply-approval gate (`p0_decision_capture.md` §3 P2 row) remains **blocked** until: (1) the slice is amended for R-1 + R-2, (2) the rehearsal is re-run on the amended slice and passes, and (3) a separate explicit apply approval is recorded. Nothing has touched the dev project, and the rehearsal's throwaway environment is gone.
