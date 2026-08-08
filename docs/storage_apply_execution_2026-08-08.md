# LegalHub — Storage Apply Execution Evidence (2026-08-08)

> **Record type:** Execution evidence for the real-storage (read) slice
> (plan `docs/storage_real_data_plan_2026-08-08.md` T5) against the shared
> dev project (`eutmvevpskerzpqmwplv`, `eu-central-1`), under the dated
> apply-approval (`docs/storage_apply_approval_2026-08-08.md`, **APPLY
> APPROVED 2026-08-08**). Mirrors the matters/documents/messages apply
> execution records (the §4-guardrail discipline).
>
> **Status: APPLIED 2026-08-08 — up sequence complete and verified on the
> shared dev project**: baseline probe → `07_storage` (bucket + files
> table) → `policies/files` + `policies/storage_objects` → demo seed (4
> files + 4 objects on the applied demo matters) → post-apply smoke all
> verified. Rollback pairing standing by (`07_storage.down.sql` + targeted
> demo-row/object delete + `git revert` of the two policy files). Nothing
> beyond the approval §3 scope was touched; the approval §5 exclusions
> hold (no write path, no download affordance, no other bucket).
>
> **Baseline-count note (honest delta, not a trigger):** the approval
> record's §4.1 baseline ("8 public policies → 9") was written before the
> realtime-push + send-message applies (owner-approved, later in the day);
> the actual pre-apply dev state was **10 public tables / 10 RLS / 9
> public policies / 0 storage policies / publication exactly messages**.
> The storage apply's real deltas: **tables 10→11, RLS 10→11, public
> policies 9→10, storage policies 0→1** — the four matters, the two dev
> accounts, and the publication were untouched (verified, not assumed).

---

## 0. Runbook (executed 2026-08-08 with these commands)

```bash
# 1. Baseline probe (read-only) — see §1 for the observed output
# 2. Apply the schema migration (approval §3.1)
supabase db query --linked --file supabase/migrations/07_storage.sql
# 3. Apply the two policies (approval §3.2)
supabase db query --linked --file supabase/policies/files.sql
supabase db query --linked --file supabase/policies/storage_objects.sql
# 4. Demo seed (approval §3.3) — 4 files + 4 objects on the applied demo
#    matters, storage_path == object name, generic names, D-STR2 org invariant
# 5. Post-apply smoke (approval §4.5) — structural subset + role-impersonated
#    reads on BOTH layers (partner 3/3 + family 0; clients 0/0; anon denied)
```

Rollback pairing standing by: `07_storage.down.sql` (drop `public.files` +
delete the `matter-files` bucket — the platform bucket-delete cascades its
objects) + a targeted delete of the seeded rows (`delete from public.files
where id like '90000000-…%'` + `delete from storage.objects where id like
'a0000000-…%'`) + `git revert` of the two policy files (the RLS-gate
review §6 convention) — **never fix-forward**.

## 1. Baseline probe (read-only, before the up sequence)

| Check | Expected | Observed | Verdict |
|---|---|---|---|
| `public.files` table | absent | `0` | ✅ |
| `matter-files` bucket | absent | `0` | ✅ |
| Public tables / RLS | 10 / 10 (pre-storage) | `10` tables (information_schema) | ✅ (files was the missing 11th) |
| Public policies | 9 current (→ 10) | `9` | ✅ (the approval's "8" predates the realtime-push + send-message applies — see the baseline-count note) |
| Storage-schema policies | 0 (→ 1) | `0` | ✅ |
| Applied demo matters resolve | the four ids, org `ef43087b-…` | all four present: `a6715e17-…` (acquisition), `d155dc92-…` (lease), `4f4a935f-…` (procedural), `575391b6-…` (family) — all org `ef43087b-adf4-4480-9bb2-28c26f46ec71` | ✅ verify-don't-guess |
| Publication (`supabase_realtime`) | exactly `messages`, untouched | `public · messages` only | ✅ |

Assignment map (the seed + smoke target): partner `8fa94af0-…` is the
assigned attorney on acquisition / lease / procedural; the family matter
`575391b6-…` is **client-only** (`0c54d251-…`); the demo clients hold no
dev membership rows.

## 2. Up sequence (each step applied + verified)

### 2.1 `07_storage.sql` — the `matter-files` bucket + `public.files`

`supabase db query --linked --file supabase/migrations/07_storage.sql` →
exit 0. Verified:

- **Bucket:** `matter-files` present (`count = 1`) — the minimal
  `(id, name, public)` insert, the **rehearsal-proven** column list
  (watch-item (a) resolved at T4 and confirmed on the dev project).
- **Table:** `public.files` present with the metadata-only column set
  (D-STR3 — no content/body/url): `id`, `organization_id`, `matter_id`,
  `name`, `mime_type`, `size_bytes`, `storage_path`, `created_at`,
  `updated_at`; RLS enabled.

### 2.2 `policies/files.sql` + `policies/storage_objects.sql`

Both → exit 0. Verified: `files_select_assigned` (SELECT on `files`,
`is_active_member` + the org-mismatch exists clause + assigned
client/attorney) and `files_storage_select` (SELECT on `storage.objects`,
bucket + `is_active_member((storage.foldername(name))[1]::uuid)` + the
path-org exists clause — the **is_active_member arm on both layers**,
D-STR2). **Public policies 9 → 10; storage-schema policies 0 → 1.**

### 2.3 Demo seed (approval §3.3) — 4 files + 4 objects

Fixed demo ids (`90000000-…` files, `a0000000-…` objects), the applied
demo matter ids, org `ef43087b-…` on every row, **generic demo file names
only** (D-STR8 — no real client/legal copy, no PII):

| File id | Matter | Name | Bytes layer (object name) |
|---|---|---|---|
| `90000000-…-0001` | `a6715e17-…` (acquisition) | `acquisition-review-summary.pdf` | `a0000000-…-0001` — same path |
| `90000000-…-0002` | `d155dc92-…` (lease) | `lease-agreement-draft.docx` | `a0000000-…-0002` — same path |
| `90000000-…-0003` | `4f4a935f-…` (procedural) | `procedural-checklist.pdf` | `a0000000-…-0003` — same path |
| `90000000-…-0004` | `575391b6-…` (family) | `family-intake-notes.docx` | `a0000000-…-0004` — same path |

Verified per guardrail §4.4: **4 files + 4 objects** seeded; every file's
`storage_path` **equals its object's `name`** (the D-STR4 encoding —
`true` on all four) and every row's `organization_id` **equals its
matter's org** (the D-STR2 invariant — `true` on all four).

## 3. Post-apply smoke (role-impersonated reads, R1 pattern — BOTH layers)

| Reader | Identity | Expected | Observed | Verdict |
|---|---|---|---|---|
| Partner (assigned attorney, the **only** dev member) | `sub=8fa94af0-7390-4f7a-988a-3965f7da04de` | reads the files/objects on its 3 assigned matters | files **3** · objects **3** | ✅ both layers consistent |
| Partner — family matter (client-only) | same | 0 (not assigned) | files **0** | ✅ the assignment gate, live |
| Assigned client (NO membership rows) | `sub=9acfd3b4-96c6-4836-aaa7-defd7864cefb` | 0 — the D-STR2 membership guard | files **0** · objects **0** | ✅ membership guard firing live — recorded as an honest expectation, never a defect (the matters/documents/messages smoke precedent) |
| Anon | `role=anon` | denied both layers | files: `permission denied for table files` (no grant, default-deny) · objects: the policy's `matters` subquery is default-deny → denied | ✅ anon denied on both layers |

> **Honest expectation note (\*):** the demo **clients** are assigned on
> the demo matters but hold **no dev membership rows** — `is_active_member`
> is false for them, so they read 0 on both layers. This is the D-STR2
> membership guard firing live (the same posture recorded in the
> matters/documents/messages smokes), never a defect.

**Final structural subset (all verified):** **11 tables / 11 RLS** (files
added; every public table RLS-enabled) · **public policies 10** (9→10) ·
**storage policies 1** (0→1) · bucket `matter-files` **1** · publication
**exactly `public.messages`** (untouched) · files 4 · objects 4.

## 4. Trigger-condition sweep (rollback_plan §5)

| Trigger | Observed | Verdict |
|---|---|---|
| A matrix negative row starts passing | anon denied on both layers · assigned client (no membership) reads 0/0 · partner does NOT read the client-only family matter | ✅ none |
| Cross-tenant data visible | all rows + reads scoped to org `ef43087b-…`, the four applied demo matters | ✅ none |
| A demo row/object lands on a real matter/account | the seed targets the applied **demo** matters only, generic names | ✅ none |
| A non-generic file name or path appears | all four names generic (D-STR8), no PII, no real account identities | ✅ none |
| Policy inventory drift | public 9→10 + storage 0→1, exactly the predicted set (`files_select_assigned` + `files_storage_select`) | ✅ none |

No trigger condition fired; **no rollback invoked** (never fix-forward).
The rollback pairing (`07_storage.down.sql` + the targeted demo-row/object
delete + the policy git-revert) stands by, unexercised.

## 5. Ledger / state / owner attention

- **Applied 2026-08-08:** `07_storage` (bucket + files table) +
  `policies/files` + `policies/storage_objects` + the demo seed (4 files +
  4 objects). Dev project now: **11 tables / 11 RLS / 10 public policies +
  1 storage policy / `matter-files` bucket / publication exactly messages
  / 4 demo files + 4 demo objects** — the approval's scope, with the
  baseline-count delta recorded (§0).
- **Plan T5 row:** flipped DONE (the dated approval §6 + this execution
  record close the apply gate; the roadmap §14/§13/§2 storage HELD
  markers resolve).
- **No write path** (D-STR9): the slice is read-only; uploads and any
  storage write path stay §14-deferred; **no download affordance** was
  added — the bytes are RLS-gated and battery-proven server-side.
- **Configured-build verification (D-STR7):** the env-gated
  `SupabaseStorageGateway` swap (committed `704f212`) now has its server
  prerequisite live — a configured build's file list will read these
  seeded rows under the same RLS gates.
- Committed as `docs(storage)`; nothing pushed; worktree clean except the
  pre-existing owner-side `SPEC_KIT.md`.
