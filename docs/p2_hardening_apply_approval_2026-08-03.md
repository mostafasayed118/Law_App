# LegalHub — P2 Hardening Apply Approval Decision Record (2026-08-03)

> **Record type:** The dated decision record that authorizes applying the
> **2026-08-03 hardening amendment** to the shared dev project
> (`eutmvevpskerzpqmwplv`) — the counterpart of the P2 base-slice approval
> (`docs/p2_apply_approval_2026-08-01.md`). The amendment: last-partner
> lockout guards in `change_member_role` / `suspend_membership` /
> `remove_membership`, existing-member rejection in `invite_member`, and the
> `_down.sql` revoke-before-drop rework. Governed by the same gates
> (`docs/p2_rehearsal_plan.md` §6, `docs/rollback_plan.md` §1/§2/§5,
> `supabase/README.md`): an ephemeral rehearsal must pass first, then explicit
> owner authorization, then the apply with rollback standing by.
>
> **Status: APPLY APPROVED (2026-08-03).** Authorizes applying exactly the
> five hardened files to the dev project **only** (`eutmvevpskerzpqmwplv`),
> per the §4 execution conditions. Nothing else — no schema/migration/policy
> changes, no storage/realtime (Q4 deferral), no production, no service-role
> key, no real data.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| P2 base slice applied (r4) | `docs/p2_apply_execution_2026-08-01.md` (`3bcd968`) | ✅ Applied — Up 1–5 GREEN on dev |
| Hardening amendment authored | `supabase/rpc/change_member_role.sql`, `suspend_membership.sql`, `remove_membership.sql`, `invite_member.sql`, `_down.sql` (marked "Hardened 2026-08-03 (code-only, NOT yet applied)") | ✅ Committed in this batch |
| Ephemeral rehearsal (r5, hardened slice) | `docs/p2_rehearsal_evidence_r5_2026-08-03.md` | ✅ Executed — **PASSED (16/16 probes green, down pairing proven)** |
| **Apply approval (this record)** | this document | ✅ **APPROVED 2026-08-03** |
| Apply execution (dev project) | `docs/p2_hardening_apply_execution_2026-08-03.md` | ⏳ executed in this batch — see that record |

## 2. Gate criteria confirmation — r5 evidence vs. plan §6 exit criteria

| # | §6 criterion | r5 evidence | Verdict |
|---|---|---|---|
| 1 | Up sequence applied cleanly with per-step verification | Evidence §1/§2: 0-table baseline → steps 1–5 GREEN (6 tables, 7 helpers, 1 seed row, 5 policies, 17 RPCs) | ✅ MET |
| 2 | Affected matrix rows positive **and** negative, recorded | Evidence §2: A1–A3, B1–B2, C1–C2, D1–D2, E1–E2 (permission + cross-org denials), F1–F2 (assertion (a) + twin gates), G1–G3 (token hashing, expiry, audit redaction) = 16/16 | ✅ MET |
| 3 | Reviewer assertions + assertion (a) on the amended surface | Evidence §2 F1: hardened RPCs granted to `authenticated` / denied to `anon`; `write_audit` denied; policy helpers granted; F2: policy read succeeds, direct audit select denied | ✅ MET |
| 4 | Down sequence restored the pairing | Evidence §2 down: amended `_down.sql` ran clean (revokes before drops); 0 slice RPCs remain | ✅ MET |
| 5 | No trigger condition fired | Evidence §3: none — no negative row passed, no credential/token/PII in audit or evidence | ✅ MET |

## 3. Scope of this approval (narrow, explicit)

Only the **function bodies and grants** of the five files above change on the
dev project. Each apply is a `create or replace function` (or, for `_down.sql`,
revokes + drops that are **not** run in the apply — the backout stands by).
The base slice state (6 tables / 25 functions / 5 policies / 3 enums) is
otherwise unchanged; `proowner`, `pg_default_acl`, RLS posture, and the
Q1 owner seed are untouched.

## 4. Execution conditions (mirrors `docs/p2_apply_approval_2026-08-01.md` §4)

1. **Baseline:** read-only probe of the applied state (function count 25,
   RPC count 17, privilege matrix) before any `create or replace` — any drift
   halts the apply.
2. **Mechanism:** `supabase db query --linked` (Management API SQL endpoint),
   read-only probes throughout; no Docker required.
3. **Rollback standing by:** the paired `down.sql` files + `rpc/_down.sql`
   (committed, r5-proven) — any trigger condition = immediate revert, never
   fix-forward.
4. **Probe-battery verification:** every applied file verified by the same
   probe battery as the r5 rehearsal (guards fire, regressions deny, assertion
   (a) holds) — recorded in the execution record.
5. **Zero residue:** synthetic probe fixtures (if any) created on dev are
   removed and verified absent afterwards.
6. **No scope beyond the slice:** nothing else touches the dev project; the
   Flutter client (`lib/`) is untouched by this approval.
