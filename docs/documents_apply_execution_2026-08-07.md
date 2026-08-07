# LegalHub — Documents Apply Execution Evidence (2026-08-07)

> **Record type:** Execution evidence for the real-documents (read) slice
> apply (plan `docs/documents_real_data_plan_2026-08-07.md` T5), under the
> dated apply approval `docs/documents_apply_approval_2026-08-07.md`
> (APPLY APPROVED 2026-08-07, owner's dated sign-off §6). Mechanism:
> `supabase db query --linked` (Management API as postgres), the R1
> rehearsal's and the matters apply's established path.
>
> **Status: APPLIED 2026-08-07 — up sequence complete and verified on the
> dev project (`eutmvevpskerzpqmwplv`), with the observed output recorded
> verbatim below. Rollback pairing standing by (`05_documents.down.sql`
> drops the table + policy; the seeded demo rows go with it).**

---

## 1. Baseline probe (read-only, before the up sequence)

| Probe | Observed | Expected | Verdict |
|---|---|---|---|
| `documents` table exists? | `0` | 0 (absent) | ✅ baseline matches the rehearsal posture |
| `matters` table + demo rows | present · `4` rows (the four applied demo matters) | present · 4 | ✅ |
| `pg_policies` (public) count | `6` | 6 (→ 7 after apply) | ✅ |
| Policy inventory | `invitations_select_partner`, `matters_select_assigned`, `memberships_select_org_roster`, `organizations_select_active_member`, `profiles_select_own`, `profiles_update_own` | 6 incl. `matters_select_assigned` | ✅ |
| Demo matters (org `ef43087b-adf4-4480-9bb2-28c26f46ec71`) | `a6715e17-…` acquisition review · `d155dc92-…` lease consultation · `4f4a935f-…` procedural review · `575391b6-…` family consultation | the four applied ids (matters execution §2.2) | ✅ — resolved from the dev project's own `matters` rows, never guessed |
| Demo accounts | `9acfd3b4-96c6-4836-aaa7-defd7864cefb` al3tar@gmail.com · `187fc8d6-e6df-40bd-a0f3-6ee22cac9568` al3tar1@gmail.com · `0c54d251-1cdd-4be6-9ce5-623a5987045f` al3tar4545@gmail.com · `8fa94af0-7390-4f7a-988a-3965f7da04de` al3tar66@gmail.com | present (matters baseline) | ✅ |

## 2. Up sequence (each step applied + verified)

| # | Step | Mechanism | Result |
|---|---|---|---|
| 1 | `supabase/migrations/05_documents.sql` | `db query --linked --file` | ✅ applied cleanly (exit 0, no errors) |
| 2 | `supabase/policies/documents.sql` | `db query --linked --file` | ✅ applied cleanly (exit 0) |
| 3 | Demo seed (4 rows, real dev ids) | `db query --linked` INSERT ... RETURNING | ✅ 4 rows; org + matter ids resolved from the dev project's own rows (never guessed) |

### 2.1 Mid-apply verification (after steps 1–2)

| Check | Observed | Verdict |
|---|---|---|
| `documents` table + RLS | `rowsecurity = true` | ✅ |
| Policy | `documents_select_assigned` (SELECT) | ✅ |
| Grants | `authenticated` SELECT only; **anon absent** | ✅ (narrow Q5 surface) |
| `pg_policies` count | `7` | ✅ (6 → 7, the re-scoped pin) |
| Metadata-only (D-V1) | `0` columns named body/content/size/url | ✅ — no body/content column exists |

### 2.2 Seeded demo rows (org `ef43087b-adf4-4480-9bb2-28c26f46ec71`, generic D-V4 titles, no real PII)

| id | title | document_type | matter_id | org = matter org? |
|---|---|---|---|---|
| `775eb1ce-435f-444a-a554-b9ffb5297f2a` | Demo document — acquisition review | contract | a6715e17-… | ✅ (D-DR2 invariant held) |
| `7059eed8-e805-4d15-93b4-950ec537d8de` | Demo document — lease consultation | brief | d155dc92-… | ✅ |
| `32176fc4-db20-4d26-a2e6-ac79b9dcfa0d` | Demo document — procedural review | evidence | 4f4a935f-… | ✅ |
| `885f23e9-b55e-4145-9a54-73914236132a` | Demo document — family consultation | correspondence | 575391b6-… | ✅ |

The post-seed join probe (`documents d JOIN matters m ON m.id = d.matter_id`) confirmed every
row's `organization_id` equals its matter's `organization_id` — the load-bearing
D-DR2 clause holds at seed time.

## 3. Post-apply smoke (role-impersonated reads, R1 pattern)

`set local role authenticated` + `request.jwt.claim.sub`/`role` — the RLS
gate on the live dev project:

| Actor | Observed | Expectation | Verdict |
|---|---|---|---|
| `8fa94af0-7390-…` (partner/active, **org member**, attorney on matters 1,2,3) | **3** rows (acquisition review · lease consultation · procedural review) | 3 | ✅ **positive** — assigned attorney sees exactly its set |
| `0c54d251-1cdd-…` (assigned **client** on matter 4, **NOT an org member**) | **0** rows | 0* | ✅ **membership guard confirmed live** — see note |
| `9acfd3b4-96c6-…` (assigned **client** on matter 1, **NOT an org member**) | **0** rows | 0* | ✅ **membership guard confirmed live** — see note |
| `187fc8d6-e6df-…` (assigned **client** on matter 2, **NOT an org member**) | **0** rows | 0* | ✅ **membership guard confirmed live** — deny-hold sweep probe |

> **Honest expectation note (\*):** exactly the matters smoke finding — only
> `8fa94af0-…` holds a dev membership row, so the other demo accounts are
> not org members. The policy (D-DR1: `is_active_member(organization_id)`
> **and** matter assignment) therefore correctly denies them: **assignment
> alone is insufficient — the org-membership guard is live on the dev
> project**, as designed and rehearsed (the battery's cross-org/suspended/
> org-role-alone denies are the same branch). This is not a defect — it is
> the defense-in-depth the matrix requires, now observed for documents.
> The org-role-alone branch (active member, no assignment) has no live demo
> account to exercise (only `8fa94af0-…` is a member, and it is assigned) —
> that branch is pinned by the battery's 05.04 row in the rehearsal
> (`docs/documents_rehearsal_evidence_r1_2026-08-07.md` §4). For a fuller
> client-side demo, the owner may later add memberships for the demo client
> accounts — a deliberate, separate data action outside this slice's §3
> scope.

## 4. Trigger-condition sweep (rollback_plan §5)

No trigger fired: no matrix negative row started passing (every deny actor
returned 0); no cross-tenant data visible (all four documents in org
`ef43087b-…`, each `organization_id` = its matter's org); no
credential/token/PII in any output (generic demo titles only); the narrow
grant surface held (anon absent, verified in §2.1). **Rollback pairing
standing by:** `05_documents.down.sql` drops the table (and its policy dies
with it; the seeded rows go with it) — clean inverse, never fix-forward.

## 5. Ledger / state

- Applied and verified on the dev project `eutmvevpskerzpqmwplv`,
  2026-08-07, under the dated approval `388e31d` (APPLY APPROVED).
- The documents table + `documents_select_assigned` policy + demo seed are
  now live; the client surface (plan **T7**, the env-gated
  `SupabaseDocumentGateway`) is the next slice and will consume this applied
  posture in configured builds. T6 (dated matrix §4 addendum for the "View
  a document (metadata)" row) precedes T7 per the plan.
- Nothing pushed (this record + the approval land on local
  `feat/documents-real-read`).
