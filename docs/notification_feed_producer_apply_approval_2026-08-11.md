# LegalHub — Notification Producer Slice: Apply Approval Decision Record (2026-08-11)

> **Record type:** the dated decision record that closes the **apply-approval
> gate (T5)** for the notification **producer** slice
> (`supabase/migrations/15_notification_producer.sql` (+ `.down`) + battery
> 15 + the battery-14 re-pin 4→6/4→6/1 + the harness re-scope
> batteries-01–15), per the established per-feature discipline — the
> `docs/notification_feed_apply_approval_2026-08-11.md` shape is the
> immediate precedent. This record, **once signed in §6**, is the owner's
> explicit authorization to apply the reviewed + rehearsed slice to the
> shared dev project, with the rollback pairing standing by.
>
> **Status: APPLY APPROVED 2026-08-11 — execution pending owner sign-off.**
> All decision-level preconditions were MET and evidenced in the repo: the
> producer plan is **RATIFIED** (D-P1…D-P6 accepted by the owner,
> `docs/notification_feed_producer_slice_plan_2026-08-11.md` — the feed's
> empty-pre-producer state D-N7 was the un-blocking reason), the T1
> mechanism/RLS-gate review **PASSED** the same day
> (`docs/notification_feed_producer_gate_review_2026-08-11.md`, Q1–Q6),
> the T2/T3 artifacts are rehearsal-ready against that contract, the
> harness is re-scoped (batteries-01–15, static `--check` **80/0/0 PASS**,
> selftest **7/0/0 — 6/6 drift classes**), and the r1 rehearsal is
> **genuinely PASSED with its evidence in the repo**
> (`docs/notification_feed_producer_rehearsal_r1_2026-08-11.md` — **`--apply`
> 47/47 · battery 88/0/0 ×2 — RESULT: PASS**, executed on the Docker
> scratch stack, with the empirical re-pin probe: org-a 6 / org-b 1 /
> total 7, zero matter:create residue). The §4 execution conditions + §5
> exclusions bound the apply; this record authorizes the decision only —
> the execution is a separate slice with its own evidence record.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/notification_feed_producer_slice_plan_2026-08-11.md`
> (D-P1…D-P6 — **RATIFIED 2026-08-11**, step 1 MET) ·
> `docs/notification_feed_producer_gate_review_2026-08-11.md` (T1
> mechanism/RLS-gate review — **PASS, Q1–Q6, commit `0f95125`**) ·
> `docs/notification_feed_producer_rehearsal_r1_2026-08-11.md` (**r1
> PASSED — 88/0/0 ×2**) · `docs/permission_matrix.md` §4/§7 (the
> read-only-stays note discipline) · `docs/rollback_plan.md` §1/§5 ·
> `supabase/README.md` · `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| Producer plan (D-P1…D-P6) | `docs/notification_feed_producer_slice_plan_2026-08-11.md` | ✅ **RATIFIED 2026-08-11** — owner accepted D-P1…D-P6 (audit-mirror trigger, minimal v1 event set, fixed redacted summaries, trigger-only EXECUTE-deny, battery-14 re-pin acceptance); un-blocked to T1 |
| **Mechanism/RLS-gate review (T1)** | `docs/notification_feed_producer_gate_review_2026-08-11.md` | ✅ **PASS 2026-08-11** (`0f95125`) — Q1 audit-mirror trigger confirmed · Q2 exact action map vs the RPC sources · Q3 org-from-audit-row + NULL-org skip + gate visibility + atomicity · Q4 privilege posture clean (counts stay 13/13/12, RPC-EXECUTE stays 20) · Q5 exact battery-14 re-pin (4→6/4→6/1) · Q6 harness/apply/rollback contract |
| Artifacts (T2, rehearsal-ready) | `supabase/migrations/15_notification_producer.sql` + `15_notification_producer.down.sql` | ✅ Built — **uncommitted working tree at HEAD `0f95125`** (rehearsed before commit, per the repo convention; the execution slice commits it first) |
| Battery + harness re-scope (T3) | `supabase/tests/15_notification_producer_rls.sql` (14 blocks) · battery-14 re-pin 4→6/4→6/1 · `scripts/verify_policy_tests.sh` (battery 15 in list/cross-ref/FAIL-sweep/run-loop/apply-order + the 1c mirror EXECUTE-deny pin) · `supabase/README.md` row · `00_fixtures.sql` comment | ✅ Static `--check` **80/0/0 PASS** · selftest **7/0/0 (6/6 drift classes)** |
| **Ephemeral rehearsal (r1)** | `docs/notification_feed_producer_rehearsal_r1_2026-08-11.md` | ✅ **PASSED 2026-08-11 — genuinely executed** on the Docker scratch stack: `--apply` **47/47** (12 migrations + 14 policies + 21 RPCs — the producer migration applied cleanly) · battery **88/0/0 ×2 — RESULT: PASS** · battery 15's 14 blocks all green · re-pinned battery 14 (6/6/1) green · batteries 01–13 no regression · **empirical re-pin probe: org-a 6 / org-b 1 / total 7, zero matter:create residue** |
| **Apply approval (this record)** | this document | ⏳ **PENDING OWNER SIGN-OFF** (§6) — the last gate before the dev-project apply |
| Apply execution (dev project) | `docs/notification_feed_producer_apply_execution_2026-08-11.md` | ⏳ Separate execution slice, after sign-off (baseline probe → apply the single migration → per-step probes → live smoke; evidence record) |
| Matrix §4 + applied-surface addenda (T7) | `docs/permission_matrix.md` §4 · `docs/current_applied_surface_2026-08-08.md` §1c-style mechanism note (counts **unchanged** 13/13/12/20 RPC) | ⏳ After apply |
| Feed re-verification (T8) | in-transaction live demo (partner `create_matter` → produced feed row in-txn → `ROLLBACK`, zero residue) + E2E walkthrough re-run **non-vacuously** | ⏳ After apply, dated evidence appended |

