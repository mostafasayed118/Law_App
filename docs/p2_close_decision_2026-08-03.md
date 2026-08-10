# LegalHub — P2 Dev Apply Close Decision (2026-08-03)

> **Record type:** The dated **owner decision** that closes the P2 dev apply at
> the decision level per owner decision **D-01(b)** — the §4.5 **manual
> post-apply smoke is NOT executed** against the dev project: no signup, no
> email send, no admin-confirm, no dashboard mutation, no curl against GoTrue;
> **zero external effect**. It sits beside the frozen 2026-08-01 dated records
> (`docs/p2_apply_approval_2026-08-01.md` and
> `docs/p2_apply_execution_2026-08-01.md`) — the same pattern already used for
> the approval record beside the execution record.
>
> **Status: P2 dev apply COMPLETE** on the strength of the **Up 1–5 GREEN probe
> battery** plus the **four ephemeral rehearsals (r2/r4 PASSED)**. The §4.5
> provider-level loop is **DEFERRED as a documented residual risk / known
> limitation** — explicitly **NOT PASSED**, with no implication that the
> deferred loop passed (§1.3 #5: no false assurance).
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Decided on:** 2026-08-03.
>
> **Governed by:** `docs/p0_decision_capture.md` D-05/D-07 ·
> `docs/p2_apply_execution_2026-08-01.md` §6 · `INSTRUCTIONS.md` §1.3 #5,
> §5 (document manual verification, reason, residual risk), §2 (no secret
> disclosure), §1.3 (synthetic data only).

---

## 1. Decision

The **P2 dev apply is CLOSED** at the decision level on the strength of:

1. **Up 1–5 ALL GREEN probe battery on the dev project** (R-4 slice
   `3704a1d`), recorded in the apply execution record §6 — final applied state
   `6 tables / 25 functions / 5 policies / 3 enums`, the R-4 assertion-(a)
   privilege matrix both directions, live `write_audit` denial probes,
   hardening `pg_default_acl` posture, verified owner uid (PII redacted), zero
   residue.
2. **Four ephemeral rehearsals** r1–r4, with **r2 and r4 PASSED**
   (38 PASS + 2 RECORDED, twin gates green on the R-4 slice; r1/r3 each
   surfaced a real finding that was fixed by a slice amendment and re-proven).

The **§4.5 provider-level loop is explicitly DEFERRED — not PASSED**. It is a
documented residual risk, forwarded to P3 end-to-end verification. This
decision records **zero external effect** on the dev project (no signup, no
email, no confirm, no dashboard mutation, no curl).

## 2. Why the provider loop is deferred (the WHY, recorded accurately)

The apply-time smoke (§6) observed, and this decision re-confirms:

- **D-07 keeps email verification REQUIRED at sign-up** — non-negotiable.
- **Dev GoTrue rejects the reserved-TLD synthetic domains** used by the
  rehearsal fixtures (`400 email_address_invalid`).
- A **synthetic gmail-format** confirmation attempt then hit
  **`429 over_email_send_rate_limit`** — the **deliberate 429 halt**: continuing
  would have sent more real confirmation emails to synthetic addresses no one
  can receive, hammering the built-in SMTP rate limit.
- **No controlled inbox exists on this portfolio project** (synthetic data
  only, no real client data, no mail infrastructure approved).

Therefore the full **signup → email-confirm → sign-in → password-reset** loop
**cannot be completed safely** on the dev project today **without either
spamming the built-in SMTP or relaxing D-07** — both out of scope.

**Mechanics (stated accurately, no "zero SMTP sends" framing):** with email
verification enabled, **each signup triggers one real confirmation-send
attempt** to the supplied address; that provider send is exactly what is
rate-limited. The §6 record's `400`s and single `429` are the observed facts
of that mechanism — preserved verbatim in §6, and summarized here as the
reason the loop is deferred rather than forced through.

## 3. What is verified vs. what is NOT verified

| Layer | Verdict |
|---|---|
| **SQL / RLS / RPC surface** (the applied slice) | ✅ **VERIFIED** — by the Up 1–5 probe battery on the dev project AND the repeated rehearsals (r2/r4 PASSED, 38 PASS + 2 RECORDED; twin gates; matrix positive/negative rows; audit self-audits; down-sequence baseline equality). |
| **Provider-level GoTrue rows** (signup → email-confirm → sign-in → password-reset) | ⚠️ **NOT VERIFIED** — unasserted at the provider layer. §6's attempt proved the endpoints are *live* (unknown-user sign-in → `400 invalid_credentials`; password-reset → generic `200 {}`) but did not complete the loop. |

No claim is made that any deferred provider loop passed (§1.3 #5). The apply
closes on the **verified SQL/RLS surface**; the provider loop remains an
accepted residual risk to be re-attempted during **P3 end-to-end verification
once a controlled inbox exists**.

## 4. Reconciliation performed (this batch)

All live references that framed §4.5 as "pending", "PARTIAL", a "manual
smoke prerequisite", or "P2-close prerequisite" were reframed, in the **same
batch**, to this canonical wording:

> **P2 closed (2026-08-03, owner decision) with documented residual risk —
> §4.5 provider loop DEFERRED to P3 end-to-end; see
> `docs/p2_close_decision_2026-08-03.md`.**

| File | References reconciled |
|---|---|
| `docs/p2_apply_execution_2026-08-01.md` | header status, §6 verdict + forward hook, §8, ledger notes |
| `docs/p2_rehearsal_plan.md` | §1 gate row + conclusion |
| `docs/p2_apply_approval_2026-08-01.md` | §1 gate row |
| `docs/p0_decision_capture.md` | §3 P2 row |
| `docs/p3_auth_org_ux_plan.md` | §1/§2/§3/§11 Test plan/§14 ledger refs |
| `supabase/README.md` | status header + "what this directory does NOT authorize" |

The §6 **factual body** (the step-by-step `429`/reserved-TLD/`invalid_credentials`
observations) is preserved **verbatim** as history in the execution record — the
reconciliation changes only the status **frame**, never the facts that explain
the deferral (see Adj-1 on the scope approval).

## 5. Ledger

- **P2 dev apply: CLOSED (decision-level, 2026-08-03).** Up 1–5 probe battery +
  r2/r4 rehearsals = primary close evidence. §4.5 provider loop **DEFERRED** —
  explicitly **NOT PASSED**, residual risk handed to P3 end-to-end verification
  (`docs/p3_auth_org_ux_plan.md` §11/§3).
- This decision reconciles **status framing only**. No new external action was
  taken against the dev project; no credentials were generated or disclosed;
  nothing is committed/pushed without further explicit approval.

## 6. Addendum (2026-08-10) — the provider-loop deferral, explained for future readers

> **Purpose:** one self-contained note so a future reader can understand the
> deferral without re-reading three records. **It changes no status** — the
> loop remains DEFERRED, NOT passed, NOT executed end-to-end. It only states,
> precisely, what was verified and why the remainder is deferred.

**The loop:** signup → email-confirm → sign-in → password-reset, through the
dev project's real GoTrue (`eutmvevpskerzpqmwplv`, `eu-central-1`).

**What WAS verified live (recorded, evidence below):**

1. **The provider endpoints are live and respond correctly at the typed-denial
   level** — `docs/p2_apply_execution_2026-08-01.md` §6 (2026-08-01): sign-in
   of a never-created user → `400 invalid_credentials` (correct denial);
   password-reset `recover` → generic `200 {}` (non-enumerating); sign-up
   attempts → `400 email_address_invalid` (reserved-TLD) then
   `429 over_email_send_rate_limit` (observed provider behavior). Zero residue
   after cleanup.
2. **The full SQL/RLS/RPC surface** (the P2 slice + all nine §14 un-deferrals)
   is applied to the dev project and battery-verified; the **D-45.1
   matter-write verification (2026-08-09)** exercised the live `create_matter`
   flow with a §8 audit row observed through the org-audit read path
   (`docs/f01_client_swap_verification_evidence_2026-08-09.md`); the **final
   E2E walkthrough (2026-08-09)** round-tripped the partner's read surface and
   the audited, rolled-back writes (`docs/final_demo_walkthrough_evidence_2026-08-09.md`).

So: everything that **was** executed **passed**. That is the honest extent of
"verified and working" — no claim is made that the full auth loop passed,
because it was never run (§1.3 #5 — no false assurance).

**Why the full loop is deferred (the reason, precisely):**

1. **D-07** keeps email verification **REQUIRED** at sign-up — non-negotiable.
2. Dev GoTrue rejects the **reserved-TLD synthetic domains** the rehearsal
   fixtures use (`400 email_address_invalid`).
3. A synthetic gmail-format attempt then hit **`429 over_email_send_rate_limit`**
   — the deliberate halt: continuing would have sent more **real confirmation
   emails** to addresses no one can receive, hammering the built-in SMTP rate
   limit.
4. **No controlled inbox exists** on this portfolio project (synthetic data
   only, no mail infrastructure approved).

→ Completing the loop safely requires EITHER a real controlled inbox
(owner-held) OR relaxing D-07 — both out of scope today.

**Path forward (recorded, not executed):** the D-45.1 two-phase plan
(`docs/p2_provider_loop_decision_2026-08-05.md` §5): Phase 1 = ephemeral
rehearsal loop on Docker-capable infra (zero external effect); Phase 2 =
dev-project smoke under a dated apply-approval, only once a controlled inbox
exists. Both plans are **DRAFT — NOT executed** (`p2_provider_loop_phase1_rehearsal_2026-08-08.md`,
`p2_provider_loop_phase2_smoke_2026-08-08.md`).

**No false assurance (§1.3 #5):** this addendum does not claim the loop
passed. The deferral stands as a documented residual risk; it becomes a
mandatory gate only if the project ever moves toward real client data
(`docs/p4_release_readiness_2026-08-09.md` §5).