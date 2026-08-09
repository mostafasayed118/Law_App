# LegalHub — P4 Threat-Model Write-Up (STRIDE, consolidated surface) — 2026-08-09

> **Record type:** The consolidated cross-surface threat write-up called for by
> **P4 §2 item 1** (`docs/security_review_gate_record_2026-08-09.md`) — a
> STRIDE-style pass over the **applied Supabase surface** (12 tables / 12 RLS /
> 11 public + 1 storage policy / 19 EXECUTE RPCs / Realtime publication
> exactly `messages` / private `matter-files` bucket) and the **auth/org
> seams**, grounded in the signed permission matrix
> (`docs/permission_matrix.md`), the policy batteries
> (`supabase/tests/*.sql` + `scripts/verify_policy_tests.sh`), and the
> recorded gate reviews (RLS-gate + mechanism reviews per §14 slice).
>
> **Status: REVIEWABLE INPUT — NOT a completed security assessment.** This
> write-up does **not** close the P4 gate. Per `docs/security_review_gate_record_2026-08-09.md`
> §2, the gate stays OPEN until the owner performs the **controlled-rollout
> rehearsal** (item 3) and grants a **dated release approval** (item 4). This
> document supplies the reviewable artifact for item 1 only; item 2
> (dependency/config review) was already recorded in the gate record §4.1.
>
> **Owner:** Project Owner (github.com/mostafasayed118). **Date:** 2026-08-09.
> **Baseline:** `origin/main` @ `b7325f8` (v1-queue slice; suite 1127, ledger
> PASS 115/115).
>
> **Method:** each threat row names a surface, the current control, and the
> repo evidence (policy file / RPC file / battery check block / harness pin)
> that exercises it — positive **and** negative per matrix §9. Claims below
> were re-verified against the committed files on 2026-08-09; the static
> battery `scripts/verify_policy_tests.sh --check` was re-run and passes
> **73/0/0** (see §8; the static UUID-scan count was corrected on 2026-08-09
> — §8 note). Nothing here asserts a property that was not verified
> at the SQL/policy layer or explicitly recorded as a residual.

---

## 1. Scope and method

**In scope:** identity/session seam (GoTrue behind `SupabaseAuthApi`, anon-key
guard, `Session` shape), the 12 public tables + their RLS policies, the 19
client-EXECUTE RPCs (including the security-definer helpers), Realtime
publication + delivery, and the storage bucket/objects surface. Client-side
controls (router guards, capability map, DI env flip) are treated as **UX
hints only** — the matrix's "server-side enforcement" contract — and are
analyzed only where they could mislead (false assurance), never as
authorization.

**Out of scope (this write-up):** provider-side controls (Supabase infra,
GoTrue rate limits, host network), physical/logical access to the dev
project's postgres role, dependency-supply-chain review (recorded in the P4
gate record §4.1), and any jurisdiction-specific compliance rule (D-03). The
**AI** path stays deferred (D-07/D-08 + undefined scope) and has no surface to
threat-model yet.

**Test method the batteries use (for the reader):** every battery file
impersonates roles via `set_config('request.jwt.claim.sub' / 'claims')` under
`set role authenticated`, so each check exercises the exact RLS/RPC
authorization the JWT path would, with `POLICY-BATTERY FAIL` markers asserted
by the harness (`--check` static + the live r-series on the ephemeral
rehearsal project). Matrix rows are covered ≥1 positive + ≥1 negative
(contract §9).

---

## 2. Assets and trust boundaries

| Asset | Classification | Boundary / source of truth |
|---|---|---|
| `auth.users` + GoTrue session | credentials / identity | provider-owned; the app refers to `auth.uid()` only |
| `profiles` (display_name, locale) | personal data | own-row-only RLS; created by signup trigger |
| `organizations` | tenant boundary | active-member SELECT only; creation RPC-owned (D-08) |
| `memberships` (role, status) | access-control data | org-roster SELECT; mutations RPC-only + audited |
| `invitations` (email, token_hash, expiry) | credential-adjacent | partner SELECT only; token stored **hashed** (Q2); token returned once |
| `platform_config` (owner_user_id) | capability source of truth | **no client grant, no policy** — read by `is_platform_owner()` in definer bodies only |
| `audit_events` | audit data | **no client grant, no policy** (D-P0C4); append-only via `write_audit`; RPC-only reads |
| `matters` / `documents` / `message_threads` / `messages` | sensitive matter content | matter-scoped assignment gates (matrix §4); `messages.body` is the only content column |
| `files` + `storage.objects` | matter content (bytes) | two-layer gate; path-encoded `{org}/{matter}/{filename}` |
| `billing_invoices` | financial metadata | matter-scoped assignment gate; **no card/payment columns** (D-BI1) |
| Realtime publication | delivery channel | enablement ≠ authorization; table SELECT RLS is the delivery gate |

**Trust boundaries:** (1) unauthenticated/anonymous — default deny, no grants
on any table or RPC (harness pins assert anon SELECT/EXECUTE absent); (2)
`authenticated` — RLS + in-RPC gates only, never client-supplied authority
fields (D-08: server re-derives membership; D-06/D-09: server owns roles);
(3) `service_role` / `postgres` (trusted backend) — not reachable from the
client build (service-role key refused at configure time by
`SupabaseEnv.ensureAnonKey`); (4) the single `platform_owner_admin` account —
bounded capability, server-gated, audited, never audit-exempt.

---

## 3. Assumptions and explicit non-goals

- **Assumption:** GoTrue (Supabase Auth) correctly validates JWTs, issues
  short-lived access + refresh tokens, and enforces email verification
  (D-07). No custom session/TTL code exists client-side.
