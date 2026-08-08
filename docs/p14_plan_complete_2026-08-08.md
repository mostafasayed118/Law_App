# LegalHub — §14 Deferred-Capabilities Plan Close (2026-08-08)

> **Record type:** The dated close note that consolidates the **roadmap §14
> per-feature un-deferral program** — the P3 plan-complete convention
> (`docs/p3_plan_complete_2026-08-05.md`): one dated record next to each
> slice's evidence, consolidating the nine SHIPPED rows (gate table §13 of
> `docs/features_roadmap_2026-08-03.md`, now nine-of-ten green) and
> recording exactly what is **still NOT done** — the AI path, owner-blocked
> on D-07/D-08 + undefined scope — with no false assurance
> (INSTRUCTIONS.md §1.3 #5).
>
> **Status: §14 PLAN CLOSE — nine of ten originally-deferred capabilities
> un-deferred and SHIPPED 2026-08-07/08, each with the full per-feature
> discipline (RLS-gate/mechanism review → rehearsal-ready artifacts →
> policy battery + harness → ephemeral rehearsal r1 → dated apply-approval
> → apply → dated matrix addendum → env-gated client swap); full gate green
> on `main` @ `dde0c11` (format 0-changed · analyze clean · suite 1080
> runtime / README 1077 declaration · ledger PASS 115 · policy-battery
> static `--check` 339/0/0).** **AI is the only remaining deferred path.**
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Closed on:** 2026-08-08.
>
> **Governed by:** `docs/p0_decision_capture.md` (P0 closes D-02…D-10b,
> RATIFIED) · `docs/p0_closure_scope_2026-08-05.md` (RATIFIED — the §14
> gate: P0 closes + policy battery + matrix extension) ·
> `docs/permission_matrix.md` §4/§6/§7 (the dated-addendum discipline) ·
> `docs/rollback_plan.md` · `INSTRUCTIONS.md` §1.3 #5, §5, §2.

---

## 1. Decision

The **roadmap §14 deferred-capabilities program is CLOSED at the decision
level (nine of ten)** on the strength of nine dated slice closes, each
with a verified gate on `main` (all key commits re-verified against git
2026-08-08):

| # | Slice (per-feature un-deferral) | SHIPPED | Server apply | Plan / evidence | Suite (runtime / README) |
|---|---|---|---|---|---|
| 1 | Matters read (real-matters path) | 2026-08-07 | ✅ EXECUTED (`docs/matters_apply_execution_2026-08-07.md`) | `docs/matters_real_data_plan_2026-08-07.md` / `docs/matters_real_data_completion_evidence_2026-08-07.md` | 877 / 874 |
| 2 | Documents read (real-documents path) | 2026-08-07 | ✅ EXECUTED (`docs/documents_apply_execution_2026-08-07.md`) | `docs/documents_real_data_plan_2026-08-07.md` / `docs/documents_real_data_completion_evidence_2026-08-07.md` | 897 / 894 |
| 3 | Messages (threads) read | 2026-08-07 | ✅ EXECUTED (`docs/messages_apply_execution_2026-08-07.md`) | `docs/messages_real_data_plan_2026-08-07.md` / `docs/messages_real_data_completion_evidence_2026-08-07.md` | 921 / 918 |
| 4 | Storage read (files + objects, two-layer) | 2026-08-08 | ✅ EXECUTED (`docs/storage_apply_execution_2026-08-08.md`) | `docs/storage_real_data_plan_2026-08-08.md` / `docs/storage_real_data_completion_evidence_2026-08-08.md` | 953 / 950 |
| 5 | Audit surfacing (client-only; RPCs pre-applied 2026-08-01) | 2026-08-08 | ✅ (RPCs applied + battery-pinned; 18-of-18 wired at its close — 19-of-19 after the send-message apply, row 8) | `docs/audit_surfacing_plan_2026-08-08.md` / `docs/audit_surfacing_completion_evidence_2026-08-08.md` | 986 / 983 |
| 6 | Realtime read (message bodies + thread detail) | 2026-08-08 | ✅ EXECUTED (`75f1880`+`35cceb9`) | `docs/realtime_real_data_plan_2026-08-08.md` / `docs/realtime_real_data_completion_evidence_2026-08-08.md` | 1011 / 1011 |
| 7 | Realtime live delivery (publication + subscription + composer) | 2026-08-08 | ✅ EXECUTED (`c96eff7`+`7efb32b`) | `docs/realtime_push_real_data_plan_2026-08-08.md` / `docs/realtime_push_real_data_completion_evidence_2026-08-08.md` | 1045 / 1042 |
| 8 | Audited send path (`send_message` RPC, §8 audit, D-SM3) | 2026-08-08 | ✅ EXECUTED (`docs/send_message_apply_execution_2026-08-08.md`) | `docs/send_message_rpc_plan_2026-08-08.md` / `docs/send_message_real_data_completion_evidence_2026-08-08.md` | 1047 / 1044 |
| 9 | Billing invoices read-metadata (D-11, fake-gateway posture) | 2026-08-08 | ✅ EXECUTED (`docs/billing_invoices_apply_execution_2026-08-08.md`) | `docs/billing_invoices_real_data_plan_2026-08-08.md` / `docs/billing_invoices_real_data_completion_evidence_2026-08-08.md` | 1080 / 1077 |
| 10 | **AI** | — | — | **DEFERRED — owner-blocked (D-07/D-08 + undefined scope)** | — |

**Remaining path (the one not closed):** **AI** stays deferred on
**D-07/D-08** (`docs/p0_decision_capture.md` — authentication policy and
organization semantics, both **Decided 2026-07-31** at the decision level)
**+ undefined scope** — there is no AI feature spec, so there is nothing to
plan. When/if the owner defines an AI scope, it enters the same T1–T8
per-feature discipline behind its own RLS-gate/mechanism review (per the
reconciliation note in `docs/send_message_rpc_plan_2026-08-08.md`). This
is a product-scope gate, **not** a codebase blocker — nothing in the repo
is waiting on AI.

## 2. The last gate table (§13 row — nine of ten green)

| Row | Gate | Gate status (2026-08-08) |
|---|---|---|
| §14 deferred capabilities | **P0 closes (D-02…D-10b) RATIFIED** + policy tests + matrix extension | ✅ **MET — nine of ten un-deferred and SHIPPED** (matters → documents → message_threads → storage → audit surfacing → individual messages/bodies → live delivery → audited send → billing invoices); each slice: review → artifacts → battery + harness (static `--check` 339/0/0, selftest 6/6) → ephemeral r1 genuinely executed → dated apply-approval → apply (dev project) → dated matrix §4/§6 addendum → env-gated client swap. **AI remains deferred** (D-07/D-08 + undefined scope). |

## 3. Consolidated §14 evidence index

Every per-feature un-deferral's gate chain in one place (plan → review →
artifacts → battery → r1 evidence → approval → execution → matrix
addendum → client swap → close evidence):

