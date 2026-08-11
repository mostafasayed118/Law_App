# LegalHub — P2 Reviewed Migration Slice (Supabase)

> **Record type:** The reviewed, gate-approved P2 migration set for the
> non-production Supabase dev project, re-authored from the approved design
> (`docs/p2_schema_rls_design.md`, APPROVED 2026-08-01, §8 Q1–Q6 answered) and
> governed by `docs/auth_tenant_authorization_contract.md` §7/§9/§11-P2 ·
> `docs/permission_matrix.md` · `docs/rollback_plan.md` §1/§2 ·
> `docs/gate3_decision.md` §5 · `docs/adr/0007`.
>
> **Status: REVIEWED & APPLIED (dev project, 2026-08-01).** The slice was
> applied to the shared dev project (`eutmvevpskerzpqmwplv`) under the
> apply-approval record's §4 conditions: Up 1–5 applied and verified GREEN —
> evidence in `docs/p2_apply_execution_2026-08-01.md` (`3bcd968`). The §4.5
> post-apply **manual smoke** (signup loop with a real inbox) is **deferred**
> — P2 closed 2026-08-03 on the probe battery + rehearsals; the provider loop
> was not executed (see `docs/p2_close_decision_2026-08-03.md`). Applying it was a
> **separate approval slice** requiring (1) the
> ephemeral rehearsal from `docs/rollback_plan.md` §2 and
> `docs/p2_schema_rls_design.md` §7, and (2) explicit owner authorization per
> `INSTRUCTIONS.md` §2.1 gates — both recorded (rehearsal r4 PASSED,
> `docs/p2_rehearsal_evidence_r4_2026-08-01.md`; approval
> `docs/p2_apply_approval_2026-08-01.md`).
>
> **Date:** 2026-08-01. **Owner:** Project Owner (github.com/mostafasayed118).

---

## Directory layout

| Path | Content | Paired backout |
|---|---|---|
| `migrations/01_org_schema.sql` | Enums, 6 tables, RLS enable, default-deny revokes + narrow grants | `migrations/01_org_schema.down.sql` |
| `migrations/02_rls_functions.sql` | Helper functions + signup trigger + expiry cleanup (security definer) | `migrations/02_rls_functions.down.sql` |
| `migrations/03_platform_config_seed.sql` | Q1 owner-uid seed (substitution token, applied only with verified id) | `migrations/03_platform_config_seed.down.sql` |
| `policies/*.sql` | Per-table RLS policies (versioned in git, never edited in dashboard) | `git revert` of the policy commit (design §7) |
| `rpc/*.sql` | Narrow RPC surface (security definer, each audited) | `rpc/_down.sql` (drops the whole surface) |

## Apply order (as executed on the dev project, 2026-08-01)

```
1. migrations/01_org_schema.sql
2. migrations/02_rls_functions.sql
3. migrations/03_platform_config_seed.sql   ← fill OWNER_USER_ID token from verified id first
4. policies/*.sql                           (order irrelevant; all reference 01/02 objects)
5. rpc/*.sql                                (all reference 01/02 objects)
```

Each step verified with `supabase db diff` before/after per `rollback_plan.md` §1.

## Design fidelity & refinements (flagged for the reviewer, not silently encoded)

1. **Q5 "only raw policy is own-profile SELECT/UPDATE"** is read as a
   **mutation-surface** rule (design §5.3 is the complete INSERT/UPDATE/DELETE
   surface). Direct SELECTs follow design §5.2 and matrix §3 (org member list,
   org select, own profile, partner invitations) — encoded as the narrow
   SELECT grants + policies below. No raw INSERT/UPDATE/DELETE grant exists.
2. **Audit reads are RPC-only** (`read_org_audit`, `read_platform_audit`),
   not a raw SELECT policy — this is the only way the matrix §6 requirement
   ("`platform_owner_admin` reading audit is itself an audited action") and
   contract §8's scope-checked-reader rule are both satisfiable. The two
   read RPCs are additions to the design §5.3 list, justified by §5.2/§6.
   Also **`reactivate_membership_platform` was added** to complete matrix §3's
   signed owner row ("Suspend / reactivate a membership | ✅ (any org)")
   which design §5.3's list omitted — flagged so the owner can veto before
   apply; the policy-test suite otherwise could not exercise that positive row.
