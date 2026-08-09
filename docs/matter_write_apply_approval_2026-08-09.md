# LegalHub — F-01 Step 2 Matter-Write Apply Approval Decision Record (2026-08-09)

> **Record type:** the dated decision record that closes the apply-approval
> gate for the F-01 step 2 matter-write slice (`supabase/rpc/create_matter.sql`
> + `supabase/migrations/11_matter_write.sql` (+ `.down`) + the battery-13
> and harness re-scope), per the P2/P3 discipline — the
> `docs/billing_invoices_apply_approval_2026-08-08.md` shape is the
> immediate precedent. This record, **once signed in §6**, is the owner's
> explicit authorization to apply the reviewed + rehearsed slice to the
> shared dev project, with the rollback pairing standing by.
>
> **Status: APPLY APPROVED + EXECUTED 2026-08-09.** All
> decision-level preconditions were MET and evidenced in the repo: the
> design was approved for build, the artifacts are rehearsal-ready, the r1
> rehearsal is **genuinely PASSED with its evidence in the repo**
> (`docs/matter_write_slice_rehearsal_r1_2026-08-09.md`, **`--apply` 44/44 ·
> battery 82/0/0 ×2 — RESULT: PASS**, executed on the Docker scratch
> stack), and the mechanism/RLS-gate review PASSED the same date with its
> two coverage findings remediated in-review
> (`docs/matter_write_slice_review_2026-08-09.md`). The §4 execution
> conditions + §5 exclusions bound the apply, which is now **executed and
> verified on the dev project** (`docs/matter_write_apply_execution_2026-08-09.md`,
> APPLIED 2026-08-09 — one pre-existing demo-data finding surfaced and
> recorded in the execution record §5).
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/f01_step2_matter_write_design_2026-08-09.md`
> (F2-D1…F2-D5, gate sequence) · `docs/matter_write_slice_review_2026-08-09.md`
> (mechanism/RLS-gate review — PASS, R-1/R-2 remediated) ·
> `docs/matter_write_slice_rehearsal_r1_2026-08-09.md` (**r1 PASSED — 82/0/0
> ×2**) · `docs/p4_findings_register_2026-08-09.md` (F-01; §3b static-gate
> correction) · `docs/p4_threat_model_2026-08-09.md` (§4.4/§4.6, §6.11) ·
> `docs/send_message_apply_execution_2026-08-08.md` (the RPC-with-audit-row
> apply precedent this slice extends) · `docs/rollback_plan.md` §1/§5 ·
> `docs/permission_matrix.md` §4/§7 · `supabase/README.md` ·
> `INSTRUCTIONS.md` §2.1/§3/§4.4/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| F-01 finding (tracked) | `docs/p4_findings_register_2026-08-09.md` F-01 — the content-table owner deny was an invariant, not an enforced clause | ✅ Tracked; **step 1 SHIPPED + r1 PASSED** (battery 12 pins the never-assigned invariant; r1 evidence `docs/owner_assignment_battery_rehearsal_r1_2026-08-09.md`, 79/0/0) |
| Step 2 design (gate 3) | `docs/f01_step2_matter_write_design_2026-08-09.md` (F2-D1 creator partner gate · F2-D2 owner refusal · F2-D3 categorical trigger · F2-D4 member guard · F2-D5 nullable assignments) | ✅ **APPROVED FOR BUILD 2026-08-09** |
| Artifacts (rehearsal-ready) | `supabase/rpc/create_matter.sql` · `supabase/migrations/11_matter_write.sql` + `11_matter_write.down.sql` · `supabase/rpc/_down.sql` drop | ✅ Built — **uncommitted working tree at HEAD `f16586e`** (the F-01 slice is rehearsed before commit, per the repo convention; the execution slice commits it first) |
| Battery + harness re-scope | `supabase/tests/13_matter_write_rls.sql` (**16 check blocks**), `scripts/verify_policy_tests.sh` (13 in file list/loops, 11 in the apply order, §1c `refuse_platform_owner_assignment` pin, §1d +`create_matter`), `supabase/README.md` row | ✅ Static `--check` **73/0/0 PASS** (corrected count — register §3b) |
| **Mechanism/RLS-gate review** | `docs/matter_write_slice_review_2026-08-09.md` | ✅ **PASS 2026-08-09** — R-1 (trigger UPDATE arm unpinned) + R-2 (F2-D5 unpinned) found and **remediated in-review** (13.14/13.15/13.16), then re-rehearsed |
| **Ephemeral rehearsal (r1, final battery)** | `docs/matter_write_slice_rehearsal_r1_2026-08-09.md` | ✅ **PASSED 2026-08-09 — genuinely executed** on the Docker scratch stack: `--apply` **44/44** (10 migrations + 14 policies + 20 RPCs) · battery **82/0/0 ×2 — RESULT: PASS** · battery 13's 16 blocks all green · battery 12 no regression · selftest 6/6 |
| **Apply approval (this record)** | this document | ✅ **APPLY APPROVED 2026-08-09** — §6 dated sign-off recorded (in-session, when the owner directed the apply) |
| Apply execution (dev project) | `docs/matter_write_apply_execution_2026-08-09.md` | ✅ **APPLIED + VERIFIED 2026-08-09** — baseline probe → create_matter → 11_matter_write → demo create `d28f1f05-…` (§8 audit row observed) → negatives + smoke all green; one pre-existing demo-data finding recorded (§5 of the execution record) |

## 2. Gate criteria — what the r1 rehearsal proved

Against the ephemeral project built from the committed files (r1, **run and
PASSED — evidence `docs/matter_write_slice_rehearsal_r1_2026-08-09.md`**):

| # | Criterion | r1 evidence (captured) | Verdict |
|---|---|---|---|
| 1 | `--apply` builds the slice cleanly — `11_matter_write.sql` + `create_matter.sql` applied on top of the already-applied 12-table/19-RPC surface | rehearsal §2: **`--apply` 44 passed / 0 failures** (10 migrations + 14 policies + 20 RPCs) | ✅ PASSED |
| 2 | Structural pins hold on the applied posture | rehearsal §3: **12 tables / 12 RLS** · **11 public policies** · publication exactly `messages` (1) · bucket + storage policy unchanged · **§1c `refuse_platform_owner_assignment denied to authenticated`** · **§1d `create_matter(uuid, text, text, uuid, uuid)` EXECUTE granted** | ✅ PASSED |
| 3 | 00–12 regression batteries unaffected | rehearsal §3: fixtures + single-account bound + all twelve prior batteries `— all checks passed`, incl. `12_owner_assignment.sql` (no regression) | ✅ PASSED |
| 4 | `create_matter` enforces F2-D1/F2-D2/F2-D4 + §8 audit | rehearsal §4: partner happy path with RLS read-back (13.01) · owner-as-client/attorney refused (13.02/13.03) · non-partner / cross-org / non-member / suspended / blank-title / anon denied (13.08–13.13) · denied create writes no audit row, allowed writes exactly one redacted `matter created` row (13.06/13.07) | ✅ PASSED |
| 5 | Categorical trigger + F2-D5 | rehearsal §4: direct INSERT with owner assignment refused by the trigger (13.04) · UPDATE re-assignment to owner refused (13.14, review R-1) · INSERT/UPDATE narrowness — non-owner assignees still succeed (13.05/13.15) · orphan create with no assignments succeeds and is invisible under RLS (13.16, review R-2) | ✅ PASSED |

**Verdict: PASSED 2026-08-09** — all five criteria are evidenced by the
genuinely-executed runs (82/0/0 ×2); the owner's §6 signature was recorded
in-session and the apply is **EXECUTED** (evidence
`docs/matter_write_apply_execution_2026-08-09.md`).

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (on signature):** apply the reviewed + rehearsed F-01 step 2
slice to the shared dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`) in
this order:

