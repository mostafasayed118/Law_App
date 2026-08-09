# LegalHub — P4 Findings Register (residual gaps, tracked) — 2026-08-09

> **Record type:** The tracked-findings register extracted from the
> **2026-08-09 review of `docs/p4_threat_model_2026-08-09.md` against the
> current policies and batteries** (`supabase/policies/*.sql`,
> `supabase/tests/*.sql`, `scripts/verify_policy_tests.sh`, the RLS-gate +
> mechanism review records, and the signed matrix). Each finding names the
> gap, the **evidence**, a **severity**, the accountable **owner**, and a
> concrete **remediation path** — the smallest safe slice that closes or
> mitigates it, per `INSTRUCTIONS.md` §2/§3.
>
> **Status: OPEN — a tracking record, not an approval.** Listing a finding
> here does not authorize any implementation; each remediation still passes
> its own gate (scope note → approval → gate stack → dated apply/matrix
> addendum where the server surface changes). **Severity is scoped to the
> portfolio/demo posture** (D-02/D-03: synthetic data only, no real clients);
> every severity note states how it would change if real data ever lands.
>
> **Owner:** Project Owner (github.com/mostafasayed118) is the accountable
> owner of every row; implementation owners are named per finding where the
> repo already assigns one. **Date:** 2026-08-09.
>
> **Method / re-verification:** every finding was re-checked against the
> committed SQL on 2026-08-09 (policy files, batteries, harness, fixtures).
> `bash scripts/verify_policy_tests.sh --check` re-run this date → **73
> passed / 0 warnings / 0 failures** (corrected count — see §3b). The register maps each finding back to
> the threat-model section/residual it came from, so it is traceable either
> direction.

---

## 1. Summary

| ID | Finding | Severity (demo posture) | Status | Threat-model ref | Remediation slice |
|---|---|---|---|---|---|
| F-01 | Content-table owner deny is an **operational invariant**, not an enforced clause | Medium (High if real data) | **STEP 1 SHIPPED + r1 PASSED; STEP 2 BUILT + r1 PASSED + REVIEW PASS + APPLIED 2026-08-09** (dev project; step 3 superseded; F-12 resolved; **client swap BUILT 2026-08-09 (`93d5ed0`) + REVIEW PASS — R-1/R-2 remediated, analyze + 1156-suite green, awaiting D-45.1 configured-build verification**) | §4.6, §6 residual 1 | **Step 1 done** (battery 12 + r1); **step 2 built + r1 PASSED + mechanism review PASS + APPLIED 2026-08-09** (`create_matter` RPC refusal + categorical trigger + battery 13; rehearsal `docs/matter_write_slice_rehearsal_r1_2026-08-09.md` — apply 44/44, battery 82/0/0 ×2; review `docs/matter_write_slice_review_2026-08-09.md` — R-1/R-2 remediated, battery 16 blocks; **execution `docs/matter_write_apply_execution_2026-08-09.md`** — demo create `d28f1f05-…` + §8 audit live, negatives + smoke green, **F-12 surfaced**); step 3 dropped — the trigger achieves the categorical deny without the R-4 probe widening |
| F-02 | MFA/SSO deferred; single owner account is the highest-value target | Medium (High if real data) | ACCEPTED (demo-posture, 2026-08-09, Project Owner) | §4.6, §6.1 | v1 MFA slice for the owner account (GoTrue TOTP) |
| F-03 | Signed-URL TTL window after membership removal (D-STR4) | Low (Medium if real files) | ACCEPTED (recorded D-STR4) | §4.4, §6.2 | Shorten TTL; re-check membership at fetch time when a download surface ships (D-STR9) |
| F-04 | Realtime delivery verified by RLS proxy, not a live websocket round-trip | Low (verification gap) | OPEN | §4.4, §6.3 | Execute D-45.1 configured-build E2E; D-LV4 polish slice |
| F-05 | Invite emails (R2) absent; one-time token delivered out-of-band | Low-Medium | ACCEPTED (demo-posture, 2026-08-09, Project Owner) | §4.1, §6.4 | GoTrue email-trigger slice (provider config + review) |
| F-06 | Accept-invite one-time token rides in a deep-link URL | Low | OPEN | §4.1 | Document exposure; verified app-links; optional server-side short-lived code |
| F-07 | No throttling beyond GoTrue defaults (D-07) | Low | ACCEPTED (demo-posture, 2026-08-09, Project Owner) | §4.5, §6.7 | Verify provider rate-limit settings; revisit before real-data rollout |
| F-08 | Denied RPC attempts not logged as `denied` audit rows (deliberate) | Info / Low | ACCEPTED (10.09 pins the negative) | §4.3, §6.8 | Ops decision; optional opt-in `denied` outcomes behind a review |
| F-09 | Demo clients hold no membership rows — client-side positives not demoable live | Low (data posture) | ACCEPTED (recorded as designed) | §6.5 | Owner-approved deliberate data action when a client demo is wanted |
| F-10 | Provider/hosting posture assumed, not verified (rate limits, storage defaults, JWT `email` claim) | Low | OPEN | §4.5, §6.6 | Read-only dev-project probes + GoTrue config check |
| F-11 | Self-scoped helpers exposed as PostgREST `/rpc/` endpoints | Info (safe today) | ACCEPTED (R-4 note) | §4.6 | Keep "self-scoped only" as a standing RLS-gate review criterion |

