# LegalHub — P2 Dev Apply Execution Evidence Record (2026-08-01)

> **Record type:** The dated execution evidence for the apply of the reviewed
> P2 slice (`3704a1d`, the R-4-amended slice) to the shared dev project
> (`eutmvevpskerzpqmwplv`), recorded under the apply-approval decision record
> (`docs/p2_apply_approval_2026-08-01.md`, `3f0d462`, slice ref reconciled to
> `3704a1d`) and its §4 execution conditions. It is the apply-side counterpart
> of the rehearsal evidence series (`r1`–`r4`): the rehearsals proved the slice
> on throwaway environments; this record proves the same slice applied to the
> real dev project, with the rollback pairing standing by.
> **Status: APPLY EXECUTED — Up 1–5 all GREEN; §4.5 post-apply smoke PARTIAL
> (full signup loop deferred to a manual smoke — see §6).**
> **Owner:** Project Owner (github.com/mostafasayed118), 2026-08-01.

---

## 1. Environment & mechanism (verified)

| Item | Value |
|---|---|
| Apply target | **Dev project** `eutmvevpskerzpqmwplv` (`law_project`, West Europe/London), org `oouytakxadxxuykbmbof` |
| Slice applied | **R-4-amended** `supabase/` from commit `3704a1d` (policy-evaluation grants on `is_active_member(uuid)` + `has_org_role(uuid, public.org_role)`; uniform revoke from `public, anon, authenticated` on all 7 helpers kept; `service_role` never revoked; hardening + down pairing unchanged) |
| Authorization | `docs/p2_apply_approval_2026-08-01.md` (`3f0d462`) — APPLY APPROVED, slice ref reconciled to `3704a1d`; execution per §4 conditions 1–6 |
| Execution vehicle | `supabase db query --linked` (Management API SQL endpoint) from a scratch CLI project context (the repo carries no `config.toml`); read-only probes throughout; no Docker required for the apply itself |
| Rollback pairing | Paired `down.sql` files + `rpc/_down.sql` + policy drops **standing by** (committed at `3704a1d`, proven in the r4 rehearsal down sequence) — any trigger condition = immediate revert, never fix-forward (§4 cond 3) |

---

## 2. Baseline confirmation (§4 cond 1) — dev-equivalent empty, with one recorded hosting default

| Check | Result |
|---|---|
| Tables / policies / enums | ✅ `0 / 0 / 0` — P2-empty |
| Functions | ⚠️ `function_count = 1`, identified read-only as **`rls_auto_enable()`** — the **Supabase hosting default** (zero-arg `SECURITY DEFINER` function `RETURNS event_trigger`, `SET search_path TO 'pg_catalog'`; auto-enables RLS on dashboard-created tables; owner `postgres`). **Not** slice content (no slice function matches), **not** a leftover from the earlier aborted dev apply (which was reverted), and it neither conflicts with nor is touched by the up/down sequences |
| `pg_default_acl` pre-up snapshot | ✅ `postgres`/`public`/`f` = `{postgres=X, anon=X, authenticated=X, service_role=X}` — **byte-identical to the rehearsal pre-up baseline**, so assertion (b) remains comparable on the dev project |

**Verdict:** dev-equivalent empty per §4 cond 1 — the 25-vs-24 function delta (after Up 5) is the hosting-version `rls_auto_enable` default present on the dev project (created 2026-07-25) but absent from the newer ephemeral rehearsal projects; recorded so a future auditor does not flag it as slice drift.

---

## 3. Up sequence — per-step verification (all GREEN on the dev project)