1. `supabase/rpc/create_matter.sql` — the first matter-**write** surface
   (the `matters` table is read-only today): SECURITY DEFINER, `set
   search_path = public`, `revoke … from public, anon` + `grant … to
   authenticated`; in-function gates F2-D1 (active **partner** of the org,
   via `has_org_role` → `active_membership` status='active' — D-08
   re-derivation), F2-D2 (the platform-owner id, **derived from
   `platform_config`**, never assignable — the F-01 core), F2-D4
   (assignees must be active members of the org — direct `memberships`
   query, the F-11 rule), title validation; §8 audit via `write_audit`
   (redacted summary `matter created`, same implicit transaction).
2. `supabase/migrations/11_matter_write.sql` — the categorical F2-D3
   trigger `refuse_platform_owner_assignment` (`BEFORE INSERT OR UPDATE`
   on `matters`, EXECUTE-revoked, narrow — owner-assignment only, so the
   demo-seed path stays viable); the `.down` pairing (drop trigger +
   function) stands by. **No policy changes** — the public-policy total
   stays 11 (the trigger is a data-layer mechanism, not an RLS arm: no
   client-probe widening, the R-4 constraint that motivated dropping F-01
   step 3).
3. **Live demo smoke (optional, per §4 condition 5):** one matter created
   via the RPC on the dev project's own demo org, assigned to the dev
   project's own demo partner member — the send-message precedent's first
   live INSERT, with the §8 audit row observed. The exact row + ids are
   recorded in the execution record.