3. **`accept_invitation` uses a generic "invalid invitation" error** for
   every failure mode (not-found, expired, revoked, email mismatch) so no
   enumeration signal leaks (matrix §2 negative).
4. **`delete_my_account` writes the audit row before deleting the identity**
   — the FK is `on delete set null`, so the redacted summary survives with the
   actor reference cleared (D-05 + contract §8).
5. **`invitations.accepted_by`/`accepted_at` stay nullable** and are bound
   only by the security-definer `accept_invitation` RPC, never by the client.
6. **pgcrypto** is required (sha-256 `digest`). The 2026-08-01 ephemeral
   rehearsal confirmed pgcrypto lives in the `extensions` schema on this
   hosting, so the unqualified `gen_random_bytes`/`digest` calls failed under
   the pinned `search_path = public`. **Amended (R-1):** the three token RPCs
   (`invite_member`, `resend_invitation`, `accept_invitation`) now qualify
   `extensions.*` explicitly. Verified in the rehearsal's ephemeral fix; the
   amended slice must be re-rehearsed before apply.
7. **`remove_membership` refuses self-removal** (`auth.uid() = p_user_id` →
   error) — self-deletion belongs to `delete_my_account` (D-05). This is a
   hardening beyond matrix §3's unqualified "Remove a member | ✅ (own org)"
   row; flagged for the owner's awareness, not a silent widening.
8. **`accept_invitation` matches the invited email against the JWT `email`
   claim** (`auth.jwt() ->> 'email'`) — a provider session without that claim
   would make acceptance impossible (generic denial). Known precondition for
   the anon-key GoTrue setup, not a silent failure.

## Rollback pairing (design §7 / rollback_plan §1–§2)

| Forward artifact | Backout | Verification after rollback |
|---|---|---|
| `01_org_schema.sql` | `.down.sql` | `supabase db diff` → schema equality with pre-P2 baseline |
| `02_rls_functions.sql` | `.down.sql` | Function inventory equal; pre-P2 policy expectations still pass |
| `policies/*.sql` | `git revert` of the policy commit | Matrix negative rows still deny; positive rows allow only where pre-approved |
| `rpc/*.sql` | `_down.sql` | RPC grant list returns to the prior set |
| `03_platform_config_seed.sql` | `.down.sql` | `is_platform_owner()` false for everyone |

**Rehearsal requirement:** the full up → down → verify sequence runs in an
ephemeral Supabase project (or `db reset` against the dev project with a
confirmed-empty baseline) before anything is applied to the shared dev
project (contract §11-P2 exit, rollback_plan §2). Any matrix negative row
starting to pass = immediate revert, never fix-forward (rollback_plan §5).

## Policy-test battery (P0-closure slice P0C.1, D-P0C2)

The committed battery under `tests/` + `scripts/verify_policy_tests.sh`
provides the durable, re-runnable positive/negative policy tests that the
permission matrix (contract §9) and the P0-closure scope note
(`docs/p0_closure_scope_2026-08-05.md`, RATIFIED 2026-08-05) require —
the P2 r1–r5 rehearsals proved specific migrations on ephemeral projects;
this battery hardens that pattern into a committed artifact.

