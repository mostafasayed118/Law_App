# LegalHub — Notification-Feed Read Slice: Apply Approval Decision Record (2026-08-11)

> **Record type:** the dated decision record that closes the **apply-approval
> gate (T5)** for the notification-feed read slice
> (`supabase/migrations/14_notifications.sql` (+ `.down`) +
> `supabase/policies/notifications.sql` + battery 14 + harness re-scope),
> per the established per-feature discipline — the
> `docs/matter_write_apply_approval_2026-08-09.md` shape is the immediate
> precedent. This record, **once signed in §6**, is the owner's explicit
> authorization to apply the reviewed + rehearsed slice to the shared dev
> project, with the rollback pairing standing by.
>
> **Status: APPLY APPROVED 2026-08-11 — execution pending owner sign-off.**
> All decision-level preconditions were MET and evidenced in the repo: the
> scope note is **DECIDED** (D-N1…D-N7 ratified; the new surface
> authorized), the T1 mechanism/RLS-gate review **PASSED** the same day
> (`docs/notification_feed_gate_review_2026-08-11.md`, Q1–Q6), the T3
> artifacts are rehearsal-ready against that contract, the harness is
> re-scoped (13/13/12+1/batteries-01–14, static `--check` **78/0/0 PASS**,
> selftest **6/6**), and the r1 rehearsal is **genuinely PASSED with its
> evidence in the repo** (`docs/notification_feed_rehearsal_evidence_r1_2026-08-11.md`,
> **`--apply` 46/46 · battery 86/0/0 ×2 — RESULT: PASS**, executed on the
> Docker scratch stack). The §4 execution conditions + §5 exclusions bound
> the apply; this record authorizes the decision only — the execution is a
> separate slice with its own evidence record.
>
> **Owner:** Project Owner (github.com/mostafasayed118).
>
> **Governed by:** `docs/notification_feed_scope_2026-08-11.md`
> (D-N1…D-N7 — **DECIDED 2026-08-11**) ·
> `docs/notification_feed_gate_review_2026-08-11.md` (T1 mechanism/RLS-gate
> review — **PASS, Q1–Q6**) ·
> `docs/notification_feed_slice_plan_2026-08-11.md` (T1–T8 gate sequence) ·
> `docs/notification_feed_rehearsal_evidence_r1_2026-08-11.md` (**r1
> PASSED — 86/0/0 ×2**) · `docs/permission_matrix.md` §4/§7 (the
> organizations-gate cell split + addendum discipline) ·
> `docs/rollback_plan.md` §1/§5 · `supabase/README.md` ·
> `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Gate step | Artifact | Status |
|---|---|---|
| Scope note (NEW-surface gate, D-N1) | `docs/notification_feed_scope_2026-08-11.md` | ✅ **DECIDED 2026-08-11** — owner ratified §3 (D-N1…D-N7); new surface authorized |
| No-provider precondition (D-N2) | scope note §3 · roadmap line 484 | ✅ MET — read-only v1, no push/FCM/device delivery, **no provider decision needed** |
| **Mechanism/RLS-gate review (T1)** | `docs/notification_feed_gate_review_2026-08-11.md` | ✅ **PASS 2026-08-11** — Q1 redaction structural · Q2 organizations-gate · Q3 matrix cell split · Q4 read-only clean · Q5 direct PostgREST, no RPC · Q6 harness re-scope contract |
| Artifacts (T3, rehearsal-ready) | `supabase/migrations/14_notifications.sql` + `14_notifications.down.sql` · `supabase/policies/notifications.sql` · `supabase/tests/14_notification_rls.sql` (+ §14 fixtures seed) | ✅ Built — **uncommitted working tree at HEAD `b9f2b08`** (rehearsed before commit, per the repo convention; the execution slice commits it first) |
| Battery + harness re-scope | `scripts/verify_policy_tests.sh` (battery 14 in list/cross-ref/FAIL-sweep/run-loop/apply-order; structural pins 13 tables / 13 RLS / 12 public policies; `notifications` grant + forward pins), `supabase/README.md` row | ✅ Static `--check` **78/0/0 PASS** · selftest **6/6 drift classes detected** |
| **Ephemeral rehearsal (r1)** | `docs/notification_feed_rehearsal_evidence_r1_2026-08-11.md` | ✅ **PASSED 2026-08-11 — genuinely executed** on the Docker scratch stack: `--apply` **46/46** (11 migrations + 14 policies + 21 RPCs) · battery **86/0/0 ×2 — RESULT: PASS** · battery 14's 10 blocks all green · prior batteries no regression · re-scoped pins (13/13/12) verified live |
| **Apply approval (this record)** | this document | ⏳ **PENDING OWNER SIGN-OFF** (§6) — the last gate before the dev-project apply |
| Apply execution (dev project) | `docs/notification_feed_apply_execution_2026-08-11.md` | ⏳ Separate execution slice, after sign-off (baseline probe → apply → per-step probes → smoke; evidence record) |
| Matrix §4 + applied-surface addenda (T7) | `docs/permission_matrix.md` §4 · `docs/current_applied_surface_2026-08-08.md` | ⏳ After apply, before the client swap |

## 2. Gate criteria — what the r1 rehearsal proved

Against the ephemeral project built from the committed files (r1, **run and
PASSED — evidence `docs/notification_feed_rehearsal_evidence_r1_2026-08-11.md`**):

| # | Criterion | r1 evidence (captured) | Verdict |
|---|---|---|---|
| 1 | `--apply` builds the slice cleanly — `14_notifications.sql` + `policies/notifications.sql` applied on top of the already-applied 12-table/11-policy surface | rehearsal §2: **`--apply` 46 passed / 0 failures** (11 migrations + 14 policies + 21 RPCs) | ✅ PASSED |
| 2 | Structural pins hold on the applied posture (the Q6 re-scope) | rehearsal §3: **13 tables / 13 RLS** · **12 public policies** · publication exactly `messages` (1) · **`notifications present (new-surface feed)`** · **authenticated SELECT granted** · **anon SELECT absent** | ✅ PASSED |
| 3 | 00–13 regression batteries unaffected | rehearsal §3: fixtures + single-account bound + all thirteen prior batteries `— all checks passed`, incl. `13_matter_write_rls.sql` (no regression) | ✅ PASSED |
| 4 | `notifications_select_org` enforces the matrix §4 cell split (Q2/Q3) | rehearsal §4: partner-a 4 / client-a 4 (**no-role-hierarchy**) / partner-b 1 (**org scoping by count**) · cross-org / owner / suspended / anon denied (14.04–14.07) | ✅ PASSED |
| 5 | D-N3/D-N4/D-N6 structural + data contracts | rehearsal §4: category CHECK rejects unmapped (14.08) · org-delete cascade (14.09) · **column-inventory pin — the redaction is structural** (14.10) | ✅ PASSED |

**Verdict: PASSED 2026-08-11** — all five criteria are evidenced by the
genuinely-executed runs (86/0/0 ×2). The apply is authorized by this record
once §6 is signed.

## 3. Decision (scope this record authorizes — once signed)

**APPLY APPROVED (on signature):** apply the reviewed + rehearsed
notification-feed read slice to the shared dev project
(`eutmvevpskerzpqmwplv`, `eu-central-1`) in this order:

1. `supabase/migrations/14_notifications.sql` — the org-scoped,
   redacted-metadata `public.notifications` table (id, organization_id FK →
   organizations cascade, category CHECK `('appointment','activity','system')`
   — the D-N4 mapping contract, type, synthetic-only summary, server
   timestamp, is_read default false — D-N6 display metadata, never mutated
   in v1), the `notifications_org_ts` composite index, RLS enabled,
   default-deny revoke, and the **narrow SELECT grant to authenticated only
   (no write grant of any kind — D-N2/D-N6, review Q4/Q5)**.
2. `supabase/policies/notifications.sql` — the single SELECT policy
   `notifications_select_org` using the **organizations-gate**
   (`is_active_member(organization_id)` — org metadata, not matter content;
   review Q2), no INSERT/UPDATE/DELETE policy, `platform_owner_admin`
   deny-always by construction (no membership carve-out, D-P0C1(a)).
3. **No RPC** (review Q5 — direct PostgREST read; the matrix row is the
   SELECT cell). **No publication change** (the realtime publication stays
   exactly `public.messages`).

plus the post-apply verification (structural subset + live smoke) per §4
condition 5, and the execution evidence record
(`docs/notification_feed_apply_execution_2026-08-11.md`).

## 4. Execution conditions (guardrails the apply must satisfy)

1. **Pre-up baseline probe (read-only):** confirm `notifications` does not
   yet exist on the dev project, the current `pg_policies` count is **11
   public + 1 storage**, tables/RLS **12**, publication exactly
   `public.messages`, and the storage surface unchanged — the exact
   baseline the rehearsal re-scoped from (12/12/11+1/batteries-01–13).
2. **Verify, don't guess (demo smoke):** the post-apply smoke uses the
   **dev project's own** rows where identity matters (the active demo
   member of the demo org) — never the rehearsal project's synthetic
   `20000000-…`/`10000000-…` ids; the feed carries NO user-identity column,
   so the smoke asserts grant + policy behavior (active member reads the
   org feed; the feed is empty until a producer slice seeds rows — D-N7,
   a separate future slice).
3. **Rollback pairing standing by (rollback_plan §1/§5):**
   `14_notifications.down.sql` (drop policy + table — the review Q6
   contract verbatim) + the git-revert policy pairing is ready before step
   1; **any** trigger condition (a non-member reads a row, a cross-org
   read succeeds, anon reads, a write path appears, the policy count
   misses 12) = immediate revert, never fix-forward.
4. **Per-step verification:** after each step, probe the applied state
   (table exists + RLS on → policy count 12 → SELECT grant present, anon
   absent) with the observed output pasted verbatim into the execution
   record.
5. **Post-apply smoke (dev project):** the structural subset the rehearsal
   proved — **13 tables / 13 RLS / 12 public policies / publication
   unchanged** + `notifications` SELECT granted, anon absent; then a
   **live positive** (an active demo member of the demo org reads the feed
   via PostgREST/psql — the grant + policy resolve, empty row set as
   expected pre-producer) and a **live negative** (a non-member / anon
   read is denied).
6. **No scope beyond the slice:** no other table/RPC/policy change, no
   write path, no read-flag RPC, no prefs filtering (D-N5), no
   push/delivery, no realtime change, no production, no service-role key,
   no real client/legal data.

## 5. What this approval does NOT authorize

- No write surface of any kind — the table has no INSERT/UPDATE/DELETE
  grant, and a producer slice (D-N7 synthetic rows or future real-event
  mapping) is a separate slice behind its own gate.
- No client change (`lib/`) — the env-gated `NotificationGateway` swap +
  feed screen (T8) is a separate slice with its own gate.
- No battery run against the dev project (the harness hard-refuses the dev
  ref; the battery is ephemeral-only by design).
- No push, no production deployment, no service-role credentials, no real
  data, no provider integration (D-N2 — none is needed for the read
  feed).
- The actual apply **execution** is a separate execution slice with its
  own evidence record; this record authorizes the apply decision only.

## 6. Owner sign-off

By signing below, the Project Owner authorizes the §3 apply against the
shared dev project (`eutmvevpskerzpqmwplv`), subject to the §4 execution
conditions and the §5 exclusions, with the rollback pairing standing by.
**Signature is valid now that the r1 rehearsal reports PASSED** and the
T1 mechanism/RLS-gate review is PASS
(`docs/notification_feed_rehearsal_evidence_r1_2026-08-11.md` is
**86/0/0 ×2, genuinely executed**; `docs/notification_feed_gate_review_2026-08-11.md`
is **PASS 2026-08-11**).

- **Project Owner:** github.com/mostafasayed118 — **date: ____________**
  — **approval wording (the matter-write precedent):** "Apply approved —
  notification-feed read slice (14_notifications.sql + policies/notifications.sql
  + harness re-scope 13/13/12+1/batteries-01–14), per this record §3–§5,
  with the §4 guardrails and rollback pairing."

> **Awaiting the owner's dated signature above.** Once signed, the apply
> gate is open; the execution slice then runs the §4 guardrails and records
> evidence in `docs/notification_feed_apply_execution_2026-08-11.md`,
> followed by the T7 matrix §4 + applied-surface addenda and the T8
> env-gated client swap.

## 7. Ledger (state at preparation)

- The slice sits **uncommitted in the working tree at HEAD `b9f2b08`**
  (rehearse-before-commit, consistent with the r1 evidence): 4 new
  artifacts + `00_fixtures.sql` §14 seed + harness re-scope +
  `supabase/README.md` row + this record.
- Static gate on the same tree: `verify_policy_tests.sh --check` **78/0/0
  PASS** · selftest **6/6** · ledger (no-arg CI gate) **115/0/0 PASS**.
- No `lib/`/`test/` change, nothing pushed, no dev-project contact of any
  kind to date.