plus the post-apply verification (structural subset + the live smoke +
owner-refusal negative) per §4 condition 5, and the execution evidence
record (`docs/matter_write_apply_execution_2026-08-09.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm `create_matter` does not
   yet exist on the dev project, `matters` **does** exist, the current
   `pg_policies` count is **11 public**, tables/RLS **12**, RPC-EXECUTE
   **19** (→ **20** after apply), the trigger function absent, publication
   exactly `public.messages`, storage unchanged — and the demo org +
   demo partner member resolve from the dev project's own rows. The up
   sequence runs against the same baseline the rehearsal proved.
2. **Verify, don't guess (demo smoke):** the demo matter (if created) uses
   the **dev project's own** demo org id + demo partner member id,
   resolved at apply time — never the rehearsal project's synthetic
   `20000000-…`/`10000000-…` ids, never a real account, never real
   client/legal copy.
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `11_matter_write.down.sql` (drop trigger + function) + the
   `rpc/_down.sql` drop for `create_matter` (+ `git revert` of the artifact
   commit) is ready before step 1; **any** trigger condition (an owner
   assignment succeeds through any path, a non-partner or cross-org create
   succeeds, a denied create writes an audit row, a non-member assignee is
   accepted) = immediate revert, never fix-forward.
4. **Per-step verification:** after each step, probe the applied state
   (function exists + granted/revoked correctly → trigger installed on
   `matters` → demo matter scoped to the right org/assignee) with the
   observed output pasted verbatim into the execution record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — **12 tables / 12 RLS / 11 public policies / 20 RPC-EXECUTE** +
   `create_matter` granted, `refuse_platform_owner_assignment` denied; then
   a **live positive** (demo partner creates the demo matter via the RPC;
   the §8 `matter:create` audit row observed with the redacted summary),
   a **live negative** (the same RPC with the owner id assigned is refused;
   anon EXECUTE denied), and the honest expectation that the assigned
   demo client reads the demo matter **0** because the demo clients hold no
   dev membership rows (the matters/documents/messages/storage smoke
   precedent) — recorded as an expectation, never as a defect.
6. **No scope beyond the slice:** no other table/RPC/policy change, no
   changes to the read-side batteries, no realtime, no production, no
   service-role key, no real client/legal data.

## 5. What this approval does NOT authorize

- No other schema, policy, or RPC change beyond §3; **no UPDATE/DELETE
  surface** for matters (the trigger guards re-assignment to the owner;
  any general matter-edit surface is a future slice behind its own gate).
- No change to the Flutter client (`lib/`) — the env-gated client
  matter-creation swap is a separate slice with its own gate (the D-45.1
  E2E remains a separate outstanding verification).
- No battery run against the dev project (the harness hard-refuses the dev
  ref; the battery is ephemeral-only by design).
- No push, no production deployment, no service-role credentials, no real
  data beyond the §3 demo smoke.
- The actual apply **execution** is a separate execution slice with its own
  evidence record; this record authorizes the apply decision only.
- This approval does **not** close the P4 gate: the controlled-rollout
  rehearsal and the dated release approval remain owner-gated.

## 6. Owner sign-off

By signing below, the Project Owner authorizes the §3 apply against the
shared dev project (`eutmvevpskerzpqmwplv`), subject to the §4 execution
conditions and the §5 exclusions, with the rollback pairing standing by.
**Signature is valid now that the r1 rehearsal reports PASSED** and the
mechanism/RLS-gate review is PASS (`docs/matter_write_slice_rehearsal_r1_2026-08-09.md`
is **82/0/0 ×2, genuinely executed**; `docs/matter_write_slice_review_2026-08-09.md`
is **PASS 2026-08-09**).

- **Project Owner:** github.com/mostafasayed118 — **date: 2026-08-09**
  — **approval wording (the documents/messages/storage precedent):**
  "Apply approved — F-01 step 2 matter-write slice (create_matter RPC +
  11_matter_write trigger + harness §1c/§1d pins), per this record §3–§5,
  with the §4 guardrails and rollback pairing."

> **Signed 2026-08-09 in-session (the owner directed the apply execution)
> — the apply gate is open, and the slice is EXECUTED.** The execution
> record (`docs/matter_write_apply_execution_2026-08-09.md`) captures the
> actual run per the §4 guardrails (APPLIED, baseline → RPC → trigger →
> demo create `d28f1f05-…` with the §8 audit row, negatives + smoke green;
> one pre-existing demo-data finding recorded §5). Next: dated matrix §4
> addendum + applied-surface record addendum, then the env-gated client
> swap.

## 7. Ledger (state at preparation)

- The slice was committed **first** as `f2e88cc` (rehearse-before-commit,
  consistent with the r1 evidence), then the apply executed per §3 —
  evidence `docs/matter_write_apply_execution_2026-08-09.md` (APPLIED
  2026-08-09; dev project now 12 tables / 12 RLS / 11 policies / 20
  RPC-EXECUTE + the trigger).
- Static gate on the same tree: `verify_policy_tests.sh --check` **73/0/0
  PASS** (the corrected count — register §3b; the historical 331–343
  figures were printed by the latent UUID-scan bug fixed during the step-2
  build).
- No `lib/`/`test/` change, nothing pushed, no dev-project contact of any
  kind to date.