| Step | Applied | Verified |
|---|---|---|
| 1 | `migrations/01_org_schema.sql` | ✅ 3 enums (`org_role`, `membership_status`, `invitation_status`); 6 tables; **RLS on all six**; narrow grants — `authenticated`: `profiles` SELECT + UPDATE `(display_name, locale)`, `organizations`/`memberships`/`invitations` SELECT; **zero `anon` grants**; nothing on `audit_events`/`platform_config` — byte-identical posture to the rehearsal |
| 2 | `migrations/02_rls_functions.sql` (R-4) | ✅ **Assertion (a) both directions** on the dev project: `is_active_member(uuid)` + `has_org_role(uuid, org_role)` **granted** to `authenticated`; `write_audit` + write/maintenance/trigger helpers **denied**; `active_membership` un-granted; anon false on all 7; `service_role` true on all 7. **Live probes**: `write_audit` denied as `authenticated` **and** `anon`; `is_active_member` callable. **Hardening proven**: post-up `pg_default_acl` = `{postgres=X, service_role=X}`. Trigger `on_auth_user_created` present; `is_platform_owner` false pre-seed (claims-driven probe) |
| 3 | `migrations/03_platform_config_seed.sql` (Q1 token filled) | ✅ exactly **1** `platform_config` row; `owner_user_id` = the **Q1-verified dev-project** `auth.users.id` (see §4); `is_platform_owner()` TRUE **only** for the owner, FALSE for a non-owner |
| 4 | `policies/*.sql` (6 files) | ✅ all applied, 0 failures; exactly **5** policies (`profiles` ×2, `organizations`/`memberships`/`invitations` ×1); **zero** policies on `audit_events`/`platform_config` (RPC-only posture) |
| 5 | `rpc/*.sql` (17 files, excl `_down`) | ✅ **all 17 applied, FAIL=0**; each `has_function_privilege('authenticated', …)` = **true** / `anon` = **false**; `proowner` check: all 25 public functions (24 slice + 1 hosting default) owned by `postgres` |

**Final applied state:** `6 tables, 25 functions, 5 policies, 3 enums` — the R-4 slice fully applied to the dev project, mirroring the twice-rehearsed state byte-for-byte on every probe.

---

## 4. Q1 owner decision (§4 cond 2) — verified, never guessed; PII redacted

The seed token (`<OWNER_USER_ID>`) was filled from the **dev project's own** verified
`auth.users.id`, per §4 cond 2 — **not** the rehearsal's synthetic id (`5573f7c6-…`).

- **Owner user id:** `9acfd3b4-96c6-4836-aaa7-defd7864cefb`
- **Verification:** read back from the dev project's `auth.users` via a read-only
  probe (the account predates the apply — created 2026-07-25 during app bootstrap —
  and is a genuine pre-existing human account). **Email redacted from this public
  record** per the session's no-PII discipline; it was verified read-only at apply
  time and is not quoted here. The owner explicitly selected this account.
- **Implication (recorded):** platform-owner capability (`is_platform_owner() =
  true`) now attaches to this pre-existing account; the audit trail will record
  owner actions against it.

---

## 5. §4.4 per-step `db diff` evidence — Docker unavailable; probe battery substitutes (recorded)

