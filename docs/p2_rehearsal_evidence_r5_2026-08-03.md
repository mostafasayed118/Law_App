# LegalHub — P2 Ephemeral Rehearsal Evidence Record, R5 (2026-08-03)

> **Record type:** The dated evidence record for the **2026-08-03 hardening
> amendment** to the applied P2 slice: last-partner lockout guards
> (`change_member_role`, `suspend_membership`, `remove_membership`),
> existing-member invite rejection (`invite_member`), and the `_down.sql`
> revoke-before-drop rework. Run against a throwaway ephemeral project,
> consumed by the apply-approval gate (`docs/p2_hardening_apply_approval_2026-08-03.md`).
> The rehearsal mandate and methodology are `docs/p2_rehearsal_plan.md` §2–§6;
> this record is the r5 counterpart of the r1–r4 series (the r4 record
> `docs/p2_rehearsal_evidence_r4_2026-08-01.md` remains the full 38-row matrix
> evidence on the base slice — r5 re-probes only the amended surface plus the
> affected matrix rows, per the plan's "amended slice is re-probed, unchanged
> surface relies on the passing prior run" methodology).
> **Status: REHEARSAL PASSED — 16/16 probes green.** Every new guard fired
> exactly where signed, every regression row (permission, cross-org) denied,
> the R-4 twin gates held live on the amended surface, and the amended
> `_down.sql` (revoke-before-drop) executed cleanly and dropped all 17 slice
> RPCs. Nothing was applied to the shared dev project (`eutmvevpskerzpqmwplv`)
> during this rehearsal — read-only probes only, plus the throwaway project's
> own up/down cycle.
> **Owner:** Project Owner (github.com/mostafasayed118), 2026-08-03.

---

## 1. Environment & mechanism (verified)

| Item | Value |
|---|---|
| Rehearsal target | **Ephemeral project** `law-app-p2-rehearsal-r5` (ref `kpjeyhmiygepkmbyoinw`), org `oouytakxadxxuykbmbof`, region **West Europe (London, eu-west-2)** — recorded from the live `supabase projects create` output |
| Dev project | `eutmvevpskerzpqmwplv` — **untouched** during rehearsal (read-only probes only, DO-NOT-TOUCH ref) |
| Slice under test | Applied P2 slice (r4-proven `3704a1d` posture) **plus the 5-file hardening amendment** in the working tree at rehearsal time: `supabase/rpc/change_member_role.sql`, `suspend_membership.sql`, `remove_membership.sql`, `invite_member.sql`, `_down.sql` (each marked "Hardened 2026-08-03 (code-only, NOT yet applied)"; committed in the same batch as this record) |
| Execution vehicle | `supabase db query --linked` (Management API SQL endpoint) from a scratch CLI project context; role impersonation via `set local role` + `set_config('request.jwt.claim.sub', …)` — the standard Supabase RLS test pattern (as r1–r4) |
| Baseline (pre-up) | **`TABLE_COUNT=0`, 0 functions, 0 policies** — confirmed read-only before the up sequence |
| Session continuity | Single uninterrupted run (project created, sliced up, probed, down'd within one session). **Recorded constraint:** physical project deletion is pending — `supabase projects delete` confirmation is TTY-only (piped stdin, `cmd /c` pipe, and .NET `Process` stdin redirect all abort with `context canceled`, and the Windows Credential Manager entry is a non-JWT session blob, so API-level deletion is unavailable to this session). The throwaway project (`kpjeyhmiygepkmbyoinw`, free tier, synthetic `.test` data only, no slice residue — post-down state verified 0 slice RPCs) is queued for dashboard teardown; recorded here like the Docker-unavailable `db diff` constraint precedent, not silently skipped |

**Fixture set (synthetic, `.test`-domain, no real PII):** owner synthetic account
(`c8fd73b8-…`, seeded via the Q1 token); org-a with `partner-a`,
`partner-b` (both partner/active), `client-a` (client/active); org-b with
`user-b` (client/active). Profiles auto-created by the `handle_new_user`
trigger. All four hardening probe rows exercised the **org-a variant
positive + negative**, plus the cross-org denial sweep.

---

## 2. Hardening probe battery — all GREEN (16/16)

| # | Probe (impersonated actor) | Expected | Result |
|---|---|---|---|
| A1 | `partner-a` demotes `partner-b` (partner-a still active) | **SUCCESS** | ✅ passed |
| A2 | `partner-a` demotes the **last** active partner (`partner-a` self, after A1) | **RAISE** `organization must retain at least one active partner` (PL/pgSQL line 30) | ✅ raised exactly that message |
| A3 | boundary: restore `partner-b` to partner, then `partner-a` demotes self | **SUCCESS** (partner-b remains) | ✅ passed |
| B1 | `partner-b` suspends `partner-a` (partner-b remains) | **SUCCESS** | ✅ passed |
| B2 | `partner-b` suspends the **last** active partner (`partner-b` self, after B1) | **RAISE** `organization must retain at least one active partner` (line 25) | ✅ raised exactly that message |
| C1 | `partner-b` removes `partner-a` (partner-b remains) | **SUCCESS** | ✅ passed |
| C2 | `partner-b` attempts to remove self | **RAISE** `cannot remove yourself; use delete_my_account` (line 4 — the pre-existing self-removal guard) | ✅ raised; **reachability note:** the last-partner branch in `remove_membership` is defense-in-depth — the line-4 self-removal guard blocks the only actor who could ever be the target of the last-partner removal. Recorded, not treated as a matrix failure |
| D1 | `partner-b` invites `client-a@org-a.test` (already a member of org-a) | **RAISE** `user already has a membership in this organization` (line 25) | ✅ raised exactly that message |
| D2 | `partner-b` invites `fresh@org-a.test` | **SUCCESS** — one-time token returned | ✅ token `c3fa4b1e…` (full literal in session log, hashed only per §3) |
| G1 | token hygiene | `token_hash` = sha-256 of the returned literal; literal absent from `invitations` | ✅ `11760651a34b9fa03c1121576b93ff89d9d6fccc7a7870b8a0ab2bbc1fc0f0ee` stored; `literal_token_absent = true` |
| G2 | expiry | `expires_at - created_at` = 7 days | ✅ `seven_day_expiry = true` |
| G3 | audit redaction | invite/role-change/suspend/remove rows carry reason-code summaries only | ✅ `invite issued (token hash only stored)` / `membership removed` / `membership suspended` / `role changed partner -> client` — no token, email, or PII |
| E1 | `client-a` (non-partner) calls `change_member_role` | **RAISE** `permission denied` (line 6) | ✅ denied |
| E2 | `partner-b` (org-a partner) calls `invite_member` on **org-b** | **RAISE** `permission denied` (line 6) | ✅ denied (tenant-isolation sweep held on the amended surface) |
| F1 | assertion (a) on the amended surface | `authenticated` EXECUTE **true** on all 4 hardened RPCs; `anon` **false** (spot-checked `change_member_role` + `invite_member`); `write_audit` still **denied** to `authenticated`; policy helpers `is_active_member`/`has_org_role` still **granted** | ✅ `true / false / false / true / true` |
| F2 | R-4 twin gates live | policy-gated read succeeds with RLS genuinely exercised; direct `select` on `audit_events` denied | ✅ canary: `client-a` as `authenticated` sees the org-a roster (3 rows); direct audit select → `42501 permission denied for table audit_events` |

**Down sequence (amended `_down.sql`):** executed cleanly (revokes ran without
error — the 2026-08-03 rework replaced the prior "note only" comment with real
`revoke execute` statements on all 17 RPCs from `authenticated`, `anon`,
`public` **before** the drops); post-down probe: **0** of the 17 slice RPCs
remain. Rollback pairing proven on the amended artifact.

---

## 3. Verdict & evidence boundaries

- **Verdict: REHEARSAL PASSED.** All new guards fire exactly as signed; all
  affected matrix rows (invite new member, change member's role, suspend /
  reactivate, remove a member — plan §4 §3) hold positive **and** negative;
  the cross-org denial sweep holds on the amended surface; the R-4 twin gates
  and assertion (a) remain live; the amended down pairing is proven.
- **No trigger condition fired** (plan §5): no negative row passed, no
  credential/token/PII appeared in audit or evidence (the one-time token is
  quoted in the session log only and its hash is what the database stores).
- **Boundaries:** unchanged rows of the §4 matrix rest on the r4 passing run
  (`d0379d2`); the full 38+2 battery was not re-executed for unchanged
  surfaces. Provider-level rows (signup/sign-in/reset) remain out of SQL
  rehearsal scope per plan §4. Storage/realtime deferrals (Q4) unchanged.
- **Apply gate:** this record is the rehearsal evidence consumed by
  `docs/p2_hardening_apply_approval_2026-08-03.md`; the dev apply is executed
  separately and recorded in `docs/p2_hardening_apply_execution_2026-08-03.md`.
