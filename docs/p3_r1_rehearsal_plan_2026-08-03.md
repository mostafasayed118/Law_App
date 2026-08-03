# LegalHub — Phase 3 R1: Ephemeral Rehearsal Plan (Member-Metadata RPC)

> **Record type:** The rehearsal verification plan for the Phase 3 R1
> amendment — `list_org_members_metadata` — mirroring the P2 rehearsal
> discipline (`docs/p2_rehearsal_plan.md`) and the rollback pairing required
> by `docs/p2_schema_rls_design.md` §7 and `docs/rollback_plan.md` §2/§5.
> The gate artifact that turns the REVIEWED design
> (`docs/p3_r1_roster_rpc_design_2026-08-03.md`) into an applied-and-proven
> one.
>
> **Status: READY — NOT EXECUTED.** Requires owner approval of the design
> first; then this plan runs **ephemeral-only** and produces r-series
> evidence (`docs/p3_r1_rehearsal_evidence_r1_2026-08-03.md`). Running this
> plan authorizes nothing on the shared dev project — the apply approval is
> a separate dated record after the rehearsal passes.
>
> **Date:** 2026-08-03. **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/p3_r1_roster_rpc_design_2026-08-03.md` (the
> reviewed amendment) · `docs/permission_matrix.md` §2 addendum (2026-08-03)
> + §9 test contract · `docs/p2_schema_rls_design.md` §7 (rollback pairing) ·
> `docs/rollback_plan.md` §1/§2/§5 (trigger conditions) ·
> `docs/p2_rehearsal_plan.md` (the discipline this mirrors) ·
> `docs/adr/0007`.

---

## 1. Purpose & gate position

This plan proves, against a throwaway environment, that the R1 amendment
**up → verify → down → verify** cleanly and that every positive/negative row
in the matrix §2 addendum behaves as signed — before anything touches the
dev project.

| Gate step | Artifact | Status |
|---|---|---|
| Spec record (R1 + R1 extension) | P3 spec §5 · Phase 2 scope note §3/§5 | ✅ Recorded |
| RLS-gate design review | `docs/p3_r1_roster_rpc_design_2026-08-03.md` + matrix §2 addendum | ⏳ **Awaiting owner review** |
| **Ephemeral rehearsal (this plan)** | `docs/p3_r1_rehearsal_plan_2026-08-03.md` → evidence r1 | 📋 Ready, **not executed** |
| Apply approval for the dev project | explicit dated owner record | ⛔ Blocked on rehearsal pass |
| Apply execution + verify | per apply-approval record | ⛔ Not started |
| Close (matrix addendum takes effect, D-T6 cross-ref, roadmap) | post-apply records | ⛔ Not started |

---

## 2. Environment: ephemeral, throwaway, zero-cost-to-dev

- **Rehearsal target:** an **ephemeral Supabase project** created for this
  rehearsal and torn down after (the P2 default — never the shared dev
  project).
- **Baseline before the amendment:** the **full committed P2 slice exactly
  as applied to dev** (`3704a1d`): migrations `01_org_schema` →
  `02_rls_functions` → `03_platform_config_seed` (owner uid filled from the
  ephemeral project's own verified `auth.users` id), the 5 policy files, and
  the 17 RPC files. The amendment rehearses **on top of** the applied P2
  surface — a `db reset`/re-apply of the committed slice on the ephemeral
  project is acceptable.
- **Connectivity:** URL + anon key from the local git-ignored `.env`. **No
  service-role key anywhere.** No credential leaves the machine.
- **Rehearsal evidence:** every step's output pasted into
  `docs/p3_r1_rehearsal_evidence_r1_2026-08-03.md` (r-series), including the
  inventory snapshots below.
- **Fixtures (synthetic, `.test`-domain, no real PII):** the P2 fixture set
  — `org-a`/`org-b`, `client@org-a.test`, `attorney@org-a.test`,
  `partner@org-a.test`, `compliance@org-a.test`, `client@org-b.test`,
  `partner@org-b.test`, one `removed@org-a.test`, one `suspended@org-a.test`,
  the owner account, and a pending invitation in org-a (token minted by
  `invite_member`, recorded only as evidence of the hash — never the
  literal… the literal is shown once by design; the evidence record logs
  only that `token_hash` = sha-256, per Q2).

---

## 3. Up sequence — apply the reviewed amendment, verifying each step

| Step | Apply | Verify after |
|---|---|---|
| 0 | Baseline: P2 slice applied (see §2) | `TABLE_COUNT=6`; 17 RPCs; **snapshot 1:** `\df public.*` inventory; **snapshot 2:** `\dp` table grants; **snapshot 3:** policy inventory (`select * from pg_policies`); **snapshot 4:** `pg_default_acl`; **snapshot 5:** policy-evaluation grant matrix (`has_function_privilege` on `is_active_member`/`has_org_role`/`write_audit` for anon/authenticated/public) |
| 1 | `supabase/rpc/list_org_members_metadata.sql` (the reviewed file) | 18 RPCs; `has_function_privilege('authenticated', 'public.list_org_members_metadata(uuid)', 'EXECUTE')` → **true**; `anon` → **false**; `public` → **false**; `service_role` → **true** (trusted backend, unchanged) |
| 2 | `rpc/_down.sql` amended with the drop line (reviewed diff) | the file diff is **exactly one added line** (the drop); no other change |
| 3 | Inventory re-assert | snapshots 2–5 **byte-equal** to baseline (no table-grant, policy, default-privilege, or policy-evaluation-grant change); only snapshot 1 gains the one function |

---

## 4. Matrix execution — positive/negative rows for the new RPC

Fixtures per §2. Every row = ≥1 positive (org-a) + ≥1 negative (cross-org
or deny), per contract §9 and the matrix §2 addendum (2026-08-03).

| Row | Positive (must pass) | Negative (must deny) |
|---|---|---|
| Partner reads own org roster | `partner@org-a` `list_org_members_metadata(org-a)` → members (display_name, locale, role, status, created_at, updated_at) + pending invite rows with `invitation_id` | `client@org-a` / `attorney@org-a` / `compliance@org-a` same call → `permission denied` (non-partner denied entirely — own-row-only does not apply) |
| R1 extension: invitation ids | every invited row carries `invitation_id`; every member row carries NULL | `token_hash`/literal token **absent** from all output (Q2) — assert no token material in any column |
| Pending-only invites | pending invite appears; after `revoke_invitation(id)` the row leaves the roster; accepted/expired invites never appear | revoked invite re-appears → fails (denial row: no stale invited row) |
| Cross-org (param swap only) | — | `partner@org-a` calls with `org-b` → `permission denied` (change only the `p_organization_id` param, never the identity) |
| Suspended/removed never authorize | — | after `suspend_membership`, the suspended partner calls → `permission denied`; after `remove_membership` (of a non-last partner), removed partner calls → `permission denied` — stale client session notwithstanding |
| Own-row-only for non-partner roles | — | `client@org-a` selects the RPC → denied; `client@org-a` raw `select * from profiles` where `user_id = partner@org-a` → 0 rows (raw table unchanged) |
| **D-T6 pair (the pivotal assertion)** | `partner@org-a` raw `select * from profiles where user_id = <other member>` → **0 rows**, WHILE `list_org_members_metadata(org-a)` returns that member's `display_name` | profiles policy unchanged — no other path returns names (a non-partner gets neither) |
| Owner no-bypass | — | owner account **without** a partner membership in org-a calls the RPC → `permission denied` (`is_platform_owner()` is not in the guard); owner's `list_members_metadata` still works (owner surface unchanged) |
| anon | — | no session → denied (no grant), not empty-success |
| Cross-org invite leakage | — | org-a's pending invite never appears in any org-b-scoped output (unreachable — org-b is denied before the union) |
| Generic denial (no enumeration) | — | every denial is the same `permission denied` text — cross-org, non-partner, suspended, owner-no-bypass are indistinguishable |

**Cross-cutting asserts (the amendment does not disturb the P2 surface):**

1. **R-4 canary (unchanged behavior):** policy-gated read still succeeds as
   an active member (`select * from memberships where organization_id =
   org-a` → roster) and `write_audit` stays denied as `authenticated` — the
   twin gates hold with the grant inventory byte-equal.
2. **Existing RPC spot-check:** `invite_member` / `resend_invitation` /
   `revoke_invitation` / `accept_invitation` (wrong token → same
   `invalid invitation` text) still behave; `list_members_metadata` still
   owner-only.
3. **Audit:** the successful partner read produced exactly one
   `audit_events` row (`partner:list_org_members`, redacted summary, no
   names/tokens/PII); denied calls produced none.
4. **Inventory byte-equality:** snapshots 2–5 from §3 step 3 hold at the end
   of the up sequence.
5. **Q5 minimality:** the full run requires **no second RPC and no policy
   change**. If any step reveals such a need, the run stops (§6 trigger).

---

## 5. Down sequence — rollback proves the pairing

| Step | Apply | Verify after |
|---|---|---|
| 1 | amended `rpc/_down.sql` (drop line) | 17 RPCs; `list_org_members_metadata` gone; `\df public.*` returns to the baseline inventory; `has_function_privilege('authenticated', ..., 'EXECUTE')` on the dropped name → false |
| 2 | Inventory re-assert | snapshots 1–5 all **byte-equal to the §3 baseline** (schema equality and `pg_default_acl` byte-equal — the R-3 hardening untouched) |
| 3 | Surface sanity | R-4 canary still green (policy read succeeds, `write_audit` denied); matrix §3/§5 spot rows from §4 (2) still behave |

**Trigger conditions (rollback_plan §5 + the design's Q5 trigger) — any of
these = immediate revert, never fix-forward:**

- Any negative row in §4 starts **passing** (a denial that should happen,
  doesn't).
- Any credential, token, or PII appears in logs/audit where it shouldn't —
  including invite token material in RPC output.
- Cross-tenant data becomes visible (org-b rows in org-a output).
- The run needs a **second RPC or any policy change** (Q5 minimality) —
  stop, record the finding, require a new amendment review.

---

## 6. Exit criteria — what "rehearsal passed" means

Against the ephemeral project:

1. The up sequence (§3 steps 0–3) applied cleanly with per-step evidence
   recorded.
2. Every §4 positive row passed and every §4 negative row denied — recorded
   row by row (contract §9's ≥1-positive/≥1-negative contract met). Any
   finding is recorded with its fix and the slice is **amended before any
   dev apply** — never applied dev-ward with known failing assertions (the
   P2 r1–r4 pattern).
3. The D-T6 pair asserted both sides (raw profiles still own-row-only;
   names reachable only through the RPC).
4. Inventory byte-equality held (snapshots 2–5 unchanged; only the one
   function added to snapshot 1); R-4 canary and existing-RPC spot-checks
   green.
5. The down sequence (§5) restored the §3 baseline — snapshots 1–5
   byte-equal — and no trigger condition fired.

The pass evidence (`docs/p3_r1_rehearsal_evidence_r1_2026-08-03.md`)
becomes the input to the separate dated **apply approval** for the dev
project. A partial pass is recorded as a finding with its fix; the amended
slice is re-rehearsed (r2, r3, …) before any apply.

---

## 7. What this plan does NOT authorize

- No apply to the shared dev project, staging, or production — ephemeral
  only.
- No implementation code, no second RPC, no policy change, no invite emails
  (R2), no real data, no service-role key, no compliance claim.
- Running this plan requires its own explicit approval (the owner's design
  review sign-off); even then, nothing reaches the dev project without a
  further dated apply approval.

**Next step:** owner approves the design (`docs/p3_r1_roster_rpc_design_2026-08-03.md`)
and the matrix §2 addendum; this plan then executes ephemeral-only and
produces the r1 evidence record.