- **Assumption:** the dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`)
  is the only non-production surface; the battery never runs against it
  (harness DO-NOT-TOUCH guard).
- **Non-goal:** MFA, SSO/SCIM, passwordless (deferred to v1, D-07).
- **Non-goal:** real invite emails (R2 — out-of-band token delivery is the
  shipped posture; the token travels to the inviter once, in-app).
- **Non-goal:** payment capture (D-11 — Paymob decided, no live payment in
  MVP; `billing_invoices` is metadata-only by construction).
- **Non-goal:** instant revocation of an already-issued storage signed URL
  (D-STR4 — TTL-bound; minting is RLS-gated, mid-flight revocation is not).

---

## 4. STRIDE analysis

### 4.1 Spoofing (impersonation / identity forgery)

| Threat | Surface | Current control (evidence) | Residual / gap |
|---|---|---|---|
| Attacker authenticates as another user | GoTrue sign-in/sign-up | Email+password with verification required (D-07); typed `SupabaseAuthResult` seam never leaks GoTrue exceptions; env-less runs/tests use the credential-free fake — never a false assurance | — |
| Session forgery / stale session projects an old role | `Session` + membership hydration | `Session` carries **no client-owned role** (contract §5; D-T4 resolved); role is a UX-only projection from the active membership; server re-derives `status = 'active'` via `active_membership()` on every check; expired session resolves to `reauthRequired` | A cached client capability map can show stale UX until the next refresh — navigation hint only, never authorization |
| Invite-token forgery / reuse | `accept_invitation` | Token stored as **sha-256 hash only** (`invitations.token_hash`, Q2); single-use status guard + expiry re-check + JWT-email-claim match (D-10a); every failure mode raises the same generic `invalid invitation` (no enumeration) | GoTrue JWT must carry the `email` claim (documented precondition, README refinement #8) — without it acceptance always denies |
| Owner-capability spoof | `is_platform_owner()` | `platform_config` has **no client grant and no policy** (01 revokes; harness pins `authenticated` SELECT absent); the function is EXECUTE-revoked from client roles (02); capability is bound to exactly one row (`id` PK check, D-P0C3 — battery 03.D-P0C3a + 03.17) | A compromised `service_role`/postgres key would bypass — outside client threat model (build-time anon-key guard) |
| Service-role key in a client build | build config | `SupabaseEnv.ensureAnonKey` refuses any JWT whose `role` claim is not `anon` at configure time (Batch 3.3); `.env` is git-ignored; `.env.example` names-only | Owner discipline (never paste a service-role key into `.env`) |

### 4.2 Tampering (unauthorized modification)

| Threat | Surface | Current control (evidence) | Residual / gap |
|---|---|---|---|
| Client mutates membership role/status directly | `memberships` | **No INSERT/UPDATE/DELETE grant or policy** (01 revokes; mutations are RPC-only); role/status transitions go through `change_member_role` / `suspend_membership` / `reactivate_membership` / `remove_membership`, each partner-gated (`has_org_role(org,'partner')`) with last-partner guards and audit | — |
| Client forges an audit row or edits history | `audit_events` | **No grant at all** (D-P0C4); append-only by construction; `write_audit` is EXECUTE-revoked from `public`/`anon`/`authenticated` (02) — battery 03.13 (forge denied), 03.22/03.23 (UPDATE/INSERT denied) | — |
| Unauthorized message write | `messages` | Direct INSERT grant **revoked** (D-SM3: `messages_insert_assigned` dropped, INSERT revoked) — the **only** write path is the audited `send_message` RPC with the in-function D-SM1 gate; battery 09.15/09.16 (privilege-layer deny + policy gone) + 10.01–10.09 | — |
| RPC parameter tampering (org/role/user ids) | all mutation RPCs | Every RPC re-derives authorization **inside** the function from `auth.uid()` + membership (D-08; client-supplied ids are routing hints at most); cross-org swaps denied (battery 02/03 negative rows; send_message thread→matter three-way org equality) | — |
| Schema-level integrity bypass | CHECK constraints | `practice_area` / `document_type` / `message_count` / `size_bytes` / non-empty `body` / `amount_cents` + `status` CHECKs pinned by batteries (04.10, 05.10, 06.10, 07.10, 08.10, 10.10, 11.10–11.12) | — |

### 4.3 Repudiation (attribution / auditability)

| Threat | Surface | Current control (evidence) | Residual / gap |
|---|---|---|---|
| A sensitive action happens without an attributable record | every RPC + signup trigger | **All 19 client-EXECUTE RPCs write `write_audit` rows** (actor, action, outcome, org, resource, correlation id, **redacted** summary) — mutations with the actor, and the reads self-audit (`list_*` owner/partner reads + both audit reads); system events use the null-actor `system:` convention (Q6); `delete_demo_account` refuses self and audits before delete (D-05) | The demo-seed INSERTs are not audited (they use trusted backend seeds, not client paths) |
| Audit read itself is unobservable / a raw SELECT leaks | `audit_events` reads | Reads are **RPC-only** (`read_org_audit` partner-gated, `read_platform_audit` owner-gated) and **self-audit** — batteries 03.18/03.19 pin `audit:read_org` / `platform:read_audit` rows with the reader actor; owner is not audit-exempt (03.05) | — |
| Owner escapes audit | `platform_owner_admin` actions | Every owner action audited with the owner actor (03.04/03.05); no client path can write or delete audit rows (03.13/03.22/03.23) | — |
| Denied actions leave no trace | denied RPC attempts | Denials raise typed `permission denied`; a denied `send_message` writes **no** audit row (10.09 — pinned as the §8 negative, deliberate: no noise from probe traffic) | Deciding whether denied attempts should log a separate `denied` outcome is a product/ops choice, not required by §8 |

### 4.4 Information disclosure (tenant / matter isolation)

| Threat | Surface | Current control (evidence) | Residual / gap |
|---|---|---|---|
| Cross-org read via an org id in a request | `organizations` / `memberships` / `invitations` | SELECT policies keyed on `is_active_member(org)` / `has_org_role(org,'partner')` — the org is derived from membership, never trusted from the request (battery 01/02 cross-org deny rows) | — |
| An org role alone reads a matter | `matters` | `matters_select_assigned`: `is_active_member(org)` **AND** `assigned_client_id`/`assigned_attorney_id` = `auth.uid()` — matrix §4 "org role alone → deny, every role" (04.06) | — |
| Matter-scoped content leaks when the matter is not readable | `documents` / `message_threads` / `messages` / `billing_invoices` | The load-bearing **org-equality clause**: content org must equal the matter's authoritative org (D-DR2/D-MSR2/D-RT2/D-BI2); org-mismatch deny rows are **non-vacuous** (05.05, 06.05, 08.06, 11.05) | — |
| Suspended/removed member keeps reading | all content + roster tables | `is_active_member()` filters `status = 'active'` (02); suspended-denial battery rows per slice (04.07, 05.07, 06.07, 07.07, 08.07, 09.08, 10.05, 11.07); a suspended-but-still-assigned fixture pins the storage layer too (07) | — |
| Owner reads matter content | content tables | **No owner carve-out exists in any content policy** (Q4 recorded residual per slice — "owner accounts are never assigned, an operational invariant, not a policy guarantee"); battery 03.06–03.09 + per-slice owner-deny rows | If an owner account were ever assigned as client/attorney, the assignment columns would grant it — the invariant, not a policy, prevents this |
| Guessed / path-traversal storage reads | `storage.objects` | Path-encoded `{org}/{matter}/{filename}`; `files_storage_select` parses `storage.foldername(name)`, requires the path-org segment to equal the matter's authoritative org, and denies guessed/foreign/malformed paths for every role (07.12 — non-vacuous); bucket is private | Signed-URL TTL window after membership removal (D-STR4 — recorded, not a battery row) |
| Realtime delivers rows the subscriber lost access to | Realtime channel | Publication membership is **enablement only**; Realtime RLS makes `messages_select_assigned` the delivery gate (D-LV3); battery 09.11/09.12 delivery-equivalence (assigned sees the row; suspended/cross-org/owner see 0); harness pin `pg_publication_tables` = exactly 1 (nothing else can be added silently) | The battery proves the RLS proxy, not a live websocket round-trip — the env-gated client slice (D-LV4) is the honest limit |
| Enumeration via error differences | invite/accept/reset | Generic `invalid invitation` for every failure mode; `invite_member` refuses an already-membership email up front; reset flow renders one localized non-enumerating denial (P3.1) | — |
| Email / PII in diagnostics | client diagnostics | Redaction contracts (`toRedactedMap()` — password/OTP/email/Bearer), `Redactor` with leak guards; audit summaries generic (`'message sent'`, never body); correlation ids carry no secrets (contract §6) | — |

### 4.5 Denial of service / availability

| Threat | Surface | Current control (evidence) | Residual / gap |
|---|---|---|---|
| Abusive RPC traffic (invite spam, audit reads) | RPCs | Provider-side GoTrue rate limits (D-07, default posture); EXECUTE restricted to `authenticated` (anon denied — harness §1d); no custom throttling layer for MVP | Provider limits are not client-verifiable; recorded, not asserted |
| Realtime event flooding / channel abuse | publication | Publication pinned to exactly `messages` (harness forward pin) — an attacker cannot subscribe to other tables; delivery gated by RLS | Client reconnect/backfill polish (D-LV4) recorded as follow-up |
| Resource exhaustion via path probing | `storage.objects` | Every probe is an RLS-denied lookup; no unauthenticated read path | — |
| Schema bloat / missing cleanup | `invitations` | `expire_stale_invitations()` (definer, EXECUTE-revoked) flips stale rows; acceptance re-checks expiry server-side | Cleanup scheduling (pg_cron / maintenance RPC) is a reviewed maintenance choice, not yet wired |

### 4.6 Elevation of privilege

| Threat | Surface | Current control (evidence) | Residual / gap |
|---|---|---|---|
| Client grants itself a role / org / owner flag | all seams | Roles are **server-owned**: `create_organization` makes the caller partner by RPC; `accept_invitation` uses the invitation's stored role; `platform_config` is migration-seeded (03) — no client-writable authority field exists (contract §2 #2) | — |
| `security definer` function misuse | all definer helpers/RPCs | `search_path = public` pinned on every definer body (no schema-confusion); EXECUTE revoked from `public`/`anon`/`authenticated` on helpers (02), granted narrowly on the 19 RPCs; the two policy-eval grants (`is_active_member`, `has_org_role`) are self-scoped (a caller learns only facts about themselves) | — |
| Partner escalates beyond membership management | partner RPCs | Partner gates use `has_org_role(org,'partner')` on **active** memberships only; last-partner guards block self-lockout (change_member_role / suspend_membership, hardened 2026-08-03); `platform_owner_admin` is **not** a bypass for any org RPC (03.15 — owner denied via the partner RPC) | — |
| Owner capability creep | `platform_owner_admin` | Bounded "May" list (metadata only) with the §5 boundary: never matter content, never impersonation, never audit mutation; enforced server-side (03.06–03.27 sweep + per-slice owner-deny rows + harness structural pins) | The single owner account is the highest-value target — MFA for the owner account is a reasonable v1 hardening (deferred, D-07) |
| Function/trigger confusion (search_path, default grants) | 02 functions + new functions | `set search_path = public` on all definer bodies; `alter default privileges … revoke execute from anon, authenticated` (R-3 hardening) so future public functions do not inherit EXECUTE | — |

---

## 5. Cross-surface controls index

### 5.1 Per-table policy + grant + battery

| Table | Policies (public) | Direct grants | Battery (pos/neg coverage) |
|---|---|---|---|
| `profiles` | `profiles_select_own`, `profiles_update_own` | SELECT, UPDATE(display_name, locale) | 01 |
| `organizations` | `organizations_select_active_member` | SELECT | 01/02 |
| `memberships` | `memberships_select_org_roster` | SELECT | 01/02 (+ hardening guards) |
| `invitations` | `invitations_select_partner` | SELECT | 02 (+ resend/revoke) |
| `audit_events` | **none** (D-P0C4) | **none** | 03 (append-only, forge, RPC-only) |
| `platform_config` | **none** | **none** | 03 (single-account bound) |
| `matters` | `matters_select_assigned` | SELECT | 04 (10 blocks) |
| `documents` | `documents_select_assigned` | SELECT | 05 (11 blocks) |
| `message_threads` | `message_threads_select_assigned` | SELECT | 06 (11 blocks) |
| `files` | `files_select_assigned` | SELECT | 07 (22 blocks, both layers) |
| `storage.objects` | `files_storage_select` (storage schema) | platform default | 07 (bytes layer incl. guessed path) |
| `messages` | `messages_select_assigned` | SELECT (INSERT **revoked**, D-SM3) | 08 (12 blocks) + 09/10 |
| `billing_invoices` | `invoices_select_assigned` | SELECT | 11 (12 blocks) |

### 5.2 RPC inventory — in-function gates

| RPC | Gate (inside the definer body) | Audited |
|---|---|---|
| `create_organization` | name non-empty; caller becomes partner (server-owned) | ✅ |
| `accept_invitation` | token sha-256 match + pending + unexpired + JWT-email match; generic denial | ✅ |
| `invite_member` | `has_org_role(org,'partner')`; existing-member guard; role enum-bound | ✅ |
| `resend_invitation` / `revoke_invitation` | partner gate + own-org invite | ✅ |
| `change_member_role` / `suspend_membership` / `reactivate_membership` / `remove_membership` | partner gate + last-partner guard; same-org target | ✅ |
| `delete_my_account` | self only, cascade (D-05) | ✅ |
| `list_organizations_metadata` / `list_members_metadata` / `suspend_membership_platform` / `reactivate_membership_platform` / `delete_demo_account` | `is_platform_owner()`; delete refuses self | ✅ |
| `list_org_members_metadata` | partner gate; own-org roster; static `(no profile)` fallback | ✅ |
| `read_org_audit` | partner gate; self-audits | ✅ (the read itself) |
| `read_platform_audit` | owner gate; self-audits | ✅ (the read itself) |
| `send_message` | D-SM1: active member + thread→matter three-way org equality + assignment; **sole write path** (D-SM3) | ✅ (`message:create`, redacted) |

---

## 6. Residual risks and recorded follow-ups (honest, per §1.3 #5)

1. **Owner account is the single highest-value target** — `platform_owner_admin`
   is one account; MFA/SSO deferred to v1 (D-07). No policy weakness, but a
   credential-hygiene exposure.
2. **Signed-URL TTL window** — an issued URL stays valid until its TTL after
   membership removal (D-STR4); minting is RLS-gated, mid-flight revocation is
   not. Recorded as a future-facing negative, not a battery row.
3. **Realtime delivery verified by RLS proxy, not live websocket** — the
   client subscription round-trip (D-LV4, reconnect/backfill) is the honest
   limit; the batteries prove the delivery gate.
4. **Invite emails (R2) not shipped** — token delivery is out-of-band (the
   inviter receives the literal token once, in-app); a GoTrue email trigger
   would be a provider-config slice with its own review.
5. **Demo clients hold no membership rows** — their 0-everything reads are the
   membership guard firing as designed; a fuller client demo is a deliberate,
   separate data action (owner-approved).
6. **Provider-side controls** (GoTrue rate limits, hosting posture) are
   assumed, not client-verifiable.
7. **No custom throttling / no password-reset rate-limit layer** beyond GoTrue
   defaults (D-07).
8. **Denied RPC attempts are not logged as `denied` audit rows** (deliberate:
   no probe noise; the §8 negative is pinned in 10.09). A future ops choice,
   not a contract gap.
9. **Deferred surfaces with no threat surface yet:** AI (D-07/D-08 +
   undefined scope), video consultation (D-11), real payment (D-11/Paymob,
   metadata-only table), notification delivery (v1).
10. **Consummation (2026-08-09, F-01 step 1 — the never-assigned invariant is
    now pinned):** `supabase/tests/12_owner_assignment.sql` asserts the
    platform-owner id (derived from `platform_config`) never appears in any
    matter assignment column or content-table uuid column, with non-vacuity
    preconditions; wired into `scripts/verify_policy_tests.sh` (file list,
    static scans, run loop, selftest glob). The §4.4/§4.6 owner-deny rows
    remain an *invariant* rather than a policy clause until F-01 step 2
    (refuse owner assignment in the future matter-write slice) ships — the
    categorical guarantee therefore still depends on that future write path;
    the battery now ensures the bad state can never be seeded silently.
11. **F-01 step 2 BUILT + r1 PASSED + REVIEW PASS (2026-08-09):** the
    matter-creation slice (`docs/f01_step2_matter_write_design_2026-08-09.md`)
    refuses owner assignment in the `create_matter` RPC **and** enforces it
    categorically via a `BEFORE INSERT OR UPDATE` trigger on `matters`;
    battery 13 (16 blocks, incl. the UPDATE arm) pins the refusal. The r1
    rehearsal genuinely executed 2026-08-09 on the ephemeral stack —
    `--apply` 44/44, full battery **82/0/0 ×2**, battery 13 all checks green
    (evidence `docs/matter_write_slice_rehearsal_r1_2026-08-09.md`); the
    mechanism/RLS-gate review PASSED the same date
    (`docs/matter_write_slice_review_2026-08-09.md`, findings R-1/R-2
    remediated in-review). **APPLIED to the dev project 2026-08-09**
    (execution evidence `docs/matter_write_apply_execution_2026-08-09.md`;
    dated approval `docs/matter_write_apply_approval_2026-08-09.md` §6):
    the §4.4/§4.6 owner-deny rows are now an **enforced guarantee** for all
    new writes (RPC refusal + categorical trigger), verified live (demo
    create `d28f1f05-…` + §8 audit row, owner-refusal + member-guard + anon
    negatives, owner reads 0). **F-12 (surfaced by the apply, now
    RESOLVED 2026-08-09):** the dev demo matter `a6715e17-…` had been
    seeded (2026-08-07, pre-F-01) with the platform-owner id as its
    assigned client; the state was **contained** (the owner holds no
    memberships, so the `is_active_member` arm of `matters_select_assigned`
    blocked the read — verified live) and was **remediated** the same day
    (owner-directed re-assignment onto the demo-client account with a
    machine audit row — `docs/f12_data_remediation_2026-08-09.md`): the
    owner id now appears in **no** assignment column. The matrix §4
    addendum + applied-surface addendum are in place; the env-gated client
    swap remains.

---

## 7. What this write-up does NOT close

- **P4 gate stays OPEN.** Item 3 (controlled-rollout rehearsal — the
  `docs/rollback_plan.md` dry-run on a staging/dev-project cycle) and item 4
  (dated owner release approval naming where the client ships) are
  **owner-only** and not performed here.
- This is **not** a legal/compliance assessment (D-03) and **not** a claim
  that the product is production-compliant — it records verified controls and
  honest residuals for the P0-closure security review.
- No code, policy, or battery was changed to produce this record.

---

## 8. Verification basis and evidence index

- **Commands actually run (2026-08-09):** `bash scripts/verify_policy_tests.sh --check`
  → **RESULT: PASS — static battery validated (73 passed, 0 warnings, 0
  failures)**; `git status` clean at `b7325f8` before adding this record.
- **Harness scan correction (2026-08-09):** the `--check` UUID cross-ref scan
  carried a latent line-continuation bug (files 07–13 never scanned, dedup
  detached) since the storage slice; fixed during the F-01 step 2 build. The
  339 printed when this write-up was first verified was the buggy scan's
  count; the corrected static gate is **73/0/0** — full record in
  `docs/p4_findings_register_2026-08-09.md` §3b.
- **Structural pins:** `scripts/verify_policy_tests.sh` §1a (12 tables / 12
  RLS), §1b (narrow SELECT grants, anon/audit/platform absent), §1c (helper
  EXECUTE surface), §1d (19 RPC-EXECUTE, anon denied), §1e (11 public
  policies; 0 on audit_events/platform_config), §1f (publication = exactly
  `messages`), §1g (bucket + storage policy = 1).
- **Behavior batteries:** `supabase/tests/00_fixtures.sql` +
  `01_identity_session.sql` (matrix §2) · `02_organization_membership.sql`
  (matrix §3) · `03_platform_owner_boundary.sql` (matrix §5 + D-P0C1/D-P0C3/
  D-P0C4) · `04_matter_rls.sql` · `05_document_rls.sql` ·
  `06_message_rls.sql` · `07_storage_rls.sql` · `08_message_rls.sql` ·
  `09_realtime_push.sql` · `10_send_message_rls.sql` · `11_invoice_rls.sql`.
- **Live rehearsal evidence (genuinely executed, ephemeral host):** the r1
  records per §14 slice with their executed check counts (realtime read
  70/0/0 · realtime push 72/0/0 · storage + send-message 74/0/0 · billing
  78/0/0; the matters/documents/messages r1 counts are recorded in their
  own evidence docs) — index: `docs/p14_plan_complete_2026-08-08.md` §3.
- **Applied surface (single source of truth):**
  `docs/current_applied_surface_2026-08-08.md` (12 tables / 12 RLS / 11+1
  policies / 19 RPCs / publication exactly `messages` / `matter-files` bucket
  / demo rows).
- **Matrix + decisions:** `docs/permission_matrix.md` (signed, dated
  addenda) · `docs/p0_decision_capture.md` §1 (D-02…D-10b) ·
  `docs/auth_tenant_authorization_contract.md` (non-negotiables) ·
  `docs/security_review_gate_record_2026-08-09.md` (gate status + STRIDE-lite
  sketch this record supersedes in depth).
