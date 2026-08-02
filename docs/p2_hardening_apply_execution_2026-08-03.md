# LegalHub — P2 Hardening Dev Apply Execution Evidence Record (2026-08-03)

> **Record type:** The dated execution evidence for the apply of the
> **2026-08-03 hardening amendment** to the shared dev project
> (`eutmvevpskerzpqmwplv`), recorded under the apply-approval decision record
> (`docs/p2_hardening_apply_approval_2026-08-03.md`) and its §4 execution
> conditions. It is the apply-side counterpart of the r5 rehearsal
> (`docs/p2_rehearsal_evidence_r5_2026-08-03.md`): the rehearsal proved the
> amendment on a throwaway environment; this record proves the same files
> applied to the real dev project, with the rollback pairing standing by.
> **Status: APPLY EXECUTED — all four files applied and verified GREEN;
> zero residue; no trigger condition fired.**
> **Owner:** Project Owner (github.com/mostafasayed118), 2026-08-03.

---

## 1. Environment & mechanism (verified)

| Item | Value |
|---|---|
| Apply target | **Dev project** `eutmvevpskerzpqmwplv` (`law_project`, West Europe/London), org `oouytakxadxxuykbmbof` |
| Files applied | `supabase/rpc/invite_member.sql`, `change_member_role.sql`, `suspend_membership.sql`, `remove_membership.sql` — the four hardened files (each a `create or replace function`; the amended `_down.sql` is the backout and was **not** run) |
| Authorization | `docs/p2_hardening_apply_approval_2026-08-03.md` — APPLY APPROVED; execution per §4 conditions 1–6 |
| Execution vehicle | `supabase db query --linked` (Management API SQL endpoint) from a scratch CLI project context; read-only probes throughout; role impersonation via `set_config('request.jwt.claim.sub', …)` — no Docker required (as the 2026-08-01 apply) |
| Rollback pairing | Paired `down.sql` files + `rpc/_down.sql` **standing by** (committed in this batch, proven in the r5 rehearsal down sequence) — any trigger condition = immediate revert, never fix-forward (§4 cond 3) |

## 2. Baseline confirmation (§4 cond 1)

| Check | Result |
|---|---|
| Public function count | ✅ `25` (24 slice + the hosting-default `rls_auto_enable`) — identical to the 2026-08-01 applied state; no drift |
| Hardened RPCs present | ✅ all 4 present pre-apply (original bodies) |

**Verdict:** applied-state baseline confirmed before any `create or replace`.

## 3. Apply + per-file verification (all GREEN)

| File | Applied | Verified |
|---|---|---|
| `invite_member.sql` | ✅ `create or replace` succeeded | ✅ **D1 live probe:** existing member's email rejected with `user already has a membership in this organization` (PL/pgSQL line 25) |
| `change_member_role.sql` | ✅ `create or replace` succeeded | ✅ **A2 live probe:** demote of the **last** active partner raises `organization must retain at least one active partner` (line 30); the prior demote with another partner remaining succeeded in-transaction |
| `suspend_membership.sql` | ✅ `create or replace` succeeded | ✅ **B2 live probe:** suspend of the **last** active partner raises `organization must retain at least one active partner` (line 25); suspend of a non-last partner succeeded |
| `remove_membership.sql` | ✅ `create or replace` succeeded | ✅ **C2 live probe:** self-removal raises `cannot remove yourself; use delete_my_account` (line 4); removal of a non-last partner succeeded (last-partner branch is defense-in-depth behind the self-removal guard — r5 evidence §2 C2 reachability note) |
| (regression) | — | ✅ **E1:** non-partner (`client` role) calling `change_member_role` → `permission denied` (line 6) — unchanged |
| (regression) | — | ✅ **F1 assertion (a) post-apply:** `authenticated` EXECUTE **true** on all 4 hardened RPCs; `anon` **false** (spot-checked `change_member_role` + `invite_member`); `write_audit` still **denied** to `authenticated` |

**Final applied state:** public function count unchanged at **25** (replaced,
not added); privilege matrix intact; RLS posture untouched.

## 4. Probe fixtures & residue (§4 cond 5) — zero residue

Synthetic fixtures (unique `30000000-…` UUID space, `.test`-domain emails,
pre-confirmed via direct `auth.users` inserts — no email sent, no GoTrue rate
limit touched): 3 users (partner-a, partner-b, client), 1 org, 3 memberships.
All guard probes ran against them and **every synthetic row was deleted
afterwards, verified by count**: remaining users/profiles/orgs/memberships/
audit/invitations in the probe UUID space = **0 / 0 / 0 / 0 / 0 / 0**. The
pre-existing dev accounts (incl. the Q1 owner) were untouched.

## 5. Trigger conditions & rollback status

- **§4 cond 3 / §5 trigger conditions — NONE fired:** no negative posture
  passed, no credential/token/PII appeared in the evidence (the probe emails
  are synthetic and redacted above by pattern).
- **Rollback pairing standing by:** the committed amended `rpc/_down.sql`
  (revoke-before-drop, r5-proven) restores the pre-hardening RPC set at any
  time per rollback_plan §1/§5.

## 6. Verdict

**All four hardened RPCs applied to the dev project and verified GREEN**
under the approval record's §4 conditions: baseline confirmed (1), mechanism
Management-API SQL (2), rollback standing by (3), probe-battery verification
(4), zero residue (5), no scope beyond the slice (6). The hardening is now
live on the shared dev project; the file headers are flipped to
"Hardened & applied — dev project, 2026-08-03" in the same batch as this
record (comment-only change; functional SQL byte-identical to what was
applied).
