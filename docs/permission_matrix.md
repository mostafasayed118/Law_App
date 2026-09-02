# LegalHub — Permission Matrix (v1, MVP)

> **Record type:** The signed permission matrix required by
> `auth_tenant_authorization_contract.md` §9 and referenced as a P1-readiness
> precondition in `docs/p0_decision_capture.md` §2. Covers **positive and
> negative** cases per contract §9 — a passing happy path alone is not
> sufficient.
>
> **Status:** Drafted 2026-07-31, decisions per `p0_decision_capture.md`
> §1 (D-06, D-09, D-10a, D-10b) and its Addendum.
> **Enforcement:** every row here must be enforced **server-side** (RLS /
> RPC / policy) once P2 lands. Nothing in this document authorizes a
> client-only implementation of any row — client-side checks are UX hints
> only, per contract §2 non-negotiable #2.
> **Test contract:** every row must have at least one automated positive
> test and at least one automated negative test once P2 policy tests are
> written (contract §9).

---

## 1. Roles in scope

| Role | Scope | Held by |
|---|---|---|
| `client` | Own profile + explicitly assigned client-facing resources | Org members |
| `attorney` | Assigned matters + approved org functions | Org members |
| `partner` | Organization oversight, membership management | Org members |
| `compliance_officer` | Approved policy-review functions | Org members |
| `platform_owner_admin` | Cross-org identity/membership administration **only** — never matter content | **Project Owner's account only** (not assignable via product UI; see `p0_decision_capture.md` Addendum) |

Unauthenticated / no valid session is treated as a distinct row ("anon") in
every table below — this is the default-deny baseline (contract §2.1).

---

## 2. Identity & session actions

| Action | anon | client | attorney | partner | compliance_officer | platform_owner_admin |
|---|---|---|---|---|---|---|
| Sign up / sign in | ✅ | — | — | — | — | — |
| View own profile | ❌ deny | ✅ own only | ✅ own only | ✅ own only | ✅ own only | ✅ own only |
| Edit own profile | ❌ deny | ✅ own only | ✅ own only | ✅ own only | ✅ own only | ✅ own only |
| View **another** user's profile (any org) | ❌ deny | ❌ deny | ❌ deny | ❌ deny | ❌ deny | ✅ any org (metadata only, see §5) |
| Delete own account | ❌ deny | ✅ | ✅ | ✅ | ✅ | ✅ |
| Sign out | ✅ (no-op) | ✅ | ✅ | ✅ | ✅ | ✅ |

> **§2 addendum (2026-08-01, D-T6):** the `partner` cell for "View
> **another** user's profile" is amended from "✅ same org only" to "❌
> deny". The gate-approved design (`docs/p2_schema_rls_design.md` §5.2) makes
> `profiles` **own-row-only**, and the reviewed slice (`b5f7e7c`) ships no
> partner profile-metadata RPC (`list_members_metadata` is owner-gated) — the
> matrix row promised a capability the approved design deliberately did not
> implement. Resolution: **amend the matrix, not the slice** — the default-deny
> direction (own-row-only for every non-owner role), with the partner's §3
> roster access unchanged. A partner needing a member's display name in P3 is
> a separate reviewed RPC decision, not this row (sequenced as **Phase 3.2**
> of the planning roadmap, `docs/features_roadmap_2026-08-03.md`). Recorded as **D-T6** in
> `docs/tracked_deviations.md`; this addendum satisfies the §7
> dated-addendum discipline.

> **§2 addendum (2026-08-03, Phase 3 R1 design — PROPOSED; takes effect on
> apply approval):** the D-T6 forward hook materializes as a reviewed RPC
> decision. The `partner` cell for "View **another** user's profile" is
> amended from "❌ deny" to a **narrow, RPC-bounded allowance**: ✅ own-org
> member **metadata** (display_name, locale, role, status, timestamps, and
> the `invitation_id` for pending invites) via the new partner-scoped RPC
> `list_org_members_metadata(p_organization_id)` — design
> `docs/p3_r1_roster_rpc_design_2026-08-03.md`, rehearsal plan
> `docs/p3_r1_rehearsal_plan_2026-08-03.md`. The raw `profiles` table stays
> **own-row-only** (D-T6 unchanged); cross-org metadata stays ❌ deny; no
> other role gains anything. This supersedes the 2026-08-01 addendum's
> "separate RPC decision" reservation (that decision is now **this** RPC),
> and roadmap Phase 3.2's separate display-name RPC is **absorbed** into it
> (Q5 surface minimality — exactly one new RPC). The addendum is inert until
> the RPC exists and the rehearsal proves the negative rows below.

**Positive / negative rows for the new RPC (`list_org_members_metadata`,
contract §9 — every row needs ≥1 positive + ≥1 negative test):**

| Row | Positive (must pass) | Negative (must deny) |
|---|---|---|
| Partner reads own org roster + member metadata (names, locale, role, status, timestamps) via the RPC | `partner@org-a` → full roster incl. display names | `client`/`attorney`/`compliance_officer` of org-a → denied (own-row-only does not apply — denied entirely); anon → denied (no grant) |
| Pending invites + invitation ids via the RPC (R1 extension) | `partner@org-a` → pending invites with `invitation_id`; no token material | revoked/expired/accepted invites never appear; invite rows of another org unreachable |
| Cross-org via the RPC (org param swapped) | — | `partner@org-a` with `org-b` → denied (same generic `permission denied` as a nonexistent org — no enumeration) |
| Suspended / removed partner via the RPC | — | suspended or removed partner → denied, stale client session notwithstanding |
| `platform_owner_admin` via the RPC (no partner membership) | — | denied — `is_platform_owner()` is not a bypass; the owner surface stays `list_members_metadata` |
| Raw `profiles` reads (D-T6 pair) | — | `partner@org-a` `select` on another member's `profiles` row → 0 rows — the RPC is the **only** widened path |
| Orphan-membership defense (LEFT JOIN + COALESCE) | a membership whose `profiles` row is missing still appears in the roster, with the static fallback `'(no profile)'`/`'en'` — no row dropped, no error | the fallback is static — no uuid or email appears in `display_name`; no member row ever drops from the roster over a missing profile row |

**Negative tests required (contract §9 identity/session block):**
- No valid session → every non-sign-up/in row above denies, not empty-success.
- Expired/revoked session → re-auth required; a cached client role/org
  selection must **not** restore access.
- Reset request for unknown email → generic response, no enumeration signal.
- Reused/expired/foreign reset token → denied without exposing which part
  failed.
- Old session token reused after sign-out → denied.

---

## 3. Organization & membership actions