| Path | Proves |
|---|---|
| `tests/00_fixtures.sql` | Deterministic, idempotent seed: owner + 6 synthetic users (fixed UUIDs), org-a/org-b, 5 memberships (incl. a suspended partner and an orphan-profile member), 1 pending invite, the `platform_config` owner row |
| `tests/01_identity_session.sql` | Matrix §2 rows: own-profile SELECT/UPDATE positive + negative, D-T6 pair (partner raw profile read → 0 rows), `list_org_members_metadata` positive (roster + pending invites, no token material) + non-partner/cross-org/suspended/owner negatives, orphan-membership fallback pair, anon denials |
| `tests/02_organization_membership.sql` | Matrix §3 rows: roster positives + cross-org/suspended negatives, invite/resend/revoke/change-role/suspend/reactivate/remove positives (in-transaction, rolled back) + non-partner/cross-org negatives, the 2026-08-03 hardening guards (last-partner lockout, existing-member invite refusal, self-removal refusal), `create_organization`, and the owner-denied-on-partner-RPC rows |
| `tests/03_platform_owner_boundary.sql` | Matrix §5 + D-P0C1(a) deny-rows (owner's direct surface = own profile only; audit/platform_config/helpers all denied; no partner/org RPC accepts the owner) + D-P0C3 single-account bound (privileged PK collision + client grant absence) + D-P0C4 audit RPC-only (self-audited reads, append-only, RPC-only grant absence) |
| `tests/04_matter_rls.sql` | Matrix §4 matter rows — the first §14 un-deferral (assigned client/attorney positives + org-role-alone / cross-org / suspended / owner / anon denies + the practice_area CHECK + org-delete cascade) |
| `tests/05_document_rls.sql` | Matrix §4 document rows — the second §14 un-deferral (matter-scoped assignment positives + org-role-alone / org-mismatch / cross-org / suspended / owner / anon denies + the document_type CHECK + matter-delete cascade) |
| `tests/06_message_rls.sql` | Matrix §4 message rows — the third §14 un-deferral (matter-scoped assignment positives + org-role-alone / org-mismatch / cross-org / suspended / owner / anon denies + the message_count CHECK + matter-delete cascade) |
| `tests/07_storage_rls.sql` | Matrix §4/§6 file rows — the fourth §14 un-deferral (BOTH-layer positives on `public.files` + `storage.objects` + org-role-alone / org-mismatch / cross-org / suspended / owner / anon denies + the guessed-path object row (matrix §6) + the size_bytes CHECK + matter-delete cascade) |
| `tests/08_message_rls.sql` | Matrix §4 body rows — the sixth §14 un-deferral (thread-scoped individual-message positives + org-role-alone / org-mismatch / cross-org / suspended / owner / anon denies + the body CHECK + thread-delete cascade + the message-count mapping-consistency pin) |
| `tests/09_realtime_push.sql` | Matrix §6 delivery + the D-SM3 revocation — the seventh §14 un-deferral (publication-membership pins (messages in `supabase_realtime`, count 1, nothing else) + the empty-body CHECK + the delivery-equivalence reads (assigned reader sees the row; suspended / cross-org / owner / stranger see 0) + the direct-INSERT privilege-layer deny + the `messages_insert_assigned` policy-gone pin) |
| `tests/10_send_message_rls.sql` | The audited write path — the send-message slice (assigned attorney/client positives, the `message:create` §8 audit-row positive (redacted summary, resource id), the in-function D-SM1 gate deny rows (org-role-alone / cross-org / suspended / owner / anon), the empty-body CHECK through the RPC, and the §8 negative — a denied send writes no audit row) |
| `tests/11_invoice_rls.sql` | Matrix §4 invoice rows — the ninth §14 un-deferral (matter-scoped assignment positives + org-role-alone / org-mismatch / cross-org / suspended / owner / anon denies + the `amount_cents` + `status` CHECKs (D-11 metadata-only mapping contract) + matter-delete cascade) |
| `tests/12_owner_assignment.sql` | **F-01 owner-assignment invariant pin** (`docs/p4_findings_register_2026-08-09.md` F-01 step 1, 2026-08-09): the platform-owner id (derived from `platform_config`) never appears in any matter assignment column (`matters.assigned_client_id`/`assigned_attorney_id`) or content-table uuid column, with non-vacuity preconditions (owner row present; assignment set non-empty) — pins the Q4 residual so the never-assigned invariant can no longer be broken silently |
| `tests/13_matter_write_rls.sql` | **F-01 step 2 matter-write battery** (`docs/f01_step2_matter_write_design_2026-08-09.md`, 2026-08-09): `create_matter` positives/negatives — the partner gate (F2-D1), the platform-owner assignment refusal (F2-D2), the active-member assignee guard (F2-D4), the §8 audit positive/negative (redacted summary; denied creates write nothing), the **trigger-layer** refusal + narrowness (F2-D3 — direct INSERT with the owner id is refused even for the connection role; non-owner inserts still work), cross-org and validation denials |
| `tests/14_notification_rls.sql` | **Notification-feed read battery** (`docs/notification_feed_gate_review_2026-08-11.md` Q2/Q3/Q6, D-N1..D-N7): `notifications_select_org` positives (partner-a 4 / client-a 4 — the no-role-hierarchy pin / partner-b 1 — org scoping by count) + cross-org / `platform_owner_admin` deny-always / suspended / anon denies + the `category` CHECK (D-N4 mapping contract) + org-delete cascade + the structural column-inventory pin (Q1 — no user-identity/content/raw-text columns) |

### Running the battery

The battery runs against an **ephemeral rehearsal project only** — never the
live dev project (`DO-NOT-TOUCH`). The harness **hard-refuses** any URL whose
host contains the known dev-project ref (`eutmvevpskerzpqmwplv`);
`ALLOW_DEV_PROJECT=1` is the explicit owner override. Requires the PostgreSQL
client (`psql`)
and the project's postgres connection string (the fixtures seed
`auth.users` + `platform_config`, which no client role may do).