`supabase db diff --linked` requires a **local Docker shadow database**, which is not
available on this machine (Docker Desktop not running: "failed to provision the shadow
database"). This is a recorded environment constraint, not a silent skip.

**Substitute per-step evidence (identical to the rehearsal methodology):** every step
was verified by the **probe battery** — object counts, enum/table/RLS/grant posture
(§3), the assertion-(a) privilege matrix, live privilege probes, hardening
`pg_default_acl` snapshots, and the final 6/25/5/3 state. The `db diff` output is the
plan's preferred mechanism; the probe battery produces the same before/after
verification and was the sole evidence vehicle for all four rehearsals. Any future
`db diff` capture can be run once Docker is available as a supplementary check.

---

## 6. §4.5 post-apply smoke — PARTIAL (full loop deferred to a manual smoke)

The smoke exercised the GoTrue/API endpoints against the applied schema with a
**synthetic identity** (cleaned up after; zero residue confirmed). Results:

| Endpoint | Attempt | Result | Interpretation |
|---|---|---|---|
| Sign-up | reserved-TLD synthetic (`…@lawapp-rehearsal.test`) | `400 email_address_invalid` | Dev GoTrue rejects the reserved `.test` TLD — **observed behavior**, attributed to **GoTrue provider config**, not the applied SQL slice |
| Sign-up (retry) | reserved-TLD synthetic (`…@example.com`) | `400 email_address_invalid` | Same reserved-TLD rejection |
| Sign-up (retry) | synthetic gmail-format identity | `429 over_email_send_rate_limit` | **Finding: email confirmation is ENABLED** on the dev project — GoTrue sends a real confirmation email per signup and was rate-limited. (The synthetic address is redacted from this record; cited as "a synthetic gmail-format identity.") |
| Sign-in | password grant, never-created user | `400 invalid_credentials` | ✅ Correct denial for a nonexistent account — endpoint live |
| Password-reset | `recover` | `200 {}` | ✅ Endpoint live; generic non-enumeration response |
| Trigger → profiles | — | 0 profile rows | No user was created, so no trigger fired (the trigger→profile path was proven in r4 via direct `auth.users` inserts) |
| Cleanup | — | 0 remaining users/profiles | Zero residue; applied state 6/25/5/3 intact |

**Verdict: PARTIAL — the apply cannot be declared complete until the full loop
runs.** The provider endpoints are live and respond correctly against the applied
schema, but the complete **signup → email-confirm → sign-in** loop requires a real
(non-reserved-TLD) email, clicking the confirmation link, and a password-grant
sign-in — a **manual smoke** per §4.5's own wording. The `429` stop was a deliberate
halt (not truncation): continuing would have sent more real confirmation emails and
hammered the provider rate limit.

**Forward hook (§4.5 PENDING):** a manual smoke with a real inbox — complete the
signup confirmation flow, then password-grant sign-in, then a password-reset round
trip — and record the result as a dated addendum to this record before the apply is
declared fully complete.

---

## 7. Trigger conditions, residue, & rollback status

- **§5 trigger conditions — NONE fired** during the apply: every negative posture
  held (write-audit denial, zero anon grants, zero cross-tenant surface), and no
  credential/token/PII appeared in the evidence.
- **Residue:** zero (smoke cleanup confirmed 0 users / 0 profiles; the two
  pre-existing dev accounts — one of which is the Q1 owner — were untouched).
- **Rollback pairing standing by:** the committed `down.sql` files, `rpc/_down.sql`,
  and the 5-policy drop are ready; the dev project remains revertible to the
  pre-apply baseline at any time per rollback_plan §1/§5.

---

## 8. Apply evidence verdict → next gates

**Up 1–5 applied and verified GREEN on the dev project** (`3704a1d` slice), under the
apply-approval's §4 conditions. Conditions 1 (baseline), 2 (Q1 verified, PII
redacted), 3 (rollback standing by), 4 (probe-battery substitute for the
Docker-unavailable `db diff` — recorded), and 6 (no scope beyond the slice) are met.
Condition **5 (post-apply smoke) is PARTIAL**: the full signup loop is deferred to a
manual smoke per §6's forward hook.

Nothing beyond the authorized slice touched the dev project; the Flutter client
(`lib/`) was not changed; no storage/realtime, no matter/doc schema, no production,
no service-role key usage, no real client data. The evidence record is the input to
declaring the P2 dev apply complete (pending the §6 manual smoke) and to any
subsequent P3 work on the applied schema.

**Ledger note (forward hook):** `docs/p2_apply_approval_2026-08-01.md` (`3f0d462`)
§1 gate table still reads "Apply execution (dev project) | ⏳ not started — gated by
§4 conditions". This record **is** the apply-execution result (Up 1–5 executed, §4.5
PARTIAL) — the approval record's row must be flipped to "executed — see
`docs/p2_apply_execution_2026-08-01.md`" in a follow-up commit (same batch or
immediate follow-up), so a reader cross-referencing the approval record does not see
"not started" beside an executed evidence record.