## 2. Gate criteria — what the r1 rehearsal proved

Against the ephemeral project built from the committed files (r1, **run and
PASSED — evidence `docs/notification_feed_producer_rehearsal_r1_2026-08-11.md`**):

| # | Criterion | r1 evidence (captured) | Verdict |
|---|---|---|---|
| 1 | `--apply` builds the slice cleanly — `15_notification_producer.sql` applied on top of the already-applied 13-table/12-policy surface | rehearsal §2: **`--apply` 47 passed / 0 failures** (12 migrations + 14 policies + 21 RPCs; `[OK] apply migrations/15_notification_producer.sql`) | ✅ PASSED |
| 2 | The producer is a **data-layer mechanism, not a policy** — counts unchanged (13/13/12, RPC-EXECUTE stays 20) | rehearsal §3: **13 tables / 13 RLS** · **12 public policies** · `mirror_audit_to_notifications denied to authenticated (15 producer D-P4) (f)` — the 1c structural deny-pin | ✅ PASSED |
| 3 | Batteries 01–14 unaffected (13/10's RPC surfaces stay byte-identical green; the re-pinned 14 counts hold) | rehearsal §3: all prior batteries `— all checks passed`, incl. `13_matter_write_rls.sql` and the **re-pinned `14_notification_rls.sql` (6/6/1)**; empirical probe: org-a **6** (4 seeded + 2 producer from battery 10's committed sends), org-b **1**, total **7** | ✅ PASSED |
| 4 | The audit-mirror map is exact (Q2) + redacted (D-P3) + org-scoped through the shipped gate (Q3) | rehearsal §4: 15.01/15.02 — exactly one org-a row per event, fixed summaries (`Demo notification — matter created` / `new message in thread`, category `activity`, types `matter_updated`/`message_received`), title/body never leak, visible under RLS through `notifications_select_org` | ✅ PASSED |
| 5 | D-P6 atomicity + the filter negatives | rehearsal §4: residue checks after every rollback — **zero** `matter:create` rows persist (empirical probe: `'Demo notification — matter created' = 0`) · 15.03–15.05 — `denied` outcome / unmapped action / NULL-org produce nothing (the `is not null` guard) · 15.06 — EXECUTE-deny | ✅ PASSED |

**Verdict: PASSED 2026-08-11** — all five criteria are evidenced by the
genuinely-executed runs (88/0/0 ×2). The apply is authorized by this record
once §6 is signed.

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (on signature):** apply the reviewed + rehearsed producer
slice to the shared dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`) —
**exactly one migration, in this order**:

1. `supabase/migrations/15_notification_producer.sql` — the audit-mirror
   mechanism (D-P1): `create or replace function
   public.mirror_audit_to_notifications()` (security definer, `set search_path
   = public`, the exact D-P2 map — `matter:create`/`message:create` +
   `outcome='allowed'` with the `is not null` org guard, D-P3 fixed redacted
   summaries) + the `AFTER INSERT` trigger
   `audit_events_mirror_notifications` on `public.audit_events` (for each
   row) + `revoke execute ... from public, anon, authenticated` (D-P4, the
   write_audit precedent).
2. **No other migration, no policy file, no RPC file** — the applied counts
   stay **13 tables / 13 RLS / 12 public + 1 storage policies / 20
   RPC-EXECUTE** (D-P5; the trigger is a data-layer mechanism, "trigger is
   not a policy" — the F-01 11_matter_write precedent). **No publication
   change** (exactly `public.messages`).

plus the post-apply verification (structural subset + live smoke) per §4
condition 5, and the execution evidence record
(`docs/notification_feed_producer_apply_execution_2026-08-11.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm `public.mirror_audit_to_notifications()`
   does not exist (pg_proc), the trigger `audit_events_mirror_notifications`
   does not exist (pg_trigger), and the applied surface is exactly the §1b
   state — **13 tables / 13 RLS / 12 public + 1 storage policies / 20
   RPC-EXECUTE**, publication exactly `public.messages`, storage bucket
   unchanged, `audit_events` present with its existing rows (this slice
   touches no data).