| Slice | Plan | Gate review | r1 evidence (PASSED) | Apply records (approval + execution) | Completion evidence |
|---|---|---|---|---|---|
| Matters read | `docs/matters_real_data_plan_2026-08-07.md` | `docs/matters_rls_gate_review_2026-08-07.md` | `docs/matters_rehearsal_evidence_r1_2026-08-07.md` | `docs/matters_apply_approval_2026-08-07.md` + `docs/matters_apply_execution_2026-08-07.md` | `docs/matters_real_data_completion_evidence_2026-08-07.md` |
| Documents read | `docs/documents_real_data_plan_2026-08-07.md` | `docs/documents_rls_gate_review_2026-08-07.md` | `docs/documents_rehearsal_evidence_r1_2026-08-07.md` | `docs/documents_apply_approval_2026-08-07.md` + `docs/documents_apply_execution_2026-08-07.md` | `docs/documents_real_data_completion_evidence_2026-08-07.md` |
| Messages read | `docs/messages_real_data_plan_2026-08-07.md` | `docs/messages_rls_gate_review_2026-08-07.md` | `docs/messages_rehearsal_evidence_r1_2026-08-07.md` | `docs/messages_apply_approval_2026-08-07.md` + `docs/messages_apply_execution_2026-08-07.md` | `docs/messages_real_data_completion_evidence_2026-08-07.md` |
| Storage read | `docs/storage_real_data_plan_2026-08-08.md` | `docs/storage_rls_gate_review_2026-08-08.md` | `docs/storage_rehearsal_evidence_r1_2026-08-08.md` | `docs/storage_apply_approval_2026-08-08.md` + `docs/storage_apply_execution_2026-08-08.md` | `docs/storage_real_data_completion_evidence_2026-08-08.md` |
| Audit surfacing | `docs/audit_surfacing_plan_2026-08-08.md` | (matrix §6 addendum; RPCs pre-applied + battery-pinned) | — | — | `docs/audit_surfacing_completion_evidence_2026-08-08.md` |
| Realtime read | `docs/realtime_real_data_plan_2026-08-08.md` | `docs/realtime_rls_gate_review_2026-08-08.md` | `docs/realtime_rehearsal_evidence_r1_2026-08-08.md` | `docs/realtime_apply_approval_2026-08-08.md` + `docs/realtime_apply_execution_2026-08-08.md` | `docs/realtime_real_data_completion_evidence_2026-08-08.md` |
| Realtime push | `docs/realtime_push_real_data_plan_2026-08-08.md` | `docs/realtime_push_gate_review_2026-08-08.md` | `docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md` | `docs/realtime_push_apply_approval_2026-08-08.md` + `docs/realtime_push_apply_execution_2026-08-08.md` | `docs/realtime_push_real_data_completion_evidence_2026-08-08.md` |
| Audited send | `docs/send_message_rpc_plan_2026-08-08.md` | `docs/send_message_gate_review_2026-08-08.md` | `docs/send_message_rehearsal_evidence_r1_2026-08-08.md` | `docs/send_message_apply_approval_2026-08-08.md` + `docs/send_message_apply_execution_2026-08-08.md` | `docs/send_message_real_data_completion_evidence_2026-08-08.md` |
| Billing invoices | `docs/billing_invoices_real_data_plan_2026-08-08.md` | `docs/billing_invoices_gate_review_2026-08-08.md` | `docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md` | `docs/billing_invoices_apply_approval_2026-08-08.md` + `docs/billing_invoices_apply_execution_2026-08-08.md` | `docs/billing_invoices_real_data_completion_evidence_2026-08-08.md` |
| AI | — | — | — | — | **DEFERRED — D-07/D-08 + undefined scope** |

