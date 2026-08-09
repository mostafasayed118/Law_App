# LegalHub — P4 Demo-Readiness Release Record (2026-08-09)

> **Record type:** dated **demo/portfolio readiness** approval — **NOT a
> production release, and not a production controlled-rollout rehearsal.**
> Scope: readiness of the F-01 matter-write chain (server slice applied to
> the dev project + the env-gated client swap) and the applied Supabase
> surface for the demo/portfolio posture this project has held since
> `docs/p0_decision_capture.md` (D-03/D-05 — synthetic data only, no real
> clients). This record does **not** authorize any production deployment or
> any real-client-data rollout; if that scope ever changes, the mandatory
> gates listed in §5 re-apply.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
> **Date:** 2026-08-09.
> **Decisions covered:** the six owner decisions recorded 2026-08-09 (§3).

---

## 1. Scope (explicit)

- **Demo/portfolio readiness, not a production release.** The project
  remains a portfolio/demo project with synthetic data only; nothing in
  this record changes that posture.
- Covers the F-01 matter-write chain: the `create_matter` RPC + the
  categorical `refuse_platform_owner_assignment` trigger (applied to the
  dev project 2026-08-09, RPC-EXECUTE 20), the F-12 demo-data remediation,
  and the env-gated client matter-creation swap (built + reviewed
  2026-08-09, commits `93d5ed0` / `178f336`), plus the D-45.1 configured-
  build verification evidence when captured (step 2 of the executing plan).

## 2. Referenced artifacts

- **Threat model / findings:** `docs/p4_findings_register_2026-08-09.md`
  (the F-xx register — the consolidated threat-model/findings ledger) and
  `docs/p4_threat_model_2026-08-09.md`.
- **Rollback plan:** `docs/rollback_plan.md` (canonical rollback plan);
  the F-01 matter-write slice's rollback pairing is recorded in
  `docs/matter_write_apply_approval_2026-08-09.md` §4 and
  `docs/matter_write_apply_execution_2026-08-09.md`.
- **Gate records:** `docs/security_review_gate_record_2026-08-09.md`
  (the P4 status record this record resolves), `docs/matter_write_slice_review_2026-08-09.md`,
  `docs/matter_write_client_slice_review_2026-08-09.md`.

## 3. Decisions recorded (2026-08-09, Project Owner — final)

1. **D-45.1 configured-build verification** — **APPROVED to execute**
   against the dev project (the last gate on the F-01 chain); evidence is
   captured in step 2 of the executing plan.
2. **Q1** (matter-scoped activity section on the details screen) —
   **DEFERRED.** No implementation this slice.
3. **Q4** (fake-write → read-fake handoff) — **DEFERRED.** No
   implementation this slice; the read fake stays untouched.
4. **F-09** (client-role demo data) — **SKIP for now.** No deliberate data
   change unless a live client-role demo is specifically needed later;
   revisit then, not now.
5. **F-02 (MFA), F-05 (invite email delivery), F-07 (throttling
   verification)** — **ACCEPTED as demo-posture**, not implemented. This
   project never handles real client data; these become mandatory gates
   only if that scope ever changes.
6. **P4 release ceremony** — **lightweight version only.** Not a full
   production controlled-rollout rehearsal; this record is the dated
   demo-readiness approval, explicitly scoped as non-production.

## 4. Items this readiness record closes

- **F-02 / F-05 / F-07 acceptance** — register rows flipped to
  `ACCEPTED (demo-posture, 2026-08-09, Project Owner)` with the rationale
  "portfolio/demo project, no real client data; revisit if that scope ever
  changes" (`docs/p4_findings_register_2026-08-09.md`).
- **Q1 / Q4 deferral** — marked `DEFERRED (Project Owner, 2026-08-09) — no
  further action this slice` in the client-slice design §7
  (`docs/matter_write_client_slice_design_2026-08-09.md`).
- **P4 decision-capture row** — resolved from `Blocked / _OPEN_` to
  `DEMO-READY (non-production)` pointing at this record
  (`docs/p0_decision_capture.md` §3, `docs/security_review_gate_record_2026-08-09.md`).

## 5. Explicit non-scope and re-gating

- **Not** a production release, **not** a real-data rollout, **not** a
  staging/store deployment.
- The F-02/F-05/F-07 acceptance is **reversible**: if the project ever
  moves toward real client data, those items become **mandatory gates**
  (MFA for operator accounts, invite-email delivery, throttling
  verification) before any such rollout — the register's remediation paths
  remain the reference.
- Nothing in this record changes the `docs/permission_matrix.md` or any
  server surface; the D-45.1 verification run remains governed by its own
  dated approval guardrails (`docs/configured_build_e2e_checklist_2026-08-08.md`).