2. **Verify, don't guess (demo smoke):** the post-apply smoke uses the
   **dev project's own** rows where identity matters (the active demo
   member of the demo org — `8fa94af0-…`/`ef43087b-…` per the walkthrough
   evidence) — never the rehearsal project's synthetic `20000000-…`/
   `10000000-…` ids. The live positive runs **inside a transaction and
   rolls back** (partner `create_matter` → the produced feed row appears
   in-txn → `ROLLBACK` → zero residue), so the dev feed gains **no**
   permanent rows (D-N7 producer start is intentional — the feed fills
   only with real event traffic after this apply).
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `15_notification_producer.down.sql` (drop trigger + function) + the
   git-revert policy pairing is ready before step 1; **any** trigger
   condition (the function is EXECUTE-able by a client role, the trigger
   fires on a non-mapped action, a produced row carries the matter title /
   message body, the policy count changes, RPC-EXECUTE leaves 20) =
   immediate revert, never fix-forward.
4. **Per-step verification:** after the apply, probe the applied state
   (function present + EXECUTE denied to anon/authenticated → trigger
   present → counts still 13/13/12/20) with the observed output pasted
   verbatim into the execution record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — **13 tables / 13 RLS / 12 public policies / 20 RPC-EXECUTE /
   publication unchanged** + the mirror function EXECUTE-deny; then a
   **live positive** (in-transaction partner `create_matter` → the
   produced org feed row appears → `ROLLBACK` → zero residue) and a
   **live negative** (anon still denied; a non-member still denied — the
   unchanged gate).
6. **No scope beyond the slice:** no other migration/policy/RPC change, no
   table change, no write surface for clients (the trigger is server-side
   and EXECUTE-revoked), no read-flag RPC, no realtime change, no
   production, no service-role key, no real client/legal data.

## 5. What this approval does NOT authorize

- No battery run against the dev project (the harness hard-refuses the dev
  ref; the battery is ephemeral-only by design — the rehearsal already
  proved the mechanism on the scratch stack).
- No client change (`lib/`) — the feed already renders (T8 shipped); a
  client-side producer surface does not exist and is not part of this
  slice.
- No table / policy / RPC change — the applied counts stay **13/13/12/20
  RPC-EXECUTE** (D-P5); no new RPC, no new policy, no new grant.
- No data change — the live smoke is transactional and rolled back; the
  dev feed gains no permanent rows from the apply itself.
- No push, no production deployment, no service-role credentials, no real
  data.
- The actual apply **execution** is a separate execution slice with its
  own evidence record; this record authorizes the apply decision only.

## 6. Owner sign-off

By signing below, the Project Owner authorizes the §3 apply against the
shared dev project (`eutmvevpskerzpqmwplv`), subject to the §4 execution
conditions and the §5 exclusions, with the rollback pairing standing by.
**Signature is valid now that the r1 rehearsal reports PASSED** and the T1
mechanism/RLS-gate review is PASS
(`docs/notification_feed_producer_rehearsal_r1_2026-08-11.md` is
**88/0/0 ×2, genuinely executed**; `docs/notification_feed_producer_gate_review_2026-08-11.md`
is **PASS 2026-08-11**; the plan is **RATIFIED** D-P1…D-P6).

- **Project Owner:** github.com/mostafasayed118 — **date: ____________**
  — **approval wording (the feed/matter-write precedent):** "Apply approved —
  notification producer slice (15_notification_producer.sql, single
  migration, battery 15 + the battery-14 re-pin 4→6/4→6/1 + harness
  re-scope batteries-01–15), per this record §3–§5, with the §4 guardrails
  and rollback pairing."

> **Awaiting the owner's dated signature above.** Once signed, the apply
> gate is open; the execution slice then runs the §4 guardrails and records
> evidence in `docs/notification_feed_producer_apply_execution_2026-08-11.md`,
> followed by the T7 addenda (applied-surface §1c-style mechanism note +
> matrix §4 read-only-stays note) and the T8 non-vacuous feed
> re-verification.

## 7. Ledger (state at preparation)

- The slice sits **uncommitted in the working tree at HEAD `0f95125`**
  (rehearse-before-commit, consistent with the r1 evidence): the 2 new
  migrations + battery 15 + the battery-14 re-pin + the harness re-scope +
  `supabase/README.md` row + `00_fixtures.sql` comment + the r1 evidence
  doc + this record.
- Static gates on the same tree: `verify_policy_tests.sh --check` **80/0/0
  PASS** · selftest **7/0/0 (6/6 drift classes)** · ledger (no-arg CI gate)
  **115/0/0 PASS**.
- No `lib/`/`test/` change, nothing pushed, no dev-project contact of any
  kind to date (the r1 ran exclusively on the scratch stack).
