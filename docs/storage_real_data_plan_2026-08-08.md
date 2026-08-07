# Plan: Real Storage (Read) Data Path — the fourth §14 un-deferral (2026-08-08)

> **Record type:** SPEC_KIT Template 2 (PLAN) + Template 3 (TASKS) for the
> fourth slice under the roadmap §14 blanket-deferral, mirroring the
> **matters**, **documents** and **messages** read slices (plans
> `docs/matters_real_data_plan_2026-08-07.md`,
> `docs/documents_real_data_plan_2026-08-07.md` and
> `docs/messages_real_data_plan_2026-08-07.md`, all SHIPPED 2026-08-07) —
> the same per-feature discipline, applied to **matter file storage**
> (metadata + byte-level read). **Docs-only planning — zero dev-project
> effect**: nothing in this document or its TASKS applies anything to the
> dev Supabase project; every external step stays behind the owner's dated
> approval (INSTRUCTIONS.md §2.1/§5 hard gates).
>
> **Gate state (why this slice is now plannable):** the §14 precondition is
> **met at the decision level and proven by precedent three times** — P0
> closure RATIFIED (`docs/p0_closure_scope_2026-08-05.md`, D-P0C1…D-P0C5),
> the policy battery ships (`scripts/verify_policy_tests.sh`), and the
> matters, documents **and** messages slices each ran the full chain green
> (rehearsal r1 PASSED → signed apply → matrix addendum → env-gated client
> swap). The `matters` table is **applied on the dev project** and is this
> slice's FK target + assignment source of truth; the `documents` +
> `message_threads` tables are applied (metadata-only rows). **The storage
> slice is the first whose byte-level surface is the native Supabase
> Storage layer** (`storage.buckets` + `storage.objects` RLS policies),
> which exists on the dev project and on any `supabase start` rehearsal
> host — the Q4 deferral from the P2 design (`docs/p2_schema_rls_design.md`
> §8 Q4: "zero buckets") is consummated here.
>
> **Owner:** Project Owner (github.com/mostafasayed118).

---

## 1. Goal

Move the **matter file read path** from "nothing exists" to a real,
org-scoped, **matter-scoped** storage surface with RLS — **without
changing any shipped VO or presentation** (there is none yet for storage:
this slice is the first to build a storage client surface, see D-STR7).
"Done" = an active member reads exactly the **file metadata** (via a
`public.files` metadata table through PostgREST) **and the file objects
themselves** (via `storage.objects` RLS on a private `matter-files`
bucket) for the matters they are assigned to (client or attorney); every
other read — org-role-alone, cross-org, unassigned, guessed-path,
unauthenticated, `platform_owner_admin` — is denied and policy-tested; the
env-less demo and the whole test suite still run on a new dev fake.
**Metadata + bytes readable; no upload/write path, no download affordance
in the client slice** (the storage.objects policy + battery prove the
byte gate server-side; a download button/UX is a flagged follow-up,
D-STR9). The matrix's §6 storage rows ("Download a private object via a
guessed path → Denied", "Reuse a stale signed URL after membership removal
→ Denied") move from deferred-recording to enforced-by-policy + battery.

## 2. Gap (verified)

- **No client storage surface exists at all.** Unlike matters/documents/
  messages (which had Phase 7/8/9 client-only fakes to swap), the storage
  capability shipped **no** VO, gateway, fake or screen — Phase 8
  (`document_vault_scope_2026-08-03.md` D-V1) is metadata-only with "no
  storage or realtime", and every gateway seam's doc comment repeats "the
  real data path (table, RLS, storage, realtime) stays deferred". The
  roadmap has **no storage phase** (phases stop at 12); the deferred list
  after the third un-deferral is **storage, realtime, audit surfacing,
  billing, AI**.