---

## 2. Findings detail

### F-01 — Content-table owner deny is an operational invariant, not an enforced clause

- **Gap:** the matrix promises `platform_owner_admin → ❌ deny, always` on
  every matter/content row (§4 + §5), but **no content policy contains an
  owner-deny arm** — the denial rests entirely on the fact that owner
  accounts are never assigned. The batteries record this explicitly: *"if an
  owner account were ever assigned, this policy WOULD grant — the categorical
  matrix deny is an operational invariant, not a policy guarantee; fixtures
  never create that state"* (04.07, 08.08; the same Q4 residual is recorded
  in every RLS-gate review).
- **Evidence:** `supabase/policies/matters.sql` / `documents.sql` /
  `message_threads.sql` / `messages.sql` / `files.sql` /
  `storage_objects.sql` / `invoices.sql` — none reference the owner;
  `supabase/tests/04_matter_rls.sql` CHECK 04.07; `08_message_rls.sql` CHECK
  08.08; per-slice RLS-gate reviews Q4.
- **Why it matters:** a single human/process error (assigning the owner id in
  a demo seed or a future matter-write path) would silently grant the owner
  matter access with **no battery that could catch it** — the current owner
  deny-rows pass because the fixtures never create that state.
- **Severity:** Medium for the demo posture; **High** if real matter data
  ever lands (the §5 boundary is the project's highest-risk row).
- **Owner:** Project Owner (accountable); engineering (slice owner at
  implementation).
- **Status:** **STEP 1 SHIPPED 2026-08-09 + r1 REHEARSAL PASSED (2026-08-09,
  79/0/0 ×2 on a local ephemeral scratch stack)** —
  `supabase/tests/12_owner_assignment.sql` (10 non-vacuous check blocks;
  owner id **derived from `platform_config`**, not hardcoded) + harness wiring
  (`scripts/verify_policy_tests.sh`: `BATTERY_FILES`, static UUID scan,
  FAIL-marker loop, `run_battery`, selftest glob) + `supabase/README.md`
  battery-table row (also back-filled the stale 09–11 rows). Static `--check`
  re-run green (§4); live evidence
  `docs/owner_assignment_battery_rehearsal_r1_2026-08-09.md` (12 ran green
  with no regression across 01–11). **STEP 2 BUILT 2026-08-09** from the
  approved design (`docs/f01_step2_matter_write_design_2026-08-09.md`):
  `supabase/rpc/create_matter.sql` (F2-D1 partner gate + F2-D2 owner refusal
  + F2-D4 member guard + §8 audit), `supabase/migrations/11_matter_write.sql`
  (+ `.down`) with the categorical F2-D3 trigger,
  `supabase/tests/13_matter_write_rls.sql` (16 check blocks, incl. anon),
  harness wiring (13 in file list/loops; 11 in the apply order; §1c pin for
  `refuse_platform_owner_assignment`; §1d +`create_matter`), README row —
  **r1 PASSED 2026-08-09** (evidence
  `docs/matter_write_slice_rehearsal_r1_2026-08-09.md`: `--apply` 44/44,
  full battery **82/0/0 ×2** on the ephemeral stack, battery 13 all 16
  blocks green, 12 no regression). **Mechanism/RLS-gate review PASSED
  2026-08-09** (`docs/matter_write_slice_review_2026-08-09.md`): R-1
  (UPDATE arm unpinned → 13.14/13.15) + R-2 (F2-D5 unpinned → 13.16) found
  and remediated in-review, re-run 82/0/0 ×2. Next: dated apply → matrix §4
  addendum. **Step 3 is superseded** by the trigger (design §10).
- **Remediation path (smallest safe slice, in order):**
  1. **Now (structural, client + battery only) — DONE 2026-08-09:** the new
     battery (`supabase/tests/12_owner_assignment.sql`) asserts **0 rows**
     where `assigned_client_id`/`assigned_attorney_id` (or any content-table
     uuid column) reference the platform-owner id, with non-vacuity
     preconditions (owner row present; assignment set non-empty) — the
     invariant is now a pinned property across the whole content surface
     (matters is the single assignment source of truth). No policy changed;
     no server gate needed (battery + harness only).
  2. **When the first matter write slice ships (future) — BUILT 2026-08-09
     (REHEARSAL-READY, NOT applied)** per the approved design
     (`docs/f01_step2_matter_write_design_2026-08-09.md`): the `create_matter`
     RPC refuses owner assignment (F2-D2, derived from `platform_config`), a
     `BEFORE INSERT OR UPDATE` trigger on `matters` refuses it categorically
     (F2-D3), and battery 13 pins the refusal (positive + negative +
     trigger-layer + §8-negative rows). Awaiting: mechanism review → r1
     rehearsal → dated apply → matrix §4 addendum.
  3. **Optional hardening (needs a review of the R-4 tradeoff):** an explicit
     owner-deny arm in content policies via a dedicated EXECUTE-granted
     definer helper. **Caveat:** `is_platform_owner()` is deliberately
     EXECUTE-revoked (the capability is never client-readable/probable), so
     this widens the probe surface — the RLS-gate review must weigh it before
     any approval.

---

### F-02 — MFA/SSO deferred; the single owner account is the highest-value target

- **Gap:** `platform_owner_admin` is bound to exactly one account (D-P0C3)
  with broad metadata-only power; authentication is email+password only
  (D-07 — MFA, SSO/SCIM, passwordless deferred to v1).
- **Evidence:** `docs/p0_decision_capture.md` D-07; threat model §4.6 /
  §6 residual 1; battery 03 (single-account bound).
- **Severity:** Medium for the demo posture (synthetic data, no real impact
  from a compromise beyond the demo project); **High** if the project ever
  moves toward real data.
- **Owner:** Project Owner (product decision); engineering (v1 slice).
- **Status (2026-08-09):** ACCEPTED as demo-posture — portfolio/demo
  project, no real client data; revisit if that scope ever changes. Not
  implemented (see `docs/p4_release_readiness_2026-08-09.md`).
- **Remediation path:** v1 auth slice — enable GoTrue **TOTP MFA** on the
  owner account (and any future operator account) before any release beyond
  the dev project; record the credential-hygiene rule (never share the owner
  password; keep the `.env` anon-key-only) in the P4 release approval.

---

### F-03 — Signed-URL TTL window after membership removal (D-STR4)

- **Gap:** matrix §6 requires *"reuse a stale signed URL after membership
  removal → denied"*; enforcement is **at generation** (minting is RLS-gated)
  **+ TTL**, not mid-flight — an already-issued URL stays valid until its
  TTL expires. Recorded honestly in the storage gate review as a
  future-facing negative, not a battery row.
- **Evidence:** `docs/storage_rls_gate_review_2026-08-08.md` D-STR4;
  threat model §4.4 / §6 residual 2; matrix §6 addendum.
- **Severity:** Low (demo posture, 4 demo files, no download affordance);
  **Medium** if real files are ever stored.
- **Owner:** Project Owner; engineering (when a download surface is approved).
- **Remediation path:** pair with the recorded **D-STR9** download
  affordance slice: route byte reads through a path that **re-checks
  membership at fetch time** (removing the window), and/or shorten issued
  TTLs to the minimum practical lifetime (contract §4.3). Add a battery row
  once the fetch path exists.

---

### F-04 — Realtime delivery verified by RLS proxy, not a live websocket round-trip

- **Gap:** the batteries prove the delivery **gate** (Realtime RLS: 09.11 /
  09.12 — assigned reader sees the row, suspended/cross-org/owner see 0) and
  the publication pin (exactly `messages`), but no live websocket round-trip
  has been observed from the app. The env-gated configured-build E2E
  (D-45.1) — the one verification the suite cannot do — is **not yet
  executed**.
- **Evidence:** `supabase/tests/09_realtime_push.sql` 09.11/09.12; harness
  §1f publication pin; `docs/configured_build_e2e_checklist_2026-08-08.md`;
  threat model §4.4 / §6 residual 3; D-LV4 recorded follow-up.
- **Severity:** Low — a verification gap, not a demonstrated defect.
- **Owner:** Project Owner (executes D-45.1 on a configured build);
  engineering (D-LV4 polish).
- **Remediation path:** execute the D-45.1 checklist (`.env` build, partner
  sign-in, live send → immediate delivery observed, denied-role 0 events)
  and record the evidence in `docs/`; ship the D-LV4 reconnect/backfill
  polish as a small client slice.

---

### F-05 — Invite emails (R2) absent; one-time token delivered out-of-band

- **Gap:** invitations are email-matched but the one-time token is shown
  **in-app to the inviter exactly once**; no GoTrue email trigger delivers it
  to the invitee (roadmap Phase 3.3 R2). Risk: the inviter forwarding the
  token over an unsecured channel; no enumeration signal to non-partners
  (D-10a) is preserved either way.
- **Evidence:** `supabase/rpc/invite_member.sql` (token returned once,
  sha-256 stored); `docs/features_roadmap_2026-08-03.md` Phase 3.3 (R2);
  threat model §4.1 / §6 residual 4.
- **Severity:** Low-Medium (single-use token, hashed at rest, 7-day expiry —
  the exposure is delivery-channel hygiene, not storage).
- **Owner:** Project Owner (provider-config decision); engineering (slice).
- **Status (2026-08-09):** ACCEPTED as demo-posture — portfolio/demo
  project, no real client data; revisit if that scope ever changes. Not
  implemented (see `docs/p4_release_readiness_2026-08-09.md`).
- **Remediation path:** R2 slice — GoTrue email trigger on invite (provider
  config + a short review + a matrix note if the surface widens); until then,
  keep the in-app single display as the shipped posture.

---

### F-06 — Accept-invite one-time token rides in a deep-link URL

- **Gap:** `com.legalhub.app://accept-invite?token=<one-time-token>` puts a
  credential-adjacent value in a URL that OS logs / launcher dumps /
  other-app intent interception can observe. Mitigations in place: single-use,
  hashed at rest, in-memory `PendingAcceptInviteStore` (consumed-and-cleared),
  no auto-submit, generic denial.
- **Evidence:** `lib/app/deep_link/app_link_parser.dart` +
  `pending_accept_invite_store.dart`; threat model §4.1; Phase 4.1
  D-P34.2 records.
- **Severity:** Low (one-time token, short exposure window, in-memory only).
- **Owner:** Project Owner; engineering (when a server surface is approved).
- **Remediation path:** document the exposure in the accept-deeplink scope
  note; when the Android release is configured, verify **App Links
  (assetlinks.json)** so the scheme cannot be claimed by another app; the
  stronger fix (short-lived server-issued code instead of the token in the
  URL) needs an edge function + review and is a future slice.

---

### F-07 — No throttling beyond GoTrue defaults (D-07)

- **Gap:** rate limiting relies entirely on Supabase Auth's built-in
  defaults (sign-in, OTP, recovery); no custom layer. Provider posture is
  not client-verifiable.
- **Evidence:** `docs/p0_decision_capture.md` D-07; threat model §4.5 /
  §6 residual 7.
- **Severity:** Low (demo posture; provider defaults are reasonable for the
  scale).
- **Owner:** Project Owner.
- **Status (2026-08-09):** ACCEPTED as demo-posture — portfolio/demo
  project, no real client data; revisit if that scope ever changes. Not
  implemented (see `docs/p4_release_readiness_2026-08-09.md`).
- **Remediation path:** verify the dev project's Auth rate-limit settings
  (read-only probe / console) and record them in the P4 release notes;
  revisit custom throttling only if a real-data rollout is approved.

---

### F-08 — Denied RPC attempts are not logged as `denied` audit rows (deliberate)

- **Gap:** a denied `send_message` writes **no** audit row — pinned as the
  §8 negative (10.09). This keeps probe traffic out of the audit trail but
  means failed-attempt forensics are unavailable.
- **Evidence:** `supabase/tests/10_send_message_rls.sql` CHECK 10.09; threat
  model §4.3 / §6 residual 8.
- **Severity:** Info / Low — a deliberate design choice, not a defect.
- **Owner:** Project Owner (ops decision).
- **Remediation path:** if denied-attempt visibility is ever wanted, add
  opt-in `denied`-outcome writes for selected RPCs behind a small review
  (the schema already supports `outcome = 'denied'`); no change for the
  current portfolio scope.

---

### F-09 — Demo clients hold no membership rows — client-side positives not demoable live

- **Gap:** the three demo client accounts have **no membership rows**, so a
  configured build shows them 0-everything (the membership guard firing as
  designed). A live client-side positive demo is impossible without a data
  action.
- **Evidence:** `docs/current_applied_surface_2026-08-08.md` §5; E2E
  checklist §4; threat model §6 residual 5.
- **Severity:** Low — data posture, recorded as designed, never a defect.
- **Owner:** Project Owner (data action).
- **Remediation path:** if a fuller client demo is wanted, a deliberate,
  owner-approved data action adding membership rows for the three demo
  clients (recorded in `docs/current_applied_surface`), with the E2E
  checklist updated to expect the new positives. No code/policy change.

---

### F-10 — Provider/hosting posture assumed, not verified

- **Gap:** several controls rest on hosting assumptions that the repo records
  but has not fully probed: the rehearsal-host storage-policy baseline
  (harness WATCH-ITEM), the platform default SELECT grants on
  `storage.objects`, and the GoTrue JWT-`email`-claim precondition for
  `accept_invitation` (README refinement #8).
- **Evidence:** `scripts/verify_policy_tests.sh` §1g WATCH-ITEM;
  `supabase/rpc/accept_invitation.sql` precondition comment; threat model
  §4.5 / §6 residual 6.
- **Severity:** Low — verification gaps; the policy/battery pins compensate
  for the storage defaults.
- **Owner:** Project Owner; engineering.
- **Remediation path:** run the recorded read-only probes on the dev project
  (storage-policy baseline, `storage.objects` grants) and confirm the GoTrue
  JWT carries `email`; record results in the P4 release notes.

---

### F-11 — Self-scoped helpers exposed as PostgREST `/rpc/` endpoints

- **Gap:** the R-4 policy-eval grants make `is_active_member(uuid)` and
  `has_org_role(uuid, org_role)` client-callable. Safe today — both are
  `auth.uid()`-self-scoped (a caller learns only facts about **themselves**;
  harness notes this as intentional) — but the pattern is a standing risk if
  a future helper with a parameter reading **other** users' rows ever
  receives a policy-eval grant.
- **Evidence:** `supabase/migrations/02_rls_functions.sql` R-4 grants +
  note; harness §1c; threat model §4.6.
- **Severity:** Info today; would rise with any non-self-scoped helper.
- **Owner:** engineering (standing review criterion).
- **Remediation path:** no code change. Add "policy-eval helper grants stay
  `auth.uid()`-self-scoped only" to the standing RLS-gate review checklist
  (the repo's own gate-review convention) so every future slice re-checks it.

---

### F-12 — Dev demo data violates the F-01 never-assigned invariant (surfaced by the F-01 step 2 apply; contained) — **RESOLVED 2026-08-09**

- **Gap:** the dev project's `platform_config.owner_user_id` **is the
  account id historically seeded as the acquisition demo matter's
  "client"** (`9acfd3b4-…`), so the pre-existing demo matter
  `a6715e17-…` ("Demo matter — acquisition review", seeded 2026-08-07 by
  the matters apply) has the **platform owner id as `assigned_client_id`**
  — the exact Q4 residual state F-01 forbids, present in the dev demo data
  since before the F-01 work. Battery 12's never-assigned invariant is
  therefore **false against the dev demo data** (the battery itself is
  ephemeral-only and never ran here).
- **Evidence:** `docs/matter_write_apply_execution_2026-08-09.md` §5 —
  verified live: impersonating the owner returns **0 visible matters** —
  the `matters_select_assigned` `is_active_member` arm blocks it (the
  owner holds no memberships).
- **Severity:** Low today — **contained, no live disclosure** (verified by
  owner impersonation). Would rise to High if the owner ever gained a
  membership while assigned (the F-01 scenario the trigger now prevents for
  new writes).
- **Owner:** Project Owner (data change on the shared dev project).
- **Remediation path (owner-approved data slice):** re-assign
  `a6715e17-…`'s `assigned_client_id` from the owner id to the real
  demo-client account (`0c54d251-…`) to restore the invariant, and note the
  account-hygiene history (the owner account was seeded as a demo
  "client" pre-F-01). F-01 step 2's trigger + RPC now guarantee no **NEW**
  owner assignment through any path (live-proven).
- **Resolution (2026-08-09, owner-directed):** **APPLIED + VERIFIED** on
  the dev project — `a6715e17-15a6-4456-96e3-78fc56630cfe`'s
  `assigned_client_id` moved off the owner id onto the demo-client account
  (`0c54d251-1cdd-4be6-9ce5-623a5987045f`) with a machine audit row
  (`matter:assignee_remediation`, Q6 NULL actor); **the owner id now
  appears in NO matter assignment column (0/5)** — the F-01 invariant
  holds in the dev demo data. Evidence:
  `docs/f12_data_remediation_2026-08-09.md`. The demo client still holds
  no membership rows (reads 0 — the F-09 posture, unchanged).

---

## 3. What this register does NOT do

- It does **not** close the P4 gate — items 3 (controlled-rollout rehearsal)
  and 4 (dated release approval) remain owner-gated and untouched
  (`docs/security_review_gate_record_2026-08-09.md` §2).
- It is **not** a compliance assessment (D-03) and **not** a claim of
  production readiness — it records residual gaps and their remediation paths
  for the P0-closure security review.
- **No code, policy, migration, or battery was changed** to produce this
  register; every remediation above still needs its own approved slice.

## 3a. Change record (F-01 step 1, 2026-08-09)

| File | Change |
|---|---|
| `supabase/tests/12_owner_assignment.sql` | **NEW** — the F-01 owner-assignment invariant pin (10 check blocks: 12.01/12.02 non-vacuity preconditions; 12.03–12.05 matters assignment columns; 12.06–12.10 content-table uuid sweeps; owner derived from `platform_config`) |
| `scripts/verify_policy_tests.sh` | Wired 12 into `BATTERY_FILES`, the static UUID scan, the FAIL-marker loop, `run_battery`, and the selftest UUID glob (`10_*.sql` → `1[0-9]_*.sql`); header comment row added |
| `supabase/README.md` | Battery-table row for 12 added; the stale 09–11 rows back-filled |
| `docs/owner_assignment_battery_rehearsal_r1_2026-08-09.md` | r1 rehearsal evidence — genuinely executed 2026-08-09 (79/0/0 ×2, `--apply` 42/42, teardown recorded) |
| `docs/f01_step2_matter_write_design_2026-08-09.md` | F-01 step 2 design — matter-creation slice: `create_matter` owner refusal + categorical trigger + battery 13 + gate sequence (approved for build 2026-08-09) |
| `supabase/rpc/create_matter.sql` | F-01 step 2 — the matter-creation RPC (REHEARSAL-READY): F2-D1 partner gate, F2-D2 owner refusal (derived from `platform_config`), F2-D4 active-member assignee guard, §8 audit; `rpc/_down.sql` drop added |
| `supabase/migrations/11_matter_write.sql` (+ `.down`) | F-01 step 2 — the categorical F2-D3 trigger (`refuse_platform_owner_assignment`, `BEFORE INSERT OR UPDATE` on `matters`), EXECUTE-revoked, with rollback pairing |
| `supabase/tests/13_matter_write_rls.sql` + harness wiring | F-01 step 2 — 16 check blocks (RPC pos/neg, trigger INSERT + UPDATE arms + narrowness, §8 audit pos/neg, F2-D5 orphan, cross-org/anon/validation denials); 13 wired into the harness file list/loops + 11 into the apply order + §1c/§1d pins |
| `docs/matter_write_slice_rehearsal_r1_2026-08-09.md` | F-01 step 2 r1 evidence — genuinely executed 2026-08-09 (`--apply` 44/44, full battery 82/0/0 ×2, battery 13 all 16 checks green, teardown recorded) |
| `docs/matter_write_slice_review_2026-08-09.md` | F-01 step 2 mechanism/RLS-gate review — PASS 2026-08-09; findings R-1 (UPDATE arm) + R-2 (F2-D5) remediated in-review (13.14/13.15/13.16), re-run 82/0/0 ×2 |
| `docs/matter_write_apply_approval_2026-08-09.md` | F-01 step 2 **dated apply-approval record — APPLY APPROVED + EXECUTED 2026-08-09** (§6 dated sign-off recorded in-session; §3 scope: create_matter + 11_matter_write + live demo smoke; §4 guardrails; §5 exclusions) |
| `docs/matter_write_apply_execution_2026-08-09.md` | F-01 step 2 **apply execution evidence — APPLIED + VERIFIED 2026-08-09** on the dev project: baseline probe → create_matter → 11_matter_write → demo create `d28f1f05-…` (§8 audit row observed) → negatives + smoke green → **finding F-12 recorded** (pre-existing owner-assigned demo matter, contained, owner-side remediation) |
| `docs/permission_matrix.md` §4 addendum + `docs/current_applied_surface_2026-08-08.md` addendum | **Dated addenda 2026-08-09** — the "Create a matter" row (partner gate, owner refusal, member guard, orphan creates, UPDATE re-assignment denial) + the applied-surface deltas (RPC-EXECUTE 19→20, trigger live, matters 4→5, F-12 noted) |
| `docs/f12_data_remediation_2026-08-09.md` | **F-12 RESOLVED 2026-08-09** — owner-directed data remediation on the dev project (acquisition matter re-assigned off the owner id onto the demo client + machine audit row; invariant restored: owner id in 0 assignment columns) |
| `docs/matter_write_client_slice_design_2026-08-09.md` | **F-01 client swap DESIGN 2026-08-09 (Gate 3)** — env-gated `MatterWriteGateway` seam + fake + Supabase impl (D-SM2 RPC pattern), `/matters/new` create flow, typed server-refusal mapping, created-matter audit surfacing via `read_org_audit`; open questions Q1–Q5 |
| Client swap build (2026-08-09) | **F-01 client swap BUILT — analyze + suite green (1151 declared / 1154 executed)** — `lib/features/matters/domain/matter_write_gateway.dart` (seam + VOs) · `lib/features/matters/data/fake_matter_write_gateway.dart` (F2-D2/F2-D4/validation mirrors) · `lib/data/matters/supabase_matter_write_api{,_impl,gateway}.dart` (the `create_matter` RPC caller, C-D2 kind mapping) · `matter_create_{state,cubit,screen}.dart` (the `/matters/new` flow) · `/matters/new` route + partner-gated list FAB · `service_locator.dart` env flip + factory seam · EN/AR/TR keys · tests (fake contract, RPC-param exactness, cubit, screen, FAB gate, DI flip) · README 1151. Q3/Q5 resolved in-build: success = in-screen confirmation (details navigation deferred — a fresh create is unreadable under RLS in the orphan case, and the read fake doesn't know creates until Q4); Q4 (fake-read handoff) stays open |
| Client swap mechanism review (2026-08-09) | **REVIEW PASS — `docs/matter_write_client_slice_review_2026-08-09.md`** — seam contract / fake mirrors / RPC-param exactness / DI flip / error copy all SOUND; **R-1 (High, production path): the `/matters/new` route had NO cubit provider — a real navigation crashed with `ProviderNotFoundException` (the widget test had masked it); fixed by self-providing the cubit (the `MatterListScreen` pattern), with a real-router pin. R-2 (Low): no-active-org submit was a silent no-op; fixed with a hub-style session seed + a visible `matterCreateNoOrg` state (EN/AR/TR).** Re-verified: analyze clean, full suite 1156, ledger PASS (README 1153). Boundary: client-only; the D-45.1 configured-build verification (live RPC + §8 row in the org-audit view) remains the next gate |

Verification: `bash scripts/verify_policy_tests.sh --check` → PASS (see §4);
`--selftest` re-run green on the committed baseline.

## 3b. Harness UUID-scan correction (2026-08-09)

The F-01 step 2 build surfaced a **latent bug in the static `--check` UUID
cross-ref scan** (`scripts/verify_policy_tests.sh`): the grep file list lost
its line-continuation backslashes when batteries 07+ were added (present
since the storage slice, `47150be`, 2026-08-08), so the scan (a) covered only
files 01–06 and (b) ran without the trailing `| sort -u` — the dedup landed
on a bogus second command that never read the battery files. Every static
count from the storage slice onward (331 → 343) decomposes exactly as
per-file presence/FAIL-marker pins + **313 raw, undeduplicated UUID
occurrences from files 01–06**, so **files 07–13 were never cross-ref
scanned**: the dangling-UUID gate was inert for the storage / realtime /
messages / invoices / F-01 batteries, and the recorded 331–343 counts are
not comparable to the corrected figure.

**Fix (this build):** restored the four continuation backslashes; the scan
now covers all 13 battery files, deduplicated. The fixed scan immediately
caught two pre-existing dangling refs (`fff2…`/`fff3…` in
`09_realtime_push.sql`, abbreviated in the fixtures comment) — repaired as
documentation-only in `00_fixtures.sql` (the ids are genuine throwaway ids
used in 09's SQL; no fixture row was affected).

**Corrected gate:** `--check` → **73/0/0 PASS** on the working tree (14
presence + 43 deduplicated fixture UUIDs + 13 FAIL-marker + 3
syntax/doc-hook pins). Live battery numbers (79/0/0, 78/0/0, 74/0/0, 72/0/0,
70/0/0…) are unaffected — they come from executed psql runs, not the static
scan. Nuance on the selftest: it kept passing 6/6 during the buggy window
because its drift-2 fixture pick always landed in the scanned 01–06 set; it
could not have detected a dangling ref cited only by files 07+.

## 4. Evidence index

- Threat model (the source this register reviews): `docs/p4_threat_model_2026-08-09.md`.
- Gate status + P4 items: `docs/security_review_gate_record_2026-08-09.md`.
- Applied surface (single source of truth): `docs/current_applied_surface_2026-08-08.md`.
- Matrix (signed, dated addenda): `docs/permission_matrix.md` (§4/§5/§6).
- Decisions: `docs/p0_decision_capture.md` (D-07 MFA; D-11 payments; D-02/D-03
  demo posture) · `docs/features_roadmap_2026-08-03.md` (R2 invites; §14).
- Batteries + harness: `supabase/tests/*.sql` (73/0/0 static on 2026-08-09,
  corrected — §3b) · `scripts/verify_policy_tests.sh` (§1c/§1d/§1e/§1f/§1g pins).
- Recorded follow-ups this register tracks: D-STR9 (download), D-LV4
  (reconnect/backfill), R2 (invite emails), D-45.1 (configured-build E2E).
