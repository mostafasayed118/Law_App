# LegalHub — Storage RLS-Gate Design Review (2026-08-08)

> **Record type:** RLS-gate design review for the real-storage (read)
> slice — the fourth roadmap §14 per-feature un-deferral, following the
> `docs/p2_schema_rls_design.md` §8 Q1–Q6 pattern and the **matters,
> documents and messages precedents**
> (`docs/matters_rls_gate_review_2026-08-07.md` +
> `docs/documents_rls_gate_review_2026-08-07.md` +
> `docs/messages_rls_gate_review_2026-08-07.md`, all three slices SHIPPED —
> applied + client-swapped). **Docs + rehearsal-ready artifacts only — NOT
> applied:** nothing in this review or the paired
> `supabase/migrations/07_storage*.sql` / `supabase/policies/files.sql` /
> `supabase/policies/storage_objects.sql` touches the dev project until the
> owner's dated apply-approval (INSTRUCTIONS.md §2.1/§5 hard gates; the
> matters/documents/messages apply pattern).
>
> **Status: REVIEWED 2026-08-08 (decision-level).** Plan:
> `docs/storage_real_data_plan_2026-08-08.md` (D-STR1…D-STR9 ratified by
> autonomy — recommended path, per the pair-programming grant; the plan was
> drafted on `main` `cc33da3` + the D-STR2 reviewer fold `bad9641`).
> **Owner:** Project Owner (github.com/mostafasayed118). **Governed by:**
> `docs/permission_matrix.md` §4/§6 (file rows — matter-scoped content +
> the storage block) · §7 (addendum discipline) ·
> `docs/p2_schema_rls_design.md` §8 pattern (Q4 storage/realtime deferral,
> consummated here) · `docs/storage_real_data_plan_2026-08-08.md` ·
> `docs/messages_rls_gate_review_2026-08-07.md` (the exists-subquery
> precedent) · `docs/rollback_plan.md` ·
> `docs/p0_closure_scope_2026-08-05.md` (D-P0C1(a) deny-row discipline) ·
> `INSTRUCTIONS.md` §2.1/§3/§5.

---

## 1. Gate position

| Precondition (roadmap §14 → this slice) | Status |
|---|---|
| P0 closes (D-02…D-10b) | ✅ **RATIFIED 2026-08-05** — `docs/p0_closure_scope_2026-08-05.md` (D-P0C1…D-P0C5) |
| Policy tests exist | ✅ Shipped — `scripts/verify_policy_tests.sh` + `docs/p0c1_verification_evidence_2026-08-05.md` |
| Signed matrix governs the grant (positive + negative) | ✅ `docs/permission_matrix.md` §4 file rows (files are **matter content** — line 143/148) + §6 storage block (guessed-path download · stale signed URL) |
| Matters + documents + messages precedents (the discipline chain ran green three times) | ✅ **SHIPPED 2026-08-07** — applied + battery r1 PASSED + matrix addenda + client swaps |
| Applied `matters` table (this slice's FK target + assignment source) | ✅ Applied on the dev project (matters T5 — execution evidence `7d0fbfe`); `documents` + `message_threads` also applied |
| Platform storage layer present (`storage.buckets` / `storage.objects`) | ✅ Native Supabase Storage on the dev project and on any `supabase start` rehearsal host — the P2 Q4 deferral ("zero buckets expected", `docs/p2_rehearsal_evidence_r4_2026-08-01.md`) is **consummated here** |
| RLS-gate review (this record) | ✅ Answered 2026-08-08 (§3 Q1–Q6) |
| Rollback pairing | ✅ `supabase/migrations/07_storage.down.sql` + git-revert policy pairing (§6) |
| Dated matrix addendum **before** the client surface ships | ⏳ T6 of the plan (after apply, before T7) |
| Dated apply-approval | ⏳ T5 — owner-gated; nothing applied until then |

**Conclusion:** the decision-level preconditions are satisfied (P0 + policy
tests + three shipped precedents + the platform storage layer) and the
schema artifacts are **rehearsal-ready but unapplied**. The first SQL
execution is the battery/rehearsal (T3/T4) on a Postgres-capable
environment **with the storage schema** — the **established host is the
owner's Docker machine** (`supabase start`; matters/documents/messages r1
Path A precedent), so this review makes **no execution claim**.