| Action | client | attorney | partner (own org) | compliance_officer | platform_owner_admin |
|---|---|---|---|---|---|
| View own org's member list | ✅ | ✅ | ✅ | ✅ | ✅ (any org) |
| View **another** org's member list | ❌ deny | ❌ deny | ❌ deny | ❌ deny | ✅ (metadata only) |
| Invite a new member | ❌ deny | ❌ deny | ✅ | ❌ deny | ❌ deny |
| Resend / revoke a pending invite | ❌ deny | ❌ deny | ✅ (own org's invites) | ❌ deny | ❌ deny |
| Change a member's role | ❌ deny | ❌ deny | ✅ (own org) | ❌ deny | ❌ deny |
| Suspend / reactivate a membership | ❌ deny | ❌ deny | ✅ (own org) | ❌ deny | ✅ (any org, metadata-level action) |
| Remove a member | ❌ deny | ❌ deny | ✅ (own org) | ❌ deny | ❌ deny |
| Delete a synthetic demo account | ❌ deny | ❌ deny | ❌ deny | ❌ deny | ✅ |
| Switch active organization (own memberships) | ✅ | ✅ | ✅ | ✅ | n/a (no org membership) |

The partner-facing client surface for these rows (invite, change role,
suspend/reactivate, remove, switch active org) is the P3 org/membership UI
slice — **Phase 1** of the planning roadmap
(`docs/features_roadmap_2026-08-03.md`, the owning planning document); rows
needing new server RPCs (member-facing roster, display names) are Phase 3
there.

**Negative tests required (contract §9 tenant/membership block):**
- An active `org-a` member cannot read/write/subscribe-to/download `org-b`
  data by changing a request parameter — proven for **every** action row
  above, not just reads.
- A suspended/removed/expired membership cannot authorize any protected
  path, even if the client's cached session still shows the old role.
- A user with two active memberships cannot touch the second org without
  explicitly selecting a valid context; selection never bypasses the
  membership check.
- Client-supplied `organization_id`, `role`, `owner_id`, `approved_by`, and
  audit-actor values cannot elevate access or cross tenant boundaries.
- `partner` in `org-a` cannot invite/change-role/suspend/remove a member of
  `org-b`.

---

## 4. Matter & document actions (P2+, scaffolded now for completeness)

| Action | client | attorney | partner | compliance_officer | platform_owner_admin |
|---|---|---|---|---|---|
| View a matter | ✅ if assigned as the client on it | ✅ if assigned to it | ✅ org policy-approved oversight only, not blanket | ✅ policy-review scope only | ❌ **deny, always** |
| Read a document/message body | ✅ if assigned | ✅ if assigned | ❌ deny unless separately assigned | ❌ deny unless separately assigned | ❌ **deny, always** |
| Send a message (insert) | ✅ if assigned | ✅ if assigned | ❌ deny unless separately assigned | ❌ deny unless separately assigned | ❌ **deny, always** |
| An org role alone (no matter assignment) | ❌ deny | ❌ deny | ❌ deny | ❌ deny | ❌ deny |

**Negative tests required (contract §9 role/nested-scope block):**
- An org role without an explicit matter assignment cannot read a
  restricted matter or its documents/messages — true for **every** role,
  including `partner` and `compliance_officer`.
- A matter in `org-a` cannot be accessed by an otherwise-authorized member
  of `org-b`.
- `platform_owner_admin` attempting to read any matter/document/message
  content must be denied at the RLS layer, not just hidden in the UI — this
  is the row that most directly guards against admin-capability creep.
- Role changes take effect on the **next** authorization check; a role
  change leaves an audit record; stale client capability state is never
  authoritative.

> **§4 addendum (2026-08-07, real-matters read slice — plan
> `docs/matters_real_data_plan_2026-08-07.md`, first §14 un-deferral):** the
> **"View a matter" row's client/attorney cells now SHIP** — granted
> server-side by `matters_select_assigned`
> (`supabase/policies/matters.sql`) and policy-tested by
> `supabase/tests/04_matter_rls.sql` (rehearsal r1 **PASSED 2026-08-07**,
> evidence `docs/matters_rehearsal_evidence_r1_2026-08-07.md`; static
> battery `--check` 24/0/0). The grant is exactly: an **active member of
> the matter's org** who is the assigned **client** or the assigned
> **attorney**. Deny rows now each have a battery check:
> - **org role alone** (no assignment) → deny, every role;
> - **cross-org** (assigned on an org-a matter, org-b member only) → deny;
> - **suspended membership** in the matter's org → deny;
> - **unauthenticated** → deny;
> - **`platform_owner_admin`** → deny, always (owner accounts are never
>   assigned — an operational invariant, not a policy guarantee; recorded
>   residual in `docs/matters_rls_gate_review_2026-08-07.md` Q4).
> **Not granted by this addendum:** the partner "org policy-approved
> oversight only, not blanket" and `compliance_officer` "policy-review
> scope only" cells — the oversight mechanism is undefined (D-MR5) and
> stays future work; "Read a document/message body" stays §14-deferred
> (documents/messages tables still absent — the forward pin was re-scoped
> to documents/messages/files). **Basis:** §14 gate-lift (P0 closure
> RATIFIED + policy battery shipped) · r1 PASS (`ea3a15d`) · apply-approval
> DRAFT (`docs/matters_apply_approval_2026-08-07.md`, §6 signature
> pending). Per §7 this extends, not replaces, and widens no other row;
> effective on apply execution, and the client surface (plan T7) ships only
> after the apply lands.

> **§4 addendum (2026-08-07, real-documents read slice — plan
> `docs/documents_real_data_plan_2026-08-07.md`, second §14 un-deferral):**
> a **new "View a document (metadata)" row is added** — the **client /
> attorney cells SHIP**, granted server-side by `documents_select_assigned`
> (`supabase/policies/documents.sql`) and policy-tested by
> `supabase/tests/05_document_rls.sql` (rehearsal r1 **PASSED 2026-08-07**,
> evidence `docs/documents_rehearsal_evidence_r1_2026-08-07.md`; static
> battery `--check` 31/0/0). The grant is exactly: an **active member of
> the document's org** who is the assigned **client** or the assigned
> **attorney** on the document's matter — documents are **matter-scoped
> content** (line 143/148), so the document gate IS the matter gate (the
> policy's exists subquery on `matters`). Deny rows now each have a
> battery check:
> - **org role alone** (no matter assignment) → deny, every role;
> - **org-mismatch** (document org ≠ its matter's org) → deny, every role
>   — the load-bearing D-DR2 clause (a document is never readable when its
>   matter is not, line 143/148);
> - **cross-org** (assigned on an org-a matter, org-b member only) → deny;
> - **suspended membership** in the document's org → deny;
> - **unauthenticated** → deny;
> - **`platform_owner_admin`** → deny, always (owner accounts are never
>   assigned — an operational invariant, not a policy guarantee; recorded
>   residual in `docs/documents_rls_gate_review_2026-08-07.md` Q4).
> The battery also pins the schema contract + teardown safety beyond the
> grant rows: the `document_type` CHECK rejects an unmapped value and the
> matter-delete FK cascade removes a matter's documents (05.10/05.11).
> **Not granted by this addendum:** the partner / `compliance_officer`
> "deny unless separately assigned" cells stay **ungranted** (the oversight
> mechanism is undefined, D-DR5 — future work, mirroring D-MR5); **the
> "Read a document/message body" row keeps its §14 deferral** — the
> documents table is metadata-only, **no body/content/size/url column
> exists** (D-V1), so body reads are structurally impossible in this
> slice. **Basis:** §14 gate-lift (P0 closure RATIFIED + policy battery
> shipped) · r1 PASS (`7f9e89a`) · apply-approval + execution
> (`docs/documents_apply_approval_2026-08-07.md` APPLY APPROVED 2026-08-07
> + `docs/documents_apply_execution_2026-08-07.md` `f500095` — applied and
> verified on the dev project). Per §7 this extends, not replaces, and
> widens no other row; **in effect since the apply execution 2026-08-07
> (`f500095`)**, and the client surface (plan T7) ships next.

> **§4 addendum (2026-08-07, real-messages read slice — plan
> `docs/messages_real_data_plan_2026-08-07.md`, third §14 un-deferral):**
> a **new "View a message thread (metadata)" row is added** — the
> **client / attorney cells SHIP**, granted server-side by
> `message_threads_select_assigned`
> (`supabase/policies/message_threads.sql`) and policy-tested by
> `supabase/tests/06_message_rls.sql` (rehearsal r1 **PASSED 2026-08-07**,
> evidence `docs/messages_rehearsal_evidence_r1_2026-08-07.md`; static
> battery `--check` 37/0/0). The grant is exactly: an **active member of
> the thread's org** who is the assigned **client** or the assigned
> **attorney** on the thread's matter — threads are **matter-scoped
> content** (line 143/148), so the thread gate IS the matter gate (the
> policy's exists subquery on `matters`). Deny rows now each have a
> battery check:
> - **org role alone** (no matter assignment) → deny, every role;
> - **org-mismatch** (thread org ≠ its matter's org) → deny, every role
>   — the load-bearing D-MSR2 clause (a thread is never readable when its
>   matter is not, line 143/148), NON-VACUOUS: the battery's 06.02 count
>   proves an assigned reader reads org-a threads generally, so the 06.05
>   deny is specifically the clause;
> - **cross-org** (assigned on an org-a matter, org-b member only) → deny;
> - **suspended membership** in the thread's org → deny;
> - **unauthenticated** → deny;
> - **`platform_owner_admin`** → deny, always (owner accounts are never
>   assigned — an operational invariant, not a policy guarantee; recorded
>   residual in `docs/messages_rls_gate_review_2026-08-07.md` Q4).
> The battery also pins the schema contract + teardown safety beyond the
> grant rows: the `message_count` CHECK rejects a negative count and the
> matter-delete FK cascade removes a matter's threads (06.10/06.11).
> **Not granted by this addendum:** the partner / `compliance_officer`
> "deny unless separately assigned" cells stay **ungranted** (the oversight
> mechanism is undefined, D-MSR5 — future work, mirroring D-MR5/D-DR5);
> **the "Read a document/message body" row keeps its §14 deferral** — the
> `message_threads` table is thread-metadata-only, **no
> body/preview/attachment/sender column exists** (D-MSG1), and the
> forward pin now narrows to `('messages','files')` (individual message
> rows/bodies + file storage stay deferred; the never-built
> `matter_documents`/`matter_messages` join-table names are dropped).
> **Basis:** §14 gate-lift (P0 closure RATIFIED + policy battery
> shipped) · r1 PASS (`a37c6dc`) · apply-approval + execution
> (`docs/messages_apply_approval_2026-08-07.md` APPLY APPROVED 2026-08-07
> + `docs/messages_apply_execution_2026-08-07.md` `a14650d` — applied and
> verified on the dev project: 9 tables / 9 RLS / 8 policies live, the
> D-MSR2 join probe 0 mismatches, smoke partner 3 / clients 0). Per §7
> this extends, not replaces, and widens no other row; **in effect since
> the apply execution 2026-08-07 (`a14650d`)**, and the client surface
> (plan T7) ships next.

> **§4 addendum (2026-08-08, real-storage read slice — plan
> `docs/storage_real_data_plan_2026-08-08.md`, fourth §14 un-deferral):**
> a **new "View a matter file (metadata)" row is added** — the **client /
> attorney cells SHIP**, granted server-side by `files_select_assigned`
> (`supabase/policies/files.sql`) on the `public.files` metadata table and
> by `files_storage_select` (`supabase/policies/storage_objects.sql`) on
> `storage.objects` (the private `matter-files` bucket — the byte-level
> read), policy-tested by `supabase/tests/07_storage_rls.sql` (22 check
> blocks; static battery `--check` **331/0/0**; the live battery is the
> r1 rehearsal, ⏳ evidence pending). The grant is exactly: an **active
> member of the file's org** who is the assigned **client** or the assigned
> **attorney** on the file's matter — files are **matter-scoped content**
> (line 143/148; §6 storage rows). Deny rows now each have a battery
> check, on **BOTH layers** (`public.files` metadata + `storage.objects`
> bytes, path-encoded `{org}/{matter}/{filename}`):
> - **org role alone** (no matter assignment) → deny, every role;
> - **org-mismatch** (file row org ≠ its matter's org; object **path org
>   segment** ≠ its matter's org) → deny, every role — the load-bearing
>   D-STR2 clause (a file/object is never readable when its matter is
>   not, line 143/148), NON-VACUOUS on both layers (07.01 counts prove an
>   assigned reader reads org-a files/objects generally, so the 07.05
>   deny is the clause);
> - **cross-org** (assigned on an org-a matter, org-b member only) → deny;
> - **suspended membership** in the file's org → deny — the
>   `is_active_member` arm is load-bearing on the objects layer too
>   (fixture matter 6 assigns `suspended-a`; without it the bytes would
>   leak);
> - **unauthenticated** → deny (files: no grant; objects: RLS-0, either
>   storage-schema posture accepted);
> - **`platform_owner_admin`** → deny, always (owner accounts are never
>   assigned — an operational invariant, not a policy guarantee; recorded
>   residual in `docs/storage_rls_gate_review_2026-08-08.md` Q4).
> The battery also pins the schema contract + teardown safety: the
> `size_bytes` CHECK rejects a negative size and the matter-delete FK
> cascade removes a matter's files rows (07.10/07.11), and the **matrix §6
> "Download a private object via a guessed path" row is now enforced** —
> the guessed-path object (unknown matter id) is denied for every role,
> non-vacuous (07.12). **Not granted by this addendum:** the partner /
> `compliance_officer` "deny unless separately assigned" cells stay
> **ungranted** (the oversight mechanism is undefined, D-STR6 — future
> work, mirroring D-MR5/D-DR5/D-MSR5); **the "Read a document/message
> body" row keeps its §14 deferral** — `public.files` is metadata-only,
> **no content/body/url column exists** (D-STR3; bytes live only in
> `storage.objects`), and the forward pin now narrows to `('messages')`
> (file storage shipped as the fourth un-deferral; individual message
> rows/bodies still deferred). **Basis:** §14 gate-lift (P0 closure
> RATIFIED + policy battery shipped) + three shipped precedents · RLS-gate
> review (`6f52930` + nits `0d7bdca`) · artifacts (`87b6ef5` + `0bc21ed`)
> · battery + harness (`47150be` + `83b406c`, static `--check` 331/0/0) ·
> r1 **⏳ PENDING — SUPERSEDED 2026-08-09 by the Consummation block below
> (r1 PASSED 2026-08-08, genuinely executed 74/0/0)**: (owner asserts
> PASSED on the Docker host; the evidence record
> `docs/storage_rehearsal_evidence_r1_2026-08-08.md` was then not yet
> filled — no observed output in the repo · now recorded: **PASSED**) · apply-approval **APPLY
> APPROVED 2026-08-08** (`docs/storage_apply_approval_2026-08-08.md`
> `91c49ce`; §6 dated sign-off) · apply execution **⏳ HELD — SUPERSEDED
> 2026-08-09 (EXECUTED 2026-08-08 — see the Consummation block below)**:
> the pre-apply read-only baseline was still verified at record time —
> files 0 · bucket 0 · public policies 8→9 · storage policies 0→1 · the
> four demo matter ids resolve under org `ef43087b-adf4-4480-9bb2-28c26f46ec71`
> · `storage.buckets.type` NOT NULL **with default** — the bare
> `(id, name, public)` insert is valid · `storage.foldername` present).
> **Consummation (2026-08-09, H2 — stale verdicts advanced to the
> observed facts):** r1 **PASSED 2026-08-08 — genuinely executed 74/0/0**
> (evidence `docs/storage_rehearsal_evidence_r1_2026-08-08.md` PASSED);
> the apply **EXECUTED 2026-08-08** (owner-approved; evidence
> `docs/storage_apply_execution_2026-08-08.md` APPLIED — up sequence
> complete: bucket `matter-files` 1, tables 10→11, RLS 10→11, public
> policies 9→10, storage policies 0→1, 4 demo files + 4 demo objects on
> the applied demo matters, smoke partner 3/3 + family 0, clients 0/0,
> anon denied on both layers); and the env-gated client surface
> **SHIPPED** (`704f212`, D-STR7 + `RoleCapability.canViewFiles`, suite
> 953/README 950, ledger PASS 115). Per §7 this extends, not replaces,
> and widens no other row; **in effect since the apply execution
> 2026-08-08** and the client swap `704f212`.

> **§4 addendum (2026-08-08, realtime read slice — plan
> `docs/realtime_real_data_plan_2026-08-08.md`, sixth §14 un-deferral):**
> **the "Read a document/message body" row's client/attorney cells now
> SHIP** — the body row's long deferral ends for the assigned reader only
> (line 143/148: messages are matter-scoped content). Granted server-side
> by `messages_select_assigned` (`supabase/policies/messages.sql`) and
> policy-tested by `supabase/tests/08_message_rls.sql` (rehearsal r1
> **PASSED 2026-08-08** — genuinely executed battery, 70/0/0, evidence
> `docs/realtime_rehearsal_evidence_r1_2026-08-08.md`; static battery
> `--check` 333/0/0). The grant is exactly: an **active member of the
> message's org** AND an exists through the thread to the matter with the
> **three-way org equality load-bearing** (`messages.organization_id =
> thread.organization_id = matter.organization_id`) AND the assigned
> **client** or assigned **attorney** on the thread's matter — the thread
> gate (D-MSR2) extended one hop (D-RT2); a message is never readable
> when its thread or matter is not. **The `body` column is the first
> content column in the public schema** — the deliberate, scoped D-MSG1
> reversal (read path only; no write grant), consummating the metadata-only
> deferral that the documents/messages/storage addenda recorded. Deny rows
> now each have a battery check:
> - **org role alone** (no matter assignment) → deny, every role;
> - **org-mismatch** (message org ≠ its thread's/matter's org) → deny,
>   every role — the load-bearing D-RT2 clause, **NON-VACUOUS** (the
>   08 battery proves partner-a reads 6 messages on its assigned threads
>   generally, so the 08.06 deny is the clause);
> - **cross-org** (assigned on an org-a matter, org-b member only) → deny;
> - **suspended membership** in the message's org → deny;
> - **unauthenticated** → deny;
> - **`platform_owner_admin`** → deny, always (owner accounts are never
>   assigned — an operational invariant, not a policy guarantee; recorded
>   residual in `docs/realtime_rls_gate_review_2026-08-08.md` Q4).
> The battery also pins the schema contract + teardown safety: the
> `body` CHECK rejects an empty body (verified live on the dev project in
> the apply smoke), the thread-delete FK cascade removes a thread's
> messages, and the 08.12 mapping-consistency pin (every thread's live
> message count equals its `message_count` column — the seeded demo rows
> match 1/2/3/4). **Not granted by this addendum:** the partner /
> `compliance_officer` "deny unless separately assigned" cells stay
> **ungranted** (the oversight mechanism is undefined — future work,
> mirroring D-MR5/D-DR5/D-MSR5/D-STR6); **live delivery stays
> §14-deferred (D-RT6)** — `postgres_changes`/Supabase Realtime push is a
> different authorization surface (publication membership ≠ table SELECT
> RLS) and gets its own mechanism review + dated approval; the forward
> pin now pins **messages present + live delivery absent** (the deferred
> item is the push half, not the table). **Basis:** §14 gate-lift (P0
> closure RATIFIED + policy battery shipped) + five shipped precedents ·
> RLS-gate review (`790f6e7`) · artifacts (`60198e2`) · battery + harness
> (`9f01870` + `f22e672`, static `--check` 333/0/0) · r1 PASS (`8204245`,
> genuinely executed 70/0/0) · apply-approval **APPLY APPROVED 2026-08-08**
> (`docs/realtime_apply_approval_2026-08-08.md` §6 dated sign-off, flipped
> in `35cceb9`) · apply execution (`docs/realtime_apply_execution_2026-08-08.md`
> `35cceb9` — applied and verified on the dev project: **10 tables / 10
> RLS / 9 policies live**, the D-RT2 org-mismatch probe 0, smoke partner 6
> / stranger 0, and the family-thread 4-denial as the assignment clause
> firing live). Per §7 this extends, not replaces, and widens no other
> row; **in effect since the apply execution 2026-08-08 (`35cceb9`)**, and
> the client surface (plan T7, env-gated `fetchMessages` + thread-detail
> screen) ships next.

> **§4 addendum (2026-08-08, realtime push slice — plan
> `docs/realtime_push_real_data_plan_2026-08-08.md`, seventh §14
> un-deferral):** a **new "Send a message (insert)" row is added** — the
> write side of the consummated body row (the read half shipped at the
> realtime-read T6, line 143/148): client/attorney cells **SHIP** — granted
> server-side by `messages_insert_assigned`
> (`supabase/policies/messages_insert.sql`; the write grant `insert on
> public.messages to authenticated` was added after the T2 live finding
> that 08 granted SELECT only — a policy without a grant never fires) and
> policy-tested by `supabase/tests/09_realtime_push.sql` (rehearsal r1
> **PASSED 2026-08-08** — genuinely executed battery, 72/0/0, evidence
> `docs/realtime_push_rehearsal_evidence_r1_2026-08-08.md`; static battery
> `--check` 335/0/0, selftest 6/6). The grant is exactly: an **active
> member of the message's org** AND an exists through the thread to the
> matter with the **three-way org equality load-bearing** AND the assigned
> **client** or assigned **attorney** on the thread's matter — the read
> gate (D-RT2/D-LV3) applied as WITH CHECK (D-LV1); a message can never be
> sent on a thread whose matter the writer is not assigned to. Deny rows
> now each have a battery check (09.05–09.09): org role alone · cross-org
> · suspended membership · `platform_owner_admin` (deny always — the §5
> content boundary extends to the write path; owner accounts are never
> assigned, recorded residual Q5) · unauthenticated (privilege-layer, no
> grant) + the empty-body CHECK (schema-level, 09.10). **Insert-only:** no
> UPDATE/DELETE policy (no edit/delete/attachments/read-receipts — the
> write-path creep guard). **The direct-INSERT path is not contract §8-
> audited** (the demo-seed posture, review Q6 — a future real-write slice
> should route sends through an audited RPC). **Not granted:** the
> partner / `compliance_officer` "deny unless separately assigned" cells
> stay **ungranted** (the oversight mechanism is undefined — future work,
> mirroring D-MR5/D-DR5/D-MSR5/D-STR6). **Basis:** §14 gate-lift (P0
> closure RATIFIED + policy battery shipped) + six shipped precedents ·
> mechanism review (`af1715c`) · artifacts (`f1d7903`, validated live on
> the rehearsal host) · battery + harness (`6302bdc`, static `--check`
> 335/0/0) · r1 PASS (`51532fd`, genuinely executed 72/0/0) ·
> apply-approval **APPLY APPROVED 2026-08-08**
> (`docs/realtime_push_apply_approval_2026-08-08.md` §6 dated sign-off) ·
> apply execution (`docs/realtime_push_apply_execution_2026-08-08.md`
> `7efb32b` — applied and verified on the dev project: **11 tables / 11
> RLS / 10 policies live, publication exactly messages**, the first live
> INSERT `7cbf49e0-…` through `messages_insert_assigned`, smoke partner 1 /
> assigned-client-without-membership 0). Per §7 this extends, not
> replaces, and widens no other row; **in effect since the apply execution
> 2026-08-08 (`7efb32b`)**, and the client surface (plan T7, env-gated
> subscription + composer, D-LV1/D-LV4) ships next.

> **§4 addendum (2026-08-08, send-message slice — plan
> `docs/send_message_rpc_plan_2026-08-08.md`, the audited-write
> consummation):** the **"Send a message (insert)" row's server-side
> mechanism changes** — the write path moves from the policy-gated direct
> INSERT (`messages_insert_assigned`, the realtime-push addendum above)
> to the **audited `send_message` RPC** (`supabase/rpc/send_message.sql`,
> `security definer` with the **in-function gate** that re-asserts the
> exact same authorization — D-SM1: an active member of the thread's org
> AND the thread→matter three-way org equality AND the assigned
> client/attorney on the thread's matter). **D-SM3:** the direct-INSERT
> surface is revoked (the `authenticated` INSERT grant on `messages` +
> `messages_insert_assigned` dropped) so the RPC is the **only** message
> write path — **policies 10→9** on the dev project once the apply
> executes; the battery pins both halves (09.15 privilege-layer deny,
> 09.16 policy gone) plus the RPC behavior (`10_send_message_rls.sql`:
> assigned attorney + client positives with the D-RT4 stored author from
> profiles, the in-function deny rows org-role-alone / cross-org /
> suspended / owner / anon, the empty-body CHECK, and the §8 negative — a
> denied send writes no audit row). **Contract §8 audit closes the
> realtime-push review-Q6 gap** (the caveat recorded in the addendum
> above): every successful send writes `message:create/allowed` with the
> actor, the message resource id, and a redacted summary ('message sent'
> — never the body). Client/attorney cells stay **SHIP** (now via the
> RPC); the partner / `compliance_officer` "deny unless separately
> assigned" cells stay **ungranted** (unchanged — the oversight mechanism
> remains undefined); `platform_owner_admin` **deny, always** (unchanged
> — the §5 boundary extends to the write path, battery 10.07).
> **Basis:** mechanism review (`7759181`, Q1–Q6, D-SM1..D-SM3 ratified) ·
> artifact (`60dae71`, live-validated on the rehearsal host) · battery +
> harness (`b013ee5`, static `--check` 337/0/0, selftest 6/6) · r1 PASS
> (`8df7e47`, genuinely executed 74/0/0, evidence
> `docs/send_message_rehearsal_evidence_r1_2026-08-08.md`) · apply-
> approval **DRAFT** (`docs/send_message_apply_approval_2026-08-08.md`,
> awaiting the owner's §6 sign-off — the apply execution
> (`docs/send_message_apply_execution_2026-08-08.md`) will be cited here
> when it lands). Per §7 this extends, not replaces, and widens no other
> row; **committed before the client surface ships (plan T7, env-gated
> `sendMessage` → RPC swap, D-SM2)**, in effect when the apply executes.

> **§4 addendum (2026-08-08, billing-invoices read slice — plan
> `docs/billing_invoices_real_data_plan_2026-08-08.md`, ninth §14
> un-deferral):** a **new "View an invoice (metadata)" row is added** —
> the **client / attorney cells SHIP**, granted server-side by
> `invoices_select_assigned` (`supabase/policies/invoices.sql`) and
> policy-tested by `supabase/tests/11_invoice_rls.sql` (rehearsal r1
> **PASSED 2026-08-08**, evidence
> `docs/billing_invoices_rehearsal_evidence_r1_2026-08-08.md`, genuinely
> executed **78/0/0**; static battery `--check` 339/0/0). The grant is
> exactly: an **active member of the invoice's org** who is the assigned
> **client** or the assigned **attorney** on the invoice's matter —
> invoices are **matter-scoped content** (line 143/148), so the invoice
> gate IS the matter gate (the policy's exists subquery on `matters`, the
> documents D-DR2 pattern verbatim — D-BI2). Deny rows now each have a
> battery check:
> - **org role alone** (no matter assignment) → deny, every role;
> - **org-mismatch** (invoice org ≠ its matter's org) → deny, every role
>   — the load-bearing D-BI2 clause (an invoice is never readable when its
>   matter is not, line 143/148), NON-VACUOUS: the battery's 11.02 count
>   proves an assigned reader reads org-a invoices generally, so the 11.05
>   deny is specifically the clause;
> - **cross-org** (assigned on an org-a matter, org-b member only) → deny;
> - **suspended membership** in the invoice's org → deny (the
>   `is_active_member` arm);
> - **unauthenticated** → deny (no grant — `permission denied` at the
>   privilege layer);
> - **`platform_owner_admin`** → deny, always (owner accounts are never
>   assigned — an operational invariant, not a policy guarantee; recorded
>   residual in `docs/billing_invoices_gate_review_2026-08-08.md` Q4).
> The battery also pins the schema contract + teardown safety beyond the
> grant rows: the `amount_cents` CHECK rejects a negative amount and the
> `status` CHECK rejects an unmapped status (D-11's deliberately minimal
> mapping contract — `issued`/`paid` only, no tax/lifecycle machinery),
> and the matter-delete FK cascade removes a matter's invoices
> (11.10/11.11/11.12). **Not granted by this addendum:** the partner /
> `compliance_officer` "deny unless separately assigned" cells stay
> **ungranted** (the oversight mechanism is undefined, mirroring
> D-DR5/D-MR5); **no payment surface of any kind is granted** — D-11 "no
> live payment in MVP" (Paymob is a separate, future, owner-approved
> integration spec; the table is metadata-only by construction — D-BI1,
> no card/payment columns can even exist). **Basis:** §14 gate-lift (P0
> closure RATIFIED + policy battery shipped) · D-11 DECIDED 2026-08-08
> (`461cf51`) · r1 PASS (`da4fa97`, genuinely executed 78/0/0) ·
> apply-approval **APPLY APPROVED 2026-08-08** + execution
> (`docs/billing_invoices_apply_approval_2026-08-08.md` §6 dated sign-off
> + `docs/billing_invoices_apply_execution_2026-08-08.md` `fc7ed1b` —
> applied and verified on the dev project: tables/RLS 11→12, public
> policies 10→11, 4 demo invoices, smoke green). Per §7 this extends, not
> replaces, and widens no other row; **in effect since the apply execution
> 2026-08-08 (`fc7ed1b`)**, and the client surface (plan T7, env-gated
> `BillingGateway` swap) ships next.

> **§4 addendum (2026-08-09, F-01 step 2 matter-write slice — the FIRST
> matter-WRITE row; closes `docs/p4_findings_register_2026-08-09.md`
> F-01):** a **new "Create a matter" row is added** — the partner cell
> **SHIPS** (the `create_matter` RPC, `supabase/rpc/create_matter.sql`,
> `security definer` + `set search_path = public`; F2-D1 — the creator
> must be an **active partner of the org**, re-derived server-side via
> `has_org_role(org,'partner')` → `active_membership` `status='active'`,
> D-08: never trust the arg alone). All other cells stay **ungranted**
> (clients/attorneys/`compliance_officer` cannot create — the general
> matter-authoring policy stays undefined, D-MR5). **The F-01 core
> (F2-D2): the platform-owner id is NEVER assignable** — as assigned
> client or attorney, refused by the RPC **and** by the categorical
> `BEFORE INSERT OR UPDATE` trigger `refuse_platform_owner_assignment`
> (`supabase/migrations/11_matter_write.sql`, EXECUTE-revoked — fires for
> the connection role too, so **no path** — RPC, seeds, manual fixes — can
> create the Q4 residual state). The §5 content boundary
> (`platform_owner_admin` deny always on matter content) is now an
> **enforced clause for the write path**, not an invariant. **F2-D4:**
> assignees must be **active members of the org** (non-member / suspended
> refused — a dead assignment would be unreadable by the assignee).
> **F2-D5:** assignments **nullable at creation** — the orphan row,
> invisible to every role under RLS (the invoice-orphan 11 semantics).
> **§8:** every create is audited (`matter:create`/`allowed`, redacted
> summary `matter created` — never the title); a denied create writes
> nothing. **Deny rows, each battery-pinned:** anon (privilege-layer, no
> EXECUTE) · non-partner creator (generic `permission denied`) · cross-org
> (tenant isolation) · owner as assignee (deny always) · non-member /
> suspended assignee. **No UPDATE/DELETE surface beyond the trigger's
> owner-guard:** the trigger refuses owner **re-assignment** (the UPDATE
> arm, pinned 13.14/13.15); general matter editing stays future work
> (D-MR5). **Basis:** design (`docs/f01_step2_matter_write_design_2026-08-09.md`
> F2-D1…F2-D5) → build → rehearsal r1 **82/0/0 ×2** (`docs/matter_write_slice_rehearsal_r1_2026-08-09.md`)
> → mechanism/RLS-gate review PASS (`docs/matter_write_slice_review_2026-08-09.md`,
> R-1/R-2 remediated) → dated apply-approval (`docs/matter_write_apply_approval_2026-08-09.md`
> §6, **APPLY APPROVED 2026-08-09**) → apply execution (`docs/matter_write_apply_execution_2026-08-09.md`
> — dev project: **RPC-EXECUTE 19→20**, trigger live, demo create
> `d28f1f05-…` via the RPC with the §8 audit row observed, negatives +
> smoke green). Per §7 this extends, not replaces, and widens no other
> row; **in effect since the apply execution 2026-08-09**, and the client
> surface (env-gated `createMatter` swap) ships next. **Caveat recorded:
> F-12** — the pre-existing demo matter `a6715e17-…` carries the owner id
> as assigned client (seeded 2026-08-07, pre-F-01); contained (owner
> reads 0 — the `is_active_member` arm) with an owner-side data
> remediation tracked in the register.

> **§4 addendum (2026-08-11, notification-feed read slice — the first
> org-scoped metadata read surface, NOT matter content; ratified scope note
> `docs/notification_feed_scope_2026-08-11.md`, D-N1…D-N7 DECIDED
> 2026-08-11 — the new-surface authorization):** a **new "View
> notifications (metadata)" row is added** — the **client / attorney /
> partner / compliance_officer cells SHIP as any active member of the
> row's org** (the organizations-gate posture, no role hierarchy in the
> feed — T1 Q3), granted server-side by the **single SELECT policy
> `notifications_select_org`** (`supabase/policies/notifications.sql`)
> using the `is_active_member(organization_id)` gate — org metadata, NOT
> the matter-assignment exists-subquery (the feed is org-wide, T1 Q2) —
> and policy-tested by `supabase/tests/14_notification_rls.sql` (10 check
> blocks; rehearsal r1 **PASSED 2026-08-11, genuinely executed 86/0/0
> ×2**, evidence `docs/notification_feed_rehearsal_evidence_r1_2026-08-11.md`;
> static battery `--check` 78/0/0). **Redaction is structural (T1 Q1):**
> the table carries **no user-identity / content / raw-text column** (the
> D-BI1 mirror — PII *cannot* be stored, not merely shouldn't; the
> `summary` is synthetic-only by convention, D-N3). **Deny rows, each
> battery-pinned:**
> - **cross-org** (member of org-a only, reading org-b rows) → deny — org
>   scoping by count (14.04: org-a rows invisible to org-b members);
> - **`platform_owner_admin`** → deny, always (owner accounts hold no org
>   membership, so the `is_active_member` arm fails — D-P0C1(a)
>   deny-always posture, 14.05; an operational invariant, recorded
>   residual in `docs/notification_feed_gate_review_2026-08-11.md` Q4, the
>   11.08-style note);
> - **suspended membership** in the row's org → deny (the
>   `is_active_member` arm, 14.06);
> - **unauthenticated** → deny (no grant — `permission denied` at the
>   privilege layer, 14.07);
> - **no write cells in v1 (D-N2/D-N6)**: no INSERT/UPDATE/DELETE policy
>   and no write grant — the read-flag RPC is a future write slice; the
>   battery also pins the category-CHECK contract (D-N4 —
>   `appointment`/`activity`/`system`, 14.08), the org-delete cascade
>   (14.09), and the Q1 structural column-inventory pin (14.10).
> **Not granted by this addendum:** any write surface (delivery D-N2 /
> read-flag D-N6 stay future slices); **no new RPC** (direct PostgREST
> read, T1 Q5); **no publication change** (the feed is not realtime —
> `public.messages` remains the only publication); no prefs filtering
> (D-N5). **Basis:** scope DECIDED 2026-08-11 (D-N1…D-N7, `1027f68`) ·
> T1 mechanism/RLS-gate review PASS (`docs/notification_feed_gate_review_2026-08-11.md`
> `b9f2b08`) · r1 PASS 86/0/0 ×2 · apply-approval + execution
> (`docs/notification_feed_apply_approval_2026-08-11.md` §6, **APPLY
> APPROVED 2026-08-11** signed in-session, + `docs/notification_feed_apply_execution_2026-08-11.md`
> — dev project: tables/RLS 12→13, public policies 11→12, live positive
> (member reads the org feed — empty pre-producer, D-N7) + anon denied at
> the privilege layer, smoke green). Per §7 this extends, not replaces,
> and widens no other row; **in effect since the apply execution
> 2026-08-11**, and the client surface (T8, env-gated `NotificationGateway`
> swap + feed screen + home-shell entry) ships next.

> **§4 addendum (2026-08-11, notification producer slice — server
> mechanism, NOT a grant; D-P5, "trigger is not a policy"):** the
> notification-feed row **stays exactly as written above** — the member
> SHIP read-only cells are unchanged. The producer is a **data-layer
> mechanism**: the audit-mirror trigger
> `mirror_audit_to_notifications` (`supabase/migrations/15_notification_producer.sql`,
> `AFTER INSERT` on `audit_events`, security definer + `set search_path =
> public`, D-P1) maps `matter:create` / `message:create` +
> `outcome='allowed'` audit rows into org-scoped `notifications` rows with
> **fixed redacted summaries** (D-P3 — never the matter title / message
> body; structural redaction, the D-N3 mirror). It **grants nothing and
> revokes nothing beyond its own EXECUTE** (D-P4 — trigger-invoked only,
> the write_audit precedent: `has_function_privilege('authenticated',
> 'mirror_audit_to_notifications()', 'EXECUTE')` = false), adds **no
> policy** (applied counts stay 13/13/12, RPC-EXECUTE stays 20), and **no
> client path can invoke it** — the read-only posture is unchanged at
> every layer. **Battery pins:** the re-pinned battery 14 (6/6/1 — battery
> 10's two committed sends produce exactly 2 org-a producer rows, D-P6,
> `supabase/tests/14_notification_rls.sql`) + the new battery 15 (14
> check blocks — the map delta + in-txn atomicity + gate visibility +
> fixed-summary redaction + the outcome/action/NULL-org filter negatives +
> EXECUTE-deny, `supabase/tests/15_notification_producer_rls.sql`).
> **Basis:** plan RATIFIED 2026-08-11 (D-P1…D-P6, `cdd7ab4`) · T1
> mechanism/RLS-gate review PASS (`docs/notification_feed_producer_gate_review_2026-08-11.md`,
> `0f95125`) · r1 PASS **88/0/0 ×2** (`docs/notification_feed_producer_rehearsal_r1_2026-08-11.md`)
> · apply-approval + execution (`docs/notification_feed_producer_apply_approval_2026-08-11.md`
> §6, **APPLY APPROVED 2026-08-11** signed in-session, +
> `docs/notification_feed_producer_apply_execution_2026-08-11.md` — dev
> project: function + trigger live, EXECUTE denied to both client roles,
> counts unchanged 13/13/12/20 RPC, in-txn live positive (partner
> `create_matter` → produced org feed row visible via RLS → `ROLLBACK`,
> zero residue) + anon denied, smoke green). Per §7 this extends, not
> replaces, and widens no other row; **in effect since the apply
> execution 2026-08-11** — the feed now fills with real event traffic
> (the T8 non-vacuous re-verification runs next).

> **§4 addendum (2026-09-02, notification read-flag write slice — the
> D-N6 write half):** the "View notifications (metadata)" row gains the
> **member SHIP write cell**: `mark_notifications_read` (plan
> `docs/notification_read_flag_slice_plan_2026-09-02.md`, D-F1…D-F7,
> owner-approved 2026-09-02) — a **single audited write RPC**
> (`supabase/migrations/16_notification_read_flag.sql`, security definer +
> `set search_path = public`, the send_message D-SM1 posture): the
> in-function `is_active_member` gate is the **sole write authorization**
> (definer bypasses RLS — no UPDATE grant, **no new policy**, applied
> counts stay **13 tables / 13 RLS / 12 public policies**; the RPC-EXECUTE
> pin moves **20 → 21**: revoked from `public`/`anon`, granted to
> `authenticated`). The RPC flips only the caller's **own-org,
> still-unread** rows (foreign-org ids silently untouched, D-F1),
> is **idempotent** (D-F4), and §8-audits **one redacted
> `notification:mark_read` row per distinct org touched** (D-F2 — summary
> `notification read state updated`, never ids; the action is OUTSIDE the
> producer's D-P2 map, so a mark never re-produces a feed row).
> **Battery pins:** `supabase/tests/16_notification_read_flag.sql` (the
> no-client-write-grant structural pin + the EXECUTE shape + member
> positive/count/audit + cross-org + non-member/suspended + anon denial).
> **Basis:** plan RATIFIED 2026-09-02 (owner approval, this session) ·
> rehearsal + apply on the dev project recorded by the slice's apply
> record. Per §7 this extends, not replaces, and widens no other row; the
> write is the ONLY notifications mutation surface.

---

## 5. `platform_owner_admin` — explicit boundary (contract §2 #2, #4)

This role exists to let the Project Owner administer synthetic/demo data for
the portfolio project. Its boundary is intentionally narrow and is repeated
here as a standalone checklist because it is the highest-risk row in this
matrix (a single powerful account):

- ✅ May: list orgs, list members + their identity/membership metadata
  (display name, role, status, timestamps — **no email**; the owner
  `list_members_metadata` RPC returns identity + membership metadata
  only), suspend/reactivate a membership, delete a demo account.
- ❌ May never: read matter/document/message content, impersonate another
  user's session, edit or delete an audit record, act on any table other
  than identity/membership metadata.
- Every action produces an audit record (contract §8) with the
  `platform_owner_admin` actor reference — **it is not exempt from
  auditing just because it's the owner's own account.**
- Enforced server-side only (RLS/RPC); a client-side "isOwner" flag is a UX
  affordance, never the authorization boundary. **The platform-admin screen
  SHIPPED 2026-08-05** (P3.5, `47f777b`) behind the enforcement contract
  recorded in the §5 addendum below — the policy-test battery (D-P0C2), the
  single-owner binding (D-P0C3), and audit-RPC-only surfacing (D-P0C4); the
  owner capability stays server-gated (`is_platform_owner()`), so the
  earlier deferral of these five owner RPCs in the planning roadmap §14 no
  longer applies (roadmap §2 reconciled 2026-08-07).

**Negative test required:** an authenticated session bearing the
`platform_owner_admin` capability but attempting to read a document/message
row must be denied by policy, identically to any other unauthorized role —
this is the row's own worst-case test and must exist before P2 ships.

> **§5 addendum (2026-08-05, P0-closure scope note
> `docs/p0_closure_scope_2026-08-05.md` — RATIFIED 2026-08-05):**
> records the test contract for the §5 deny-row and the
> per-row negative blocks, and pins the forward content-table boundary. (a)
> The §5 "negative test required" row is satisfied by a committed policy-test
> battery (`supabase/tests/` + `scripts/verify_policy_tests.sh`, D-P0C2) run
> against an ephemeral rehearsal project, proving the owner cannot exceed
> identity/membership metadata through any existing grant or RPC path. (b)
> Because no matter/document/message tables exist, the §4 "❌ deny, always"
> content rows are enforced as a **forward design pin**: every future content
> table ships with an explicit `platform_owner_admin → deny` RLS row and its
> own negative test, enforced at schema-review time (D-P0C1). (c) The owner
> capability stays bound to exactly one account (D-P0C3): the battery includes
> a negative test that a second `platform_config` owner row cannot be created
> through any reachable path. (d) Audit surfacing stays RPC-only (D-P0C4):
> `read_org_audit`/`read_platform_audit` self-audit; no raw `SELECT` on
> `audit_events` is ever granted. This addendum widens no permission row — it
> records the test contract and the forward boundary; the §7 dated-addendum
> discipline is satisfied by this block.

---

## 6. Storage / realtime / audit (contract §9 storage block)

| Scenario | Expected result |
|---|---|
| Download a private object via a guessed path | Denied |
| Reuse a stale signed URL after membership removal | Denied |
| Realtime subscription for an org/matter the session no longer has access to | No events delivered |
| Membership or sensitive-access change | Produces an attributable, redacted audit record (no credentials/content) |
| Read the audit table | Scope-checked per reader's role; audit table is never publicly readable, and `platform_owner_admin` reading it is itself an audited action |

> **§6 addendum (2026-08-08, real-storage read slice — plan
> `docs/storage_real_data_plan_2026-08-08.md`, fourth §14 un-deferral):**
> the first two rows of this block are **enforced by the committed
> policies + battery (effective on the apply execution — pending)** — the
> P2 r4 Q4 deferral's "zero buckets" posture is superseded by this slice,
> not deferred recordings:
> - **"Download a private object via a guessed path → Denied"** is
>   enforced by `files_storage_select` on `storage.objects` (the
>   path-org/matter gate; a guessed/mismatched path denies for every role
>   — battery 07.12, non-vacuous) **and** by `files_select_assigned` on
>   the metadata table — the storage rows now have positive + negative
>   tests (contract §9).
> - **"Reuse a stale signed URL after membership removal → Denied"** is
>   enforced **at generation**: the storage API's signed-URL creation is
>   itself RLS-gated (a removed member cannot mint one), and issued URLs
>   are TTL-bound — **recorded honestly as such, not as instant
>   mid-flight revocation** (an already-issued signed URL stays valid
>   until its TTL expires; the mechanism is documented in
>   `docs/storage_rls_gate_review_2026-08-08.md` D-STR4/§4 — recorded
>   there as a future-facing negative (the P2 r4 Q4-deferral convention),
>   not asserted as a battery check row).
> The remaining §6 rows (realtime delivery, audit) are unchanged. Per §7
> this extends, not replaces, and widens no other row; in effect on the
> apply execution (pending — r1 evidence ⏳, apply ⏳ HELD, approval ✅>   APPLY APPROVED 2026-08-08 `91c49ce`).

> **§6 addendum (2026-08-08, audit-surfacing slice — plan
> `docs/audit_surfacing_plan_2026-08-08.md`, fifth §14 un-deferral):**
> the **"Read the audit table"** row gains its first **client surface**,
> behind the two audit RPCs — both **REVIEWED & APPLIED to the dev project
> 2026-08-01** (backout `rpc/_down.sql`) and both **pinned in the harness
> battery's §1d RPC-EXECUTE list** (`read_org_audit(uuid)`,
> `read_platform_audit()`):
> - **`read_platform_audit()`** — `platform_owner_admin`-only cross-org
>   audit read; the platform-admin screen's Platform audit list.
> - **`read_org_audit(org_id)`** — org-scoped audit read; the per-org audit
>   list for the selected org (the RPC is partner-capable server-side, but
>   the first surface is owner-only on the platform-admin screen — a
>   partner-facing org-audit UI is a recorded follow-up).
> Both render **redacted metadata only** (the RPCs return `redacted_summary`
> + `correlation_id`; no credentials/content — contract §8), and **D-P0C4
> holds: no raw `SELECT` on `audit_events` is ever granted** — the RPCs are
> the only auditable read path (a raw SELECT policy cannot audit a read),
> and `platform_owner_admin` reading the audit is itself an audited action
> (owner is not audit-exempt). A **non-owner reader is denied** (the
> server-side owner-only deny maps to the platform-admin screen's distinct
> denied state — P3.5 AC-7, never empty-success). The remaining §6 row
> (realtime delivery) is unchanged. Per §7 this extends, not replaces, and
> widens no other row; in effect on the client surface ship (T2–T5 of
> `docs/audit_surfacing_plan_2026-08-08.md`).

> **§6 addendum (2026-08-08, realtime push slice — plan
> `docs/realtime_push_real_data_plan_2026-08-08.md`, seventh §14
> un-deferral):** the **"Realtime subscription for an org/matter the
> session no longer has access to → No events delivered"** row is now
> **enforced**, resolving the realtime-read addendum's D-RT6 caution
> ("postgres_changes is a different authorization surface") with the
> verified mechanism: Supabase **Realtime RLS** makes `postgres_changes`
> adhere to the underlying table's SELECT policies, so the **existing
> `messages_select_assigned` policy IS the delivery gate** (D-LV3) —
> publication membership is the *enablement*, table RLS is the
> *authorization*, and both are pinned:
> - **Publication (enablement):** exactly the `messages` table in
>   `supabase_realtime` (D-LV2) — pinned by the harness forward pin
>   (`pg_publication_tables` for messages = **1** + exactly-one-publication-
>   row) and the battery 09.01/09.02; adding any other table trips the pin
>   loudly (D-P0C1(b) teeth — no accidental table exposure via realtime).
>   Verified live on the dev project (`7efb32b`): `pg_publication_tables` =
>   exactly `public.messages`.
> - **Delivery (authorization):** the role-impersonated delivery-equivalence
>   checks (09.11/09.12) prove the read gate = the delivery gate: the
>   assigned reader sees the delivered row; the **suspended / cross-org /
>   owner readers see 0** — a subscription for an org/matter the session no
>   longer has access to delivers nothing. **Honest limit recorded:** the
>   battery proves the RLS proxy for live delivery; the real websocket
>   round-trip is the env-gated client slice (T7, D-LV4), never claimed by
>   the battery.
> The remaining §6 rows (storage, audit) are unchanged. Per §7 this
> extends, not replaces, and widens no other row; in effect on the apply
> execution 2026-08-08 (`7efb32b`).

> **§6 addendum (2026-08-09, partner org-audit read surface — the recorded
> follow-up consummated; scope note
> `docs/partner_org_audit_scope_2026-08-09.md`):** the **"Read the audit
> table" row's partner cell gains its first in-product surface** — the same
> remote record of the audit-surfacing addendum ("a partner-facing org-audit
> UI is a recorded follow-up") ships: partner-scoped, read-only, org-scoped
> to the active-org context (D-08, server re-derives membership), rendering
> **server-redacted fields only** (action/outcome/`redacted_summary`/
> timestamp; never content or credentials — contract §8) with no export
> affordance (D-AUD1), and a **distinct denied state for non-partners —
> never empty-success** (P3.5 AC-7, server `permission denied` maps to a
> typed denial). The only server surface consumed is `read_org_audit`, which
> is **already applied (2026-08-01) and partner-capable** — **no server
> change, no new RPC, no grant**: this addendum only records the client-side
> consummation (`OrganizationGateway.readOrgAudit` + `OrgAuditCubit` +
> `/organizations/audit` surface + `canViewAudit` partner-hint + l10n ×3 +
> env-gated `SupabaseOrgApi.readOrgAudit` RPC call). Per §7 this extends,
> not replaces, and widens no other row; the enforcement remains the applied
> in-RPC gate (a non-partner is denied server-side); raw SELECT on
> `audit_events` stays ungranted (D-P0C4 holds).

---
## 7. Sign-off

| Role | Name | Date |
|---|---|---|
| Product / Project Owner | github.com/mostafasayed118 | 2026-07-31 |

This matrix satisfies the "signed permission matrix... positive and negative
cases" precondition in `p0_decision_capture.md` §2. It must be extended (not
replaced) as new MVP actions are approved — do not silently widen an
existing row without a dated addendum, per the same discipline used in
`gate3_reconciliation.md`. Planned extensions and their sequencing live in
the planning roadmap (`docs/features_roadmap_2026-08-03.md`).
