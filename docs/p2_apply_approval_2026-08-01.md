# LegalHub — P2 Apply Approval Decision Record (2026-08-01)

> **Record type:** The dated decision record that closes the apply-approval
> gate (`docs/p0_decision_capture.md` §3 P2 row) per `docs/p2_rehearsal_plan.md`
> §6 and `supabase/README.md` ("Applying it is a **separate approval slice**:
> it requires (1) the ephemeral rehearsal … and (2) explicit owner
> authorization per `INSTRUCTIONS.md` §2.1 gates"). This records the owner's
> explicit authorization to apply the reviewed + amended slice to the shared
> dev project, with the rollback pairing standing by.
>
> **Status: APPLY APPROVED (2026-08-01).** Authorizes the up sequence against
> the dev project **only** (`eutmvevpskerzpqmwplv`, `eu-central-1`), per the
> §4 execution conditions. Nothing else — no storage/realtime (Q4 deferral),
> no matter/doc schema, no production, no service-role key, no real data.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/p2_rehearsal_plan.md` §6 · `docs/p2_schema_rls_design.md`
> §7/§8 · `docs/rollback_plan.md` §1/§2/§5 · `supabase/README.md` ·
> `docs/auth_tenant_authorization_contract.md` §11-P2 · `docs/adr/0007`.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| P2 approval recorded | `docs/p0_decision_capture.md` §3 | ✅ Approved 2026-08-01 |
| RLS-gate design review passed | `docs/p2_schema_rls_design.md` §8 (Q1–Q6) | ✅ Passed 2026-08-01 |
| Reviewed migration slice | `supabase/` (`b5f7e7c`) | ✅ Committed & pushed, REVIEWED (superseded by later amendments — never applied) |
| Slice amendment (R-1/R-2) | `supabase/` (`83593c2`) | ✅ Committed & pushed, REVIEWED (superseded by later amendments — never applied) |
| Slice amendment (R-3) | `supabase/` (`c95dcf4`) | ✅ Committed & pushed, REVIEWED (superseded by later amendments — never applied) |
| Slice amendment (R-4) | `supabase/` (`3704a1d`) | ✅ Committed & pushed, REVIEWED — applied to the dev project 2026-08-01 (execution row below) |
| Ephemeral rehearsal (r1) | `docs/p2_rehearsal_evidence_2026-08-01.md` (`3266c23`) | ✅ Executed — NOT PASSED (findings R-1/R-2) |
| Ephemeral rehearsal (r2, amended slice) | `docs/p2_rehearsal_evidence_r2_2026-08-01.md` (`2c31b27`) | ✅ Executed — PASSED (38 PASS + 2 RECORDED) |
| Ephemeral rehearsal (r3, R-3 slice) | `docs/p2_rehearsal_evidence_r3_2026-08-01.md` (`38e4832`) | ✅ Executed — NOT PASSED (finding R-4) |
| Ephemeral rehearsal (r4, R-4 slice) | `docs/p2_rehearsal_evidence_r4_2026-08-01.md` (`d0379d2`) | ✅ Executed — **PASSED (twin gates green, 38 PASS + 2 RECORDED)** |
| **Apply approval (this record)** | this document | ✅ **APPROVED 2026-08-01** (slice ref reconciled to `3704a1d`) |
| Apply execution (dev project) | docs/p2_apply_execution_2026-08-01.md (3bcd968) | ✅ Executed — Up 1–5 GREEN, §4.5 smoke PARTIAL (manual smoke pending, see evidence §6) |

## 2. Gate criteria confirmation — plan §6 exit criteria vs. r2 evidence (r4 re-confirmed)

The rehearsal passes when, against the ephemeral project, **all five** §6
criteria hold. Each is confirmed against
`docs/p2_rehearsal_evidence_r2_2026-08-01.md` (`2c31b27`):

| # | §6 criterion | r2 evidence | Verdict |
|---|---|---|---|
| 1 | Full up sequence (steps 1–5) applied cleanly with per-step `db diff` evidence recorded | Evidence §2: steps 1–5 all GREEN with per-step verification — enums/tables/RLS/grants; 7 security-definer helpers + `active_membership` **SETOF** confirmed live; exactly 1 `platform_config` row; exactly 5 policies; **17 RPCs applied FAIL=0** (R-1 `extensions.*` resolved) | ✅ MET |
| 2 | Every §4 positive row passed and every negative row denied, recorded row by row (contract §9 matrix) | Evidence §4/§5: §3 assertions 7/7; matrix §2 7/7, §3 17/17, §5 7 PASS, §6 5 PASS + 2 RECORDED (Q4), cross-cutting 2 PASS = **38 PASS + 2 RECORDED, 0 FAIL** | ✅ MET |
| 3 | All three reviewer assertions passed (auth.users DELETE privilege, policy-helper canary, audit self-audit) | Evidence §4: 1a/1b PASS — **auth.users DELETE privilege present** (no grant amendment needed); canary PASS (RLS genuinely exercised, 7-row roster); 3a/3b PASS — both audit-read self-audits produced their own rows | ✅ MET |
| 4 | Full down sequence restored the pre-up baseline (schema equality) | Evidence §6: final baseline `TABLE_COUNT=0`, 0 functions, 0 policies, 0 enums — **byte-equal to pre-up** (rollback_plan §1 equality met) | ✅ MET |
| 5 | No trigger condition fired | Evidence §7: no §5 trigger fired — every negative row denied, including **both R-2 cross-org roster negatives (0 rows)**; no credential/token/PII in logs/audit | ✅ MET |

**Verdict: all five exit criteria are satisfied on the r2 evidence
(`2c31b27`).** The apply-approval gate is unblocked, and the owner records the
apply approval below. No known failing assertion remains (the r1 findings
R-1/R-2 were fixed in `83593c2` and re-verified as resolved in r2).

**r4 re-confirmation (reconciliation of this record, 2026-08-01):** the R-3
amendment (`c95dcf4`) subsequently hardened `authenticated` EXECUTE on the 7
security-definer helpers, which surfaced a **latent slice bug** (r3, finding
R-4: RLS policy quals execute as the querying role, so the policy-referenced
helpers need `authenticated` EXECUTE) and broke the policy read surface until
the R-4 amendment (`3704a1d`) granted EXECUTE on exactly `is_active_member` +
`has_org_role`. The **r4 rehearsal** (`docs/p2_rehearsal_evidence_r4_2026-08-01.md`,
`d0379d2`) re-confirms **all five** §6 criteria on the R-4-amended slice — and
adds the assertion r2 could not make: **`write_audit` stays denied to
`authenticated`/`anon`** (privilege matrix and live probes) while the twin
gates hold (canary roster succeeds; both R-2 cross-org negatives → 0 rows).
This record's slice reference is reconciled from `83593c2` to `3704a1d` below.

## 3. Decision

**APPLY APPROVED.** The Project Owner authorizes applying the reviewed and
amended slice (`supabase/`, as committed in `3704a1d` — the R-4-amended
slice, reconciled from `83593c2` per this record's §2) to the shared dev
project (`eutmvevpskerzpqmwplv`, `eu-central-1`) in the `supabase/README.md`
apply order, subject to the §4 execution conditions.

The approval covers **only**:

1. `migrations/01_org_schema.sql`
2. `migrations/02_rls_functions.sql`
3. `migrations/03_platform_config_seed.sql` — owner-uid token filled from the
   **verified** dev-project `auth.users.id` at apply time (Q1, never guessed)
4. `policies/*.sql`
5. `rpc/*.sql`

plus the post-apply verification per `rollback_plan.md` §1: `supabase db
diff` before/after, `flutter test`, and the manual smoke (sign-in /
sign-up / password-reset against the applied schema — the §2 provider-level
rows the SQL rehearsal could not assert).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline confirmation (plan §2 / §3 step 0):** before step 1,
   verify the dev project is still in its pre-P2 empty state — read-only
   `TABLE_COUNT=0` (or dev-equivalent) probe + `supabase db diff` clean — so
   the up sequence runs against the same baseline the rehearsal proved.
2. **Verify, don't guess (Q1):** the `03_platform_config_seed.sql`
   `<OWNER_USER_ID>` token is filled from the **dev project's own** verified
   `auth.users.id` — **not** the rehearsal project's id (the r4 run's
   `5573f7c6-…` was a synthetic identity in the throwaway project and is
   invalid for the dev seed).
3. **Rollback pairing standing by (rollback_plan §1/§5):** the paired
   `down.sql` files and `rpc/_down.sql` + policy `git revert` are ready
   before step 1; **any** trigger condition (a matrix negative row starts
   passing, credential/token/PII appears where it shouldn't, cross-tenant
   data visible in smoke) = immediate revert, never fix-forward.
4. **Per-step verification:** `supabase db diff` before/after each step,
   output pasted into the apply evidence (rollback_plan §1 discipline).
5. **Post-apply smoke:** sign-in / sign-up / password-reset manual smoke
   against the applied schema (rollback_plan §1) — the matrix §2
   provider-level rows the rehearsal recorded as not SQL-assertable.
6. **No scope beyond the slice:** no storage/realtime (Q4 deferral), no
   matter/doc schema, no production/staging, no service-role key usage, no
   real client/legal data.

## 5. What this approval does NOT authorize

- No storage/realtime policies or objects (Q4 deferral stays deferred).
- No matter/doc schema, no P2+ work, no production/staging, no service-role
  credentials, no real client/legal data.
- No change to the Flutter client (`lib/`).
- The actual apply **execution** is a separate execution slice requiring its
  own commit/push approvals per `INSTRUCTIONS.md` §2/§3; this record
  authorizes the apply decision, not a bundle of commits.

## 6. Ledger

- `docs/p0_decision_capture.md` §3 P2 row — apply-approval status appended
  (2026-08-01), this document as the pointer.
- `docs/p2_rehearsal_plan.md` §1 gate table — rehearsal rows updated to
  executed/PASSED, apply-approval row updated to APPROVED (2026-08-01).
- **Slice reference reconciled (2026-08-01):** this record's §1 gate table,
  §2 criteria, and §3 decision scope now cite the **R-4-amended slice
  `3704a1d`** (reconciled from `83593c2`), with the r4 rehearsal (`d0379d2`)
  re-confirming all five exit criteria plus the `write_audit` denial — per
  the forward hook recorded in `docs/p2_rehearsal_evidence_r4_2026-08-01.md`
  §8 and resolved in `docs/p2_rehearsal_plan.md` in the same batch.