## 4. What is still NOT done (honest, per INSTRUCTIONS §1.3 #5)

- **AI** — the only remaining §14 path; owner-blocked on D-07/D-08 +
  undefined scope. No spec, no plan, nothing committed.
- **Owner-side live E2E on configured builds** — the D-45.1 convention: the
  env-gated client swaps (matters/documents/messages/storage/realtime/
  send/billing) are verified by the typed/fake suite + DI pins + the
  applied server surfaces; a configured-build device round-trip (`.env`,
  git-ignored) remains an owner-side checklist item.
- **No push beyond `dde0c11`** — `main` == `origin/main` (ahead 0); nothing
  else pending.
- **Follow-ups recorded in the slices** (each small, none blocking): the
  storage download affordance (D-STR9), live-delivery edge cases (D-LV4
  reconnect/backfill polish), account-hygiene already resolved
  (2026-08-08), and the audited-send §8 scope as-is.

## 5. Dated close decision

**The roadmap §14 deferred-capabilities program is CLOSED (nine of ten) as
of 2026-08-08.** Nine per-feature un-deferrals shipped back-to-back
2026-08-07/08, each through the full discipline — matters read, documents
read, messages (threads) read, storage read, audit surfacing, realtime
read, realtime live delivery, the audited send path, and billing invoices
read — with the dev-project applies executed under dated approvals, the
dated matrix addenda recorded, the env-gated client swaps shipped, and the
full gate green at every tip (final: suite 1080 runtime / README 1077,
ledger PASS 115, battery static `--check` 339/0/0, `main` @ `dde0c11`,
pushed). **AI is the only remaining deferred path** — it stays deferred on
D-07/D-08 + undefined scope until the owner defines an AI scope, at which
point it enters the same per-feature discipline.