```bash
# 1. Create the throwaway project (supabase CLI or dashboard), then:
SUPABASE_TEST_DB_URL=postgresql://postgres:***@host:5432/postgres scripts/verify_policy_tests.sh --apply   # build from the committed files
SUPABASE_TEST_DB_URL=postgresql://postgres:***@host:5432/postgres scripts/verify_policy_tests.sh           # run the full battery
scripts/verify_policy_tests.sh --check        # static validation, no database
```

- `--apply` applies `migrations/01`, `02`, `04_matters.sql`,
  `05_documents.sql`, `06_message_threads.sql`, `07_storage.sql`,
  `08_messages.sql` (the five §14 un-deferral slices — `07_storage.sql`
  requires the platform storage schema, present on the rehearsal host),
  `policies/*.sql`, `rpc/*.sql` in the apply order above.
  **`03_platform_config_seed.sql` is NOT applied**: its owner token is an
  apply-time substitution placeholder for the dev project; the battery seeds
  its own fixture owner row and proves the single-account bound (D-P0C3)
  instead.
- The battery exercises every matrix §2/§3/§5 row with ≥1 positive + ≥1
  negative check (contract §9), plus the D-P0C1(a) deny-rows and the
  D-P0C4 audit pins.
- **Out of battery scope (recorded, not skipped):** provider-level flows
  (signup/sign-in/reset, GoTrue email triggers) stay out of SQL rehearsal
  scope per the P2 r5 methodology — they have their **own ephemeral
  rehearsal harness**: `scripts/verify_provider_loop.sh` (D-45.1 Phase 1,
  `docs/p2_provider_loop_phase1_rehearsal_2026-08-08.md`), the mail-catcher
  loop that proves the GoTrue round trip on a throwaway stack before the
  Phase 2 dev-project smoke; realtime buckets remain Q4 deferrals
  (the storage Q4 deferral is consummated — the fourth §14 un-deferral).
  The D-P0C1(b) content-table forward pin is asserted structurally
  (matters, documents, message_threads + files exist as the first four §14
  un-deferrals; individual message rows/bodies still absent) and enforced
  at schema-review time per the matrix §5 addendum.
- Record the run as rehearsal evidence (the P0C.3 close decision consumes
  it), then delete the throwaway project.

## Provider-loop rehearsal (D-45.1 Phase 1, 2026-08-08)

The GoTrue provider loop (signup → email-confirm → sign-in → reset) is
rehearsed on a **throwaway stack** with `scripts/verify_provider_loop.sh`
(spec: `docs/p2_provider_loop_phase1_rehearsal_2026-08-08.md`) — the
committed `migrations/` + `policies/` + `rpc/` files build the ephemeral
project (`--apply`), and the local mail catcher (Inbucket, `127.0.0.1:54324`)
receives the confirmation/recovery emails (zero real email, zero dev-project
contact). Five legs: L1 existing-account sign-in · L2 sign-up → D-07 pending
(no session) · L3 email-confirm → session + `email_confirmed_at` · L4
confirmed sign-in + trigger-created profile · L5 password-reset round trip.
`--check`/`--selftest` are static and run anywhere; the live loop needs a
Docker/CI host (`supabase start`). Phase 2 (the dev-project smoke) stays
gated on this rehearsal passing + the owner's dated apply-approval
(`docs/p2_provider_loop_phase2_smoke_2026-08-08.md`).

## What this directory does NOT authorize

- No Supabase change beyond the reviewed + applied slice (Up 1–5, executed
  2026-08-01 on the dev project; P2 closed 2026-08-03, §4.5 provider loop
  deferred — `docs/p2_close_decision_2026-08-03.md`).
- No matter/doc schema, no storage/realtime policy (Q4 deferral), no real
  data, no service-role usage, no compliance claim.
- The Flutter code (`lib/`) is untouched by this slice.