## 2. Scope

**In scope (read path only):** a `public.files` metadata table (D-STR3
column shape — **metadata only, no content/body/url column**, D-V1 line
held), one RLS SELECT policy on it (`files_select_assigned` — the
documents/messages exists-subquery pattern, org-mismatch clause
load-bearing), a **private `matter-files` bucket** (idempotent insert —
`on conflict do nothing`, D-STR4) with one RLS SELECT policy on
`storage.objects` (`files_storage_select` — path-derived org/matter gate
including the **active-membership arm**, D-STR2), default-deny revokes + a
narrow direct SELECT grant (Q5 discipline), and the paired backout. The
client swap (T7) is a separate, env-gated slice that **builds** the first
storage client surface (D-STR7).

**Out of scope (flagged, not guessed):** file **uploads/writes** (no
INSERT/UPDATE/DELETE grant, no write RPC — a future reviewed slice with
its own matrix addendum); a **download affordance / signed-URL UX**
(D-STR9 — the bytes are RLS-gated and battery-proven server-side; the
client interaction is a follow-up); partner/`compliance_officer` "deny
unless separately assigned" oversight reads (D-STR6 — mechanism undefined;
not granted); realtime file events; audit surfacing (`read_org_audit` /
`read_platform_audit` stay §14/P2-gated); individual message rows/bodies
(still deferred — the forward pin narrows to `('messages')`); seeding
(apply-time, T5, owner-approved with cleanup).

## 3. Gate-review decisions (Q1–Q6, answered 2026-08-08)

1. **Q1 — Read mechanism: RESOLVED.** **Two-layer, both RLS, no SECURITY
   DEFINER RPC.** (a) **Metadata:** `public.files` + `files_select_assigned`
   via PostgREST (`supabase.from('files').select()`). (b) **Bytes:**
   `files_storage_select` on `storage.objects` for the private
   `matter-files` bucket — the only surface that can gate object bytes (a
   public table alone cannot). The public-layer policy calls
   `public.is_active_member(organization_id)` — already EXECUTE-granted to
   `authenticated` (02_rls_functions R-4 grants); the storage-objects
   policy calls the same helper on the **path's org segment** (storage
   policy expressions may reference `public.*` functions + `auth.uid()` —
   **proven live by the T3 battery, not assumed**). No new function grant
   is introduced.