- The **permission matrix §6** is the storage contract: "Download a
  private object via a guessed path → **Denied**" and "Reuse a stale
  signed URL after membership removal → **Denied**". The P2 rehearsal
  recorded these as **future-facing negatives, not executed** ("zero
  buckets expected" — `docs/p2_rehearsal_evidence_r4_2026-08-01.md`).
  Storage files are also **matter content** per matrix §4 (line 143/148):
  an org role without an explicit matter assignment never reads a
  restricted matter **or its documents/messages/files**; `platform_owner_admin`
  deny, always.
- The **harness forward pin** currently asserts `('messages','files')`
  absent (0 public tables) — this slice ships a public `files` metadata
  table (the pin's own name) **and** the native storage layer, so the pin
  narrows to `('messages')` (individual message rows/bodies stay deferred).
- The **applied `matters` table** (with `assigned_client_id` /
  `assigned_attorney_id`) is the assignment source of truth; `documents`
  and `message_threads` are applied metadata-only tables the files table
  mirrors exactly.
- The battery fixture set already seeds six matters with every assignment
  branch + six documents + six threads; the storage battery reuses the six
  matters — no new identity fixtures needed, only file/object rows.

## 3. Design decisions (D-STR1…D-STR9 — ratified by autonomy 2026-08-08, recommended path per the pair-programming grant; the RLS-gate review `docs/storage_rls_gate_review_2026-08-08.md` answers Q1–Q6 on these)

| # | Decision | Recommendation | Why / alternative |
|---|---|---|---|
| D-STR1 | **Read scope, slice 4** | **Matter-scoped file metadata + byte read**: a `public.files` metadata row is readable iff the reader is an active member of the file's org **AND** assigned (client or attorney) on the file's `matter_id` (matrix §4 line 143/148 — files are matter content); the **byte-level read is granted by a `storage.objects` SELECT policy on a private `matter-files` bucket**, path-scoped to the same assignment gate (matrix §6). **No upload/write path, no download affordance in this slice** — the storage.objects policy + battery prove the byte gate server-side; the client ships a metadata-only list (D-V1 discipline) | Partner/owner "deny unless separately assigned" cells need a defined oversight mechanism (mirror D-MR5/D-DR5/D-MSR5); a download/upload UX is a future reviewed slice (D-STR9) |
| D-STR2 | **Read mechanism** | **Two-layer, both via RLS — no SECURITY DEFINER RPC.** (a) **Metadata:** `public.files` + `files_select_assigned` SELECT policy via PostgREST (`supabase.from('files').select()`), the documents/messages exists-subquery pattern verbatim — `m.id = files.matter_id AND m.organization_id = files.organization_id AND (m.assigned_client_id = auth.uid() OR m.assigned_attorney_id = auth.uid())` with the **org-mismatch clause load-bearing**. (b) **Bytes:** `files_storage_select` on `storage.objects` for `bucket_id = 'matter-files'`, where the object **path encodes `{org_id}/{matter_id}/{filename}`** and the policy matches the path segments against `matters` via `storage.foldername(name)` — `public.is_active_member((storage.foldername(name))[1]::uuid) AND m.id::text = (storage.foldername(name))[2] AND m.organization_id::text = (storage.foldername(name))[1] AND (m.assigned_client_id = auth.uid() OR m.assigned_attorney_id = auth.uid())`. **The active-membership arm is load-bearing on the objects layer too** (symmetric with `files_select_assigned`): a suspended-but-still-assigned user must be denied on storage.objects exactly as on public.files — the fixture matter 6 (assigned attorney = `suspended-a`) pins it. The **path-org segment must equal the matter's authoritative org** — the org-mismatch invariant, path-encoded (a guessed/mismatched path denies). Path segments are compared as **canonical lowercase hyphenated uuid::text** — pinned in the T1 review so T2's artifact and T3's battery cannot drift on formatting | Row-scoped reads are RLS's job; `is_active_member` already R-4 granted; the native storage layer is the only way to gate object bytes — a public table alone cannot |
| D-STR3 | **Column shape (metadata)** | `public.files`: `id uuid pk default gen_random_uuid()`, `organization_id uuid not null fk organizations on delete cascade`, `matter_id uuid not null fk matters on delete cascade`, `name text not null` (never PII by convention), `mime_type text not null default 'application/octet-stream'`, `size_bytes bigint not null default 0 check (size_bytes >= 0)`, `storage_path text not null` (the single source of truth linking the row to its object — `{org_id}/{matter_id}/{filename}`), `created_at`/`updated_at`. **No content/body/url column** — bytes live only in `storage.objects`, never in the table (D-V1 line holds) | The metadata table mirrors documents/message_threads exactly (the client VO needs size/mime/path); the bytes live in the platform storage layer |
| D-STR4 | **Bucket + object scoping** | A private `matter-files` bucket (`public = false`) created by the migration (`insert into storage.buckets ... on conflict do nothing` — idempotent for the harness `--apply` loop). Objects are stored at `{org_id}/{matter_id}/{filename}`; the storage.objects policy derives the gate from the path (D-STR2). Client byte reads use `storage.from('matter-files').download(storage_path)` — **authenticated and RLS-scoped**; signed URLs are TTL-bound and their **generation is itself RLS-gated** (a removed member cannot mint one), so the matrix §6 "stale signed URL" row is enforced by policy-at-generation + TTL expiry — **recorded with the residual caveat, not over-claimed** | The bucket + path model is the canonical Supabase storage pattern; no new primitives |
| D-STR5 | **matterRef resolution** | Rows store `matter_id` (ids only); the client `FileMetadata.matterRef` (title-keyed, D-W2) resolves via the **embedded `matters(title)` select** (documents D-DR4 pattern) with raw-id fallback (honest — never a fabricated title) | One round-trip, RLS-safe, no new surface |
| D-STR6 | **Partner/owner oversight** | **Not in slice 4** — the "deny unless separately assigned" mechanism is undefined; RLS stays purely assignment-based (mirror D-MR5/D-DR5/D-MSR5); `platform_owner_admin` deny always (Q4 residual: owner accounts are never assigned, so the gate denies them; a future oversight row would also propagate to matters/documents/messages/files via the shared exists gate) | Matrix cells stay ungranted; a future D-DR defines the oversight row |
| D-STR7 | **Client swap (NEW surface — first slice with no Phase 7–12 fake)** | No `StorageGateway`/`FileMetadata`/`FakeStorageGateway` exists — this slice **builds** the minimal consumer-attached surface (never a shelved headless layer, per the booking-layer lesson): `lib/features/storage/domain/file_metadata.dart` + `storage_gateway.dart` + `data/fake_storage_gateway.dart` (deterministic synthetic non-PII rows, Phase 8 fake pattern), env-gated `lib/data/storage/supabase_storage_api.dart` + impl + `supabase_storage_gateway.dart` behind `env.isConfigured` (service_locator flip, documents/messages pattern), a **read-only `matter_files_section`** on the matter details screen (mirroring the shipped `matter_documents_section.dart`/`matter_messages_section.dart`), l10n ×3, DI pins. **Metadata-only — no download affordance** (D-STR9 follow-up) | Env-less runs and ALL tests keep the fake; the real path is inert until a configured build + applied schema exist; the section is the consumer that proves the seam |
| D-STR8 | **Seeding + residue** | Demo file rows **+ demo storage objects** referencing the **applied demo matter ids** (dev project's own ids resolved at apply time, org = matter's org, paths `{org}/{matter}/{demo-name}`) are part of the **apply step** (owner-approved), paired with the rollback (`07_storage.down.sql` drops files + bucket; policy git-revert; object cleanup) and cleanup discipline | No seed at commit time; no real client PII anywhere |
| D-STR9 | **Non-decisions (flagged, not guessed)** | Byte **download affordance** + signed-URL UX + **upload/write path** (a future reviewed slice — the storage.objects gate is proven by the battery now); realtime; audit surfacing; billing; AI; the "stale signed URL" row's TTL caveat (D-STR4) | Kept out of scope so the read-metadata slice stays additive and honest |

**Non-decisions (flagged, not guessed):** file **uploads/writes** (no
INSERT/UPDATE/DELETE grant, no write RPC — a future reviewed slice with
its own matrix addendum); a **download button/signed-URL UX** (the bytes
are RLS-gated and battery-proven server-side; the client interaction is a
follow-up); realtime file events; audit surfacing for storage reads (stays
§14/P2-gated); billing/AI rows (unchanged).

## 4. Layers touched

- **Server (rehearsal → apply, gated):** `supabase/migrations/07_storage.sql`
  (+ `07_storage.down.sql` — creates the `matter-files` bucket and the
  `public.files` table; **nothing applied at commit time**),
  `supabase/policies/files.sql` (`files_select_assigned` on public.files) +
  `supabase/policies/storage_objects.sql` (`files_storage_select` on
  storage.objects), `supabase/tests/07_storage_rls.sql`,
  `scripts/verify_policy_tests.sh` (battery list + run loop + UUID/FAIL
  scans gain the new battery; `--apply` order gains `07_storage.sql`;
  structural pins re-scoped **9→10 public tables / 8→9 public policies** +
  **new storage pins** (bucket present, storage.objects policy present);
  forward pin narrowed to `('messages')`). The `storage` schema is a
  **platform prerequisite** (exists on the dev project and any `supabase
  start` rehearsal host — the P2 Q4 deferral's "zero buckets" is
  consummated).
- **Client (env-gated, NEW surface — D-STR7):** `lib/features/storage/`
  (VO + gateway + fake + `matter_files_section`), `lib/data/storage/`
  (supabase api + impl + gateway), `lib/app/service_locator.dart` (flip),
  3 `.arb` + generated l10n. No shipped VO/presentation changes — there is
  nothing to change; the new surface mirrors the Phase 8 pattern.
- **Docs:** dated matrix §4 addendum (new "View a matter file (metadata)"
  row) + §6 addendum (the two storage rows move to enforced, with the
  signed-URL caveat recorded), roadmap §14 fourth per-feature flip,
  README lockstep, completion evidence.

## 5. State shape / data flow

- **State shape:** new `StorageCubit`/`StorageState` (or a section-local
  state mirroring `matter_documents_section`'s wiring) reading
  `StorageGateway.fetchFiles()`; the fake is the env-less/test
  implementation. No shipped cubit/state changes elsewhere.
- **Data flow (configured build):**
  `matter details → matter_files_section → StorageGateway (Supabase impl) →
  PostgREST from('files').select('id, matter_id, name, mime_type,
  size_bytes, storage_path, matters(title)') (RLS-scoped, D-STR1/D-STR2)
  → row → FileMetadata VO (matterRef from the embedded title, fallback
  id)`. One embed hop, the documents pattern — no new surface. The
  byte-level read (`storage.from('matter-files').download(storage_path)`,
  D-STR4) is a follow-up slice; the policy is proven by the battery.

## 6. Dependencies

- **Server:** the **applied `matters` table** (D-STR2's exists subqueries +
  D-STR3's FK) and the **platform storage layer** (`storage.buckets` /
  `storage.objects` — present on the dev project and the rehearsal host).
  Additive on the three shipped slices; no new primitives beyond stock
  Postgres/PostgREST/Storage.
- **Client:** none new — `supabase_flutter` is already the only backend
  SDK (its storage client is the byte-path seam, used by the follow-up
  slice; this slice's metadata read uses the same PostgREST client the
  documents/messages layers use), confined to `lib/data/`.
- **Infra (rehearsal/apply):** Postgres **with the storage schema** to run
  the battery — the **established host is the owner's Docker machine**
  (`supabase start` — matters/documents/messages r1 Path A precedent), so
  the rehearsal is owner-side but no longer an unknown.

## 7. Testing strategy

- **SQL battery** (`07_storage_rls.sql`, via `verify_policy_tests.sh`):
  positives on **both layers** — assigned client sees the files **and**
  the objects of its matters (client-a → 2, partner-a → 3, orphan → 1;
  the documents 2/3/1 count shape, proving no blanket-org bleed); denies on
  both layers: org-role-alone · **org-mismatch (non-vacuous — a file row /
  object path whose org ≠ its matter's org denies for every role)** ·
  cross-org · suspended · unauthenticated · `platform_owner_admin` denied
  always; **the matrix §6 guessed-path row**: an object under a path with
  an unknown/foreign matter id is denied for every role; `size_bytes`
  CHECK rejects a negative value; matter-delete cascade removes its files
  rows; the storage.objects teardown deletes the temp objects (no matters
  FK — cleaned by the battery, pinned).
- **Dart unit:** `SupabaseStorageGateway` row→VO mapping (size_bytes/mime/
  storage_path guarded casts, matterRef embed + fallback, failure mapping
  incl. `providerUnavailable`, malformed-row guards — the documents T7
  baseline: no raw `TypeError`s across the boundary); `FakeStorageGateway`
  determinism + non-PII.
- **DI pins:** `service_locator_test` — env-less → `FakeStorageGateway`,
  configured → `SupabaseStorageGateway`.
- **Widget/cubit:** the new `matter_files_section` renders fake rows
  env-less (metadata-only line pin: no download affordance); the existing
  matter-details suite is the regression net proving the section is
  additive.
- **Not claimed:** no live dev-project read until the apply step; the
  battery + rehearsal evidence are the standing server claims; the
  download interaction is explicitly NOT built (D-STR9).

## 8. Acceptance criteria

- [ ] A file's **metadata** is readable iff the reader is an active member
      of its org **and** assigned (client or attorney) on its matter (RLS
      + battery, matrix §4 line 143/148).
- [ ] A file's **bytes** are readable (storage.objects SELECT) iff the
      same gate holds, scoped by the object path's org + matter segments —
      a **guessed path is denied** for every role (matrix §6 row 1).
- [ ] Org-role-alone, cross-org, unassigned, org-mismatch, unauthenticated,
      and `platform_owner_admin` reads are denied on **both layers**
      (battery, 03-style deny rows; the owner row holds as the operational
      invariant — never assigned).
- [ ] Battery green via `verify_policy_tests.sh` (static `--check` first,
      then the live battery); rehearsal r-series passed with evidence
      before any apply (owner's Docker host, `supabase start` — the
      storage-schema prerequisite).
- [ ] Apply executed only under the owner's dated apply-approval, with
      `07_storage.down.sql` + policy git-revert rollback pairing and
      demo-row/object cleanup discipline (demo rows + objects reference
      the **applied** demo matter ids, resolved at apply time).
- [ ] Client surface is **new but consumer-attached** (D-STR7): env-gated
      swap; env-less runs and the full Flutter suite unchanged (fake);
      metadata-only, no download affordance.
- [ ] Dated matrix §4 + §6 addendum (§7 discipline) precedes the client
      surface shipping; roadmap §14 gains the fourth per-feature flip;
      README count in lockstep; ledger PASS.
- [ ] Full gate on every client slice: format clean · analyze clean ·
      suite green · ledger PASS — nothing pushed.

## 9. Risks / open questions

- **Storage-schema dependency (D-STR4):** the migration + battery touch
  `storage.buckets`/`storage.objects`, which exist only on Supabase hosts
  (dev project + `supabase start`), not a bare Postgres. The rehearsal
  host is the owner's Docker machine (r1 Path A precedent) — recorded, not
  guessed; the static `--check` mode is DB-free.
- **Signed-URL semantics (D-STR4/matrix §6 row 2):** an already-issued
  signed URL is TTL-bound and not revoked mid-flight by a membership
  change; the **generation** of new URLs is RLS-gated (a removed member
  cannot mint one). Recorded as the honest mechanism + a future-facing
  caveat in the battery (RECORDED row, the P2 r4 Q4-deferral convention) —
  never over-claimed as instant revocation.
- **Policy/matters coupling (D-STR2):** both policies' exists subqueries
  inherit any future change to `matters` (e.g. a partner oversight row
  would also open files on those matters). Recorded as **intended** —
  files should track matter access — and pinned by the battery.
- **Path-scoping invariant (D-STR2):** the object path's org segment must
  equal the matter's authoritative org; a mismatched path denies (the
  org-mismatch battery row, non-vacuous). A future write slice must keep
  path construction consistent.
- **New client surface (D-STR7):** the first slice that builds (not
  swaps) the client layer — scoped to the minimal consumer-attached
  metadata section to avoid a shelved headless layer; the download/upload
  UX is a separate reviewed slice.
- **Infra:** rehearsal/apply are owner-side (matters/documents/messages r1
  Path A precedent) — no psql/Docker on this machine; the first battery
  execution is T3/T4 on the owner's host or CI.
- **Scope:** slice 4 swaps in the storage **read** path; realtime, audit
  surfacing, billing, AI, and the file **write** path each stay deferred.

---

# Tasks: Real Storage (Read) Data Path

Branch: `feat/storage-real-read`

Each task is independently committable with the stated verification; the
apply gate (T5) is the only owner-gated step. T2–T4 are server artifacts —
**no dev-project change until T5**.

- [x] **1. Scope note + RLS-gate design addendum** — touches: this document
  + a `storage` §8-style review (`docs/storage_rls_gate_review_2026-08-08.md`,
  the Q1–Q6 pattern answered for storage: the two-layer mechanism (metadata
  table + storage.objects path policy, D-STR2), the bucket/object scoping
  (D-STR4), the guessed-path + signed-URL negatives (matrix §6), negative
  cases, rollback pairing, seed plan) — done when: docs committed, ledger
  sweep green (no dev-project contact). — **DONE `6f52930`** (the review
  doc on `feat/storage-real-read`; the plan itself was drafted + D-STR
  ratified on `main` `cc33da3`/`bad9641`).
- [x] **2. Schema artifacts (rehearsal-ready, NOT applied)** — touches:
  `supabase/migrations/07_storage.sql` (+ `07_storage.down.sql`),
  `supabase/policies/files.sql` + `supabase/policies/storage_objects.sql`
  — done when: DDL matches D-STR1/D-STR3/D-STR4 (private `matter-files`
  bucket via idempotent insert — **bucket column list verified against the
  dev project's storage schema, `owner` omitted if absent**; `public.files`
  with matter FK + org column
  + `size_bytes` CHECK + `storage_path`, metadata only, no content
  column; `files_select_assigned` + `files_storage_select` policies),
  `_down.sql` is a clean inverse (drop files + bucket), committed.
  — **DONE `87b6ef5`** (bucket insert `(id, name, public)` verified live
  via the read-only probe — `owner` deprecated, omitted; NOT applied at
  commit; applied later under the T5 approval).
- [ ] **3. Policy battery** — touches: `supabase/tests/07_storage_rls.sql`
  (new file + object fixture rows referencing the six fixture matters go in
  `supabase/tests/00_fixtures.sql`, the documents/messages precedent —
  including the reset-ordering `delete from public.files;` +
  `delete from storage.objects where bucket_id = 'matter-files';` before
  matters, the 6-file/6-object sanity pins, **and fixture object inserts
  respecting `storage.objects`' NOT NULL/generated columns — `path_tokens`
  is generated (cannot be inserted), `bucket_id`/`name`/`metadata` are
  required**) + `scripts/verify_policy_tests.sh`
  — **four sites**: battery file list, run loop, UUID cross-ref scan,
  FAIL-marker scan — **plus the `--apply` order gains `07_storage.sql`**,
  the structural pins re-scope (9→10 public tables / 8→9 public policies
  + files grant/anon rows + **new storage pins**: bucket present,
  `files_storage_select` on storage.objects present) + the forward pin
  **splits** (the current single "both absent" assertion becomes `files`
  present — covered by the 10-table pin — and `messages` still 0,
  narrowed to `('messages')`), **and the harness header + D-P0C1(b)
  forward-pin comments** ("all nine" → "all ten"; "individual
  messages/files still absent" → "individual message rows/bodies still
  absent; file storage shipped as the fourth un-deferral") — done when: static `--check` green
  and the battery runs green against a Postgres-with-storage (owner's
  Docker `supabase start` host or CI) with the §4/§6 deny rows incl. the
  non-vacuous org-mismatch + guessed-path rows; committed.
- [ ] **4. Ephemeral rehearsal (r-series)** — touches: evidence record
  `docs/storage_rehearsal_evidence_r1_<date>.md` — done when: the loop
  (migrate → policies → battery → read-as-roles on **both layers**) passes
  on throwaway infra with zero dev-project contact; **owner-side / CI
  runner** (matters/documents/messages r1 Path A precedent; the `supabase
  start` host provides the storage schema).
- [ ] **5. Dated apply-approval → apply** — touches: dev project
  (07_storage migration + both policies + demo file rows + demo objects),
  `docs/storage_apply_approval_<date>.md` + `docs/storage_apply_execution_<date>.md`
  — done when: the owner's dated approval exists, apply executed with
  `_down.sql` pairing + cleanup discipline (baseline probe: files absent,
  bucket absent, policies 8→9 public + storage.objects 0→1; demo rows +
  objects reference the applied demo matter ids), observed output recorded
  verbatim.
- [ ] **6. Matrix addendum (dated)** — touches: `docs/permission_matrix.md`
  §4 + §6 — adds the **"View a matter file (metadata)"** row (client/
  attorney cells SHIP behind `files_select_assigned`; partner/
  `compliance_officer` "deny unless separately assigned" cells stay
  ungranted; `platform_owner_admin` deny always) and flips the §6 storage
  rows to enforced (guessed-path download denied — battery-proven; stale
  signed URL — policy-at-generation + TTL, caveat recorded) — done when:
  addendum committed **before** the client surface ships, ledger sweep
  green.
- [ ] **7. Client swap (env-gated, NEW surface)** — touches:
  `lib/features/storage/domain/file_metadata.dart` + `storage_gateway.dart`
  + `data/fake_storage_gateway.dart`, `lib/data/storage/supabase_storage_api.dart`
  + impl + `supabase_storage_gateway.dart`, `lib/app/service_locator.dart`,
  the `matter_files_section` widget (matter-details mirror, metadata-only,
  no download affordance), 3 `.arb` + generated l10n, tests (mapping incl.
  size_bytes/mime/storage_path, matterRef embed + fallback, failure
  mapping incl. `providerUnavailable`, DI pins, section widget) — done
  when: format clean · analyze clean · suite green (fake unchanged) ·
  ledger PASS; no shipped VO/presentation changed.
- [ ] **8. Lockstep + evidence + close** — touches: README test count,
  roadmap §14 fourth per-feature flip + gate-table row, completion evidence
  `docs/storage_real_data_completion_evidence_<date>.md`, dated close
  decision — done when: all docs sweep green, full gate re-run on the
  committed state, close decision recorded.