2. **Q2 — Assignment model: RESOLVED.** Files are **matter content**
   (matrix §4 line 148 — "a restricted matter **or its documents/
   messages**" — and §6). **Public layer:** a row grants iff
   `is_active_member(organization_id)` **and** the reader is assigned
   (client or attorney) **on the file's matter**, via the documents/
   messages exists-subquery pattern verbatim: `m.id = files.matter_id AND
   m.organization_id = files.organization_id AND (m.assigned_client_id =
   auth.uid() OR m.assigned_attorney_id = auth.uid())`. **Objects layer:**
   the object **path encodes `{org_id}/{matter_id}/{filename}`** and the
   policy derives the gate from the segments via `storage.foldername(name)`:
   `bucket_id = 'matter-files' AND public.is_active_member((storage.foldername(name))[1]::uuid) AND m.id::text = (storage.foldername(name))[2] AND m.organization_id::text = (storage.foldername(name))[1] AND (m.assigned_client_id = auth.uid() OR m.assigned_attorney_id = auth.uid())` (inside an exists on `matters`). **The active-membership arm is load-bearing on BOTH layers** — a suspended-but-still-assigned user must be denied on `storage.objects` exactly as on `public.files` (the plan reviewer fold `bad9641`; the fixture matter 6 assigns `suspended-a`, pinning it). The **`m.organization_id`-vs-path/row org equality is load-bearing on both layers** — the org gate comes from the matter's **authoritative** org, so a file/object is never readable when its matter is not (the org-mismatch battery rows pin it).
3. **Q3 — matterRef (title) resolution: RESOLVED.** Rows store
   `matter_id` (ids only); the client `FileMetadata.matterRef` is
   **title-keyed by design** (D-W2). The gateway resolves the title via the
   **embedded `matters(title)` select** (the documents D-DR4 pattern
   exactly), falling back to the raw matter id (honest — never a
   fabricated title). The embed resolves because the policy guarantees the
   reader passes the matter gate.
4. **Q4 — `platform_owner_admin` and oversight rows: RESOLVED.** Neither
   policy contains an **owner carve-out** — the matrix's "deny, always"
   row holds as an **operational invariant, not a policy guarantee**:
   owner accounts are never assigned on matters, so both gates deny them;
   the battery pins the unassigned-owner deny row on **both layers**.
   **Recorded residual (mirrors the matters Q4 / documents Q4 / messages
   Q4):** if an owner account were ever assigned on a matter, both
   policies WOULD grant its files/objects — enforcing the categorical deny
   would require an `is_platform_owner()` exclusion (and its EXECUTE grant
   to `authenticated`, widening the PostgREST surface the prior reviews
   avoided); deferred with the oversight mechanism (D-STR6).
   Partner/`compliance_officer` "deny unless separately assigned" cells
   are **NOT granted** in this slice.
5. **Q5 — No direct table mutation; metadata only: RESOLVED.** The only
   grant is `select` on `public.files` to `authenticated` (mirrors
   matters/documents/messages); no INSERT/UPDATE/DELETE grant, no write
   RPC. On `storage.objects` no direct table grants are added — the
   bucket is **private** (`public = false`) and the RLS policy is the
   only read surface; anon/authenticated default-deny holds. The `files`
   table carries **no content/body/url column** (bytes live only in
   `storage.objects`, never in the table — D-V1). The new client surface
   is **metadata-only** (D-STR7) with **no download affordance** (D-STR9)
   — the storage surface can never render file bytes in this slice. A
   future write/download slice is a separate reviewed design with its own
   matrix addendum.
6. **Q6 — Audit: RESOLVED.** Read-only slice: no new audit events, no
   `write_audit` call sites, no system-actor additions. File **metadata +
   byte** reads are not audited (consistent with matters/documents/
   messages); surfacing the audit RPCs stays a separate §14 item.

## 4. Policy + deny-rows spec (the battery contract, executed in T3)

Positive (each grants exactly the file set **and** object set of the
assigned matters, one file + one object per fixture matter — the documents
2/3/1 count shape, asserted on **both layers**):
- **assigned client** (client-a on matters 1,2) reads their files → 2
  **and** their objects → 2;
- **assigned attorney** (partner-a on matters 1,2,3) reads theirs → 3 / 3;
- **orphan** (assigned client on matter 4) reads theirs → 1 / 1;
- row-count pins prove no blanket-org bleed (same count shape as the
  matters 2/3/1, documents 2/3/1 and messages 2/3/1 batteries).

Negative (deny rows, `03_platform_owner_boundary` style, **each deny row
asserted on both the `public.files` layer and the `storage.objects` layer**):
- active org member, **no matter assignment** → denied (org-role-alone);
- **org-mismatch (D-STR2 invariant):** a file row whose `organization_id`
  ≠ its matter's org denies, and an object whose **path org segment** ≠
  its matter's org denies — for **every** role; the fixture must be
  **non-vacuous** — the reader is an active member of the row's org AND
  assigned on the temp (different-org) matter, so only the clause denies
  (the documents T3 lesson, pre-empted);
- **cross-org**: partner-b assigned on an org-a matter, member of org-b
  only → denied (`is_active_member` of the file's org / path org fails);
- **suspended** membership in the file's org → denied **on both layers**
  — the load-bearing `is_active_member` arm (fixture matter 6 assigns
  `suspended-a`; without the arm the objects layer would leak);
- **unauthenticated** → denied;
- **`platform_owner_admin`** (owner account, unassigned) → denied, always
  (D-P0C1(a) deny-row extension; Q4 residual noted in-file);
- **guessed-path (matrix §6 row 1):** an object under a path whose matter
  id is unknown/foreign (or whose org segment doesn't match) → denied for
  every role — the objects-layer exists finds no assigned matter (the
  "Download a private object via a guessed path" row, now executed);
- **stale signed URL (matrix §6 row 2):** **RECORDED** — signed-URL
  **generation** is itself RLS-gated (a removed member cannot mint one)
  and issued URLs are TTL-bound; not claimed as instant mid-flight
  revocation (the P2 r4 Q4-deferral convention: future-facing negative,
  recorded not executed);
- `size_bytes` **CHECK** row: an insert with a negative size (`-1`) fails
  the CHECK — the schema is the mapping contract;
- deleted-cascade sanity: dropping the matter removes its `files` rows (FK
  `on delete cascade`); `storage.objects` have **no matters FK** — the
  battery teardown deletes the temp objects explicitly (pinned).

## 5. Schema (rehearsal-ready — D-STR3/D-STR4)

`public.files`: `id uuid pk default gen_random_uuid()` · `organization_id
uuid not null fk organizations on delete cascade` (denormalized, mirrors
matters/documents/message_threads — the policy's membership check reads
it, but the **matter's org is authoritative**, Q2) · `matter_id uuid not
null fk matters on delete cascade` (the assignment source of truth + FK
target for the embed) · `name text not null` (never PII by convention) ·
`mime_type text not null default 'application/octet-stream'` · `size_bytes
bigint not null default 0` with a `check (size_bytes >= 0)` — the schema
is the mapping contract, so no write path can insert a size the client
cannot render · `storage_path text not null` (the **single source of
truth** linking the row to its object — `{org_id}/{matter_id}/{filename}`,
canonical lowercase hyphenated uuid::text — pinned so T2's artifact and
T3's battery cannot drift) · `created_at timestamptz not null default
now()` · `updated_at timestamptz not null default now()`. Indexes:
`(organization_id)`; `(matter_id)` (the FK join + battery lookup shape).
RLS enabled; `revoke all … from anon, authenticated`; `grant select … to
authenticated` only (Q5). **No content/body/url column** (D-V1).

Bucket + objects (D-STR4): `insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types, owner) values ('matter-files',
'matter-files', false, …) on conflict (id) do nothing` — **private**, so
no anonymous public read; **the column list is verified against the dev
project's storage schema at T2** (`owner` may not exist in current
versions and is omitted if absent — the sketch is not a column contract);
objects at `{org_id}/{matter_id}/{filename}`; `files_storage_select` on
`storage.objects` as Q2. Storage API client reads
(`storage.from('matter-files').download(storage_path)`) are authenticated
+ RLS-scoped (follow-up slice, D-STR9).

## 6. Rollback pairing (never-fix-forward)

- `supabase/migrations/07_storage.down.sql` — `drop table public.files;`
  then `delete from storage.buckets where id = 'matter-files';` (clean
  inverse; the platform's bucket-delete cascades its objects — the inline
  `size_bytes` CHECK dies with the table, like 05/06, no type object to
  drop).
- Policy backout: `git revert` of the policy commits (design §7
  convention in `docs/rollback_plan.md`).
- Apply-time residue (T5): demo file rows + demo objects are inserted and
  removed in the same owner-approved step (cleanup discipline; one insert
  set, one delete set).

## 7. Ledger

- Docs-only + rehearsal-ready SQL this session: **no `lib/`/`test/` change,
  no README-count change, no dev-project contact** — `verify_ledger.sh`
  unaffected; nothing pushed.
- The plan (T1–T8) tracks each subsequent gate; the battery (T3) and
  rehearsal (T4) are the first executions and will carry their own
  evidence records.
