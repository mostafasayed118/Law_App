# LegalHub — Messages Apply Execution Evidence (2026-08-07)

> **Record type:** Execution evidence for the real-messages (read) slice
> apply (plan `docs/messages_real_data_plan_2026-08-07.md` T5), under the
> dated apply approval `docs/messages_apply_approval_2026-08-07.md`
> (APPLY APPROVED 2026-08-07, owner's dated sign-off §6, commit `38494e3`).
> Mechanism: `supabase db query --linked` (Management API as postgres), the
> R1 rehearsal's and the matters/documents applies' established path.
>
> **Status: APPLIED 2026-08-07 — up sequence complete and verified on the
> dev project (`eutmvevpskerzpqmwplv`), with the observed output recorded
> verbatim below. Rollback pairing standing by (`06_message_threads.down.sql`
> drops the table + policy; the seeded demo rows go with it).**
>
> **Access note (dated, resolved):** the first CLI session on the dev
> machine failed `supabase link` with "Your account does not have the
> necessary privileges to access this endpoint" — the login account had no
> membership in the org owning the dev project (`supabase projects list`
> showed six other projects across three orgs, all East US / West EU
> Ireland; `eutmvevpskerzpqmwplv`, Central EU, absent). Resolved
> 2026-08-07 by logging in with the owning account (the ref then appeared
> LINKED in `projects list`) and re-running `supabase link --project-ref
> eutmvevpskerzpqmwplv`. The failed link changed nothing.

---

## 0. Owner-side runbook (executed 2026-08-07 with these commands)

```bash
supabase login                          # owning account
supabase link --project-ref eutmvevpskerzpqmwplv   # Finished supabase link.
supabase db query --linked "..."        # each probe below
supabase db query --linked --file supabase/migrations/06_message_threads.sql
supabase db query --linked --file supabase/policies/message_threads.sql
supabase db query --linked "insert ... returning id, title;"   # the demo seed
```

## 1. Baseline probe (read-only, before the up sequence)

| Probe | Observed | Expected | Verdict |
|---|---|---|---|
| `message_threads` table exists? | `0` | 0 (absent) | ✅ baseline matches the rehearsal posture |
| `matters` table + demo rows | present · `4` rows | present · 4 | ✅ |
| `documents` table (second un-deferral) | `1` (present) | present | ✅ |
| `pg_policies` (public) count | `7` | 7 (→ 8 after apply) | ✅ |
| Policy inventory | `documents_select_assigned`, `invitations_select_partner`, `matters_select_assigned`, `memberships_select_org_roster`, `organizations_select_active_member`, `profiles_select_own`, `profiles_update_own` | 7 incl. matters + documents | ✅ |
| Demo matters (org `ef43087b-adf4-4480-9bb2-28c26f46ec71`) | `a6715e17-15a6-4456-96e3-78fc56630cfe` acquisition review · `d155dc92-f2df-4780-a1fb-99d73b8f80b6` lease consultation · `4f4a935f-c2bc-45f3-929e-130e51e97555` procedural review · `575391b6-a9ee-4125-8f16-bdc14454c144` family consultation | the four applied ids (matters execution §2.2) | ✅ — resolved from the dev project's own `matters` rows, never guessed |
| Demo accounts | `9acfd3b4-96c6-4836-aaa7-defd7864cefb` al3tar@gmail.com · `187fc8d6-e6df-40bd-a0f3-6ee22cac9568` al3tar1@gmail.com · `0c54d251-1cdd-4be6-9ce5-623a5987045f` al3tar4545@gmail.com · `8fa94af0-7390-4f7a-988a-3965f7da04de` al3tar66@gmail.com | present (matters baseline) | ✅ |

## 2. Up sequence (each step applied + verified)

| # | Step | Mechanism | Result |
|---|---|---|---|
| 1 | `supabase/migrations/06_message_threads.sql` | `db query --linked --file` | ✅ applied cleanly (exit 0, no errors) |
| 2 | `supabase/policies/message_threads.sql` | `db query --linked --file` | ✅ applied cleanly (exit 0) |
| 3 | Demo seed (4 rows, real dev ids) | `db query --linked` INSERT ... RETURNING | ✅ 4 rows; org + matter ids from the dev project's own rows (never guessed) |

### 2.1 Mid-apply verification (after steps 1–2)

| Check | Observed | Verdict |
|---|---|---|
| `message_threads` table + RLS | `rowsecurity = true` | ✅ |
| Policy | `message_threads_select_assigned` (SELECT) | ✅ |
| Grants | `auth_sel = true` · `anon_sel = false` | ✅ (narrow Q5 surface; the initial unaliased probe rendered a single `false` — a same-name column collision showing the anon column — re-run aliased to disambiguate) |
| `pg_policies` count | `8` | ✅ (7 → 8, the re-scoped pin) |
| Metadata-only (D-MSG1) | `0` columns named body/preview/attachment/sender | ✅ — no body/content column exists |

### 2.2 Seeded demo rows (org `ef43087b-adf4-4480-9bb2-28c26f46ec71`, generic D-MSG4 titles + participants, no real PII)

| id (RETURNING) | title | participants | matter_id | org = matter org? |
|---|---|---|---|---|
| `5d148bca-d784-4c21-81a1-1646c6754e2a` | Demo thread — acquisition review | `{"Demo attorney","Demo client"}` | a6715e17-… | ✅ (D-MSR2 invariant held) |
| `a8fd025e-d962-4573-9442-2d9f3a892376` | Demo thread — lease consultation | `{"Demo attorney","Demo client"}` | d155dc92-… | ✅ |
| `d0904762-87dc-45ff-9480-845444511738` | Demo thread — procedural review | `{"Demo attorney"}` | 4f4a935f-… | ✅ |
| `4a8755b1-0260-4bcb-8544-9f019e658632` | Demo thread — family consultation | `{"Demo client"}` | 575391b6-… | ✅ |

The post-seed join probe (`message_threads t JOIN matters m ON m.id =
t.matter_id WHERE t.organization_id <> m.organization_id`) returned **0**
rows — every thread's `organization_id` equals its matter's
`organization_id`; the load-bearing D-MSR2 clause holds at seed time.

## 3. Post-apply smoke (role-impersonated reads, R1 pattern)

`set local role authenticated` + `request.jwt.claim.sub` — the RLS gate on
the live dev project:

| Actor | Observed | Expectation | Verdict |
|---|---|---|---|
| `8fa94af0-…` (partner/active, **org member**, attorney on matters 1,2,3) | **3** rows (acquisition review · lease consultation · procedural review) | 3 | ✅ **positive** — assigned attorney sees exactly its set |
| `0c54d251-…` (assigned **client** on matter 4, **NOT an org member**) | **0** rows | 0* | ✅ **membership guard confirmed live** — see note |
| `9acfd3b4-…` (assigned **client** on matter 1, **NOT an org member**) | **0** rows | 0* | ✅ **membership guard confirmed live** |
| `187fc8d6-…` (assigned **client** on matter 2, **NOT an org member**) | **0** rows | 0* | ✅ **membership guard confirmed live** |

> **Honest expectation note (\\*):** exactly the matters/documents smoke
> finding — only `8fa94af0-…` holds a dev membership row, so the other
> demo accounts are not org members. The policy (D-MSR2:
> `is_active_member(organization_id)` **and** matter assignment) therefore
> correctly denies them: **assignment alone is insufficient — the
> org-membership guard is live on the dev project**, as designed and
> rehearsed (the battery's cross-org/suspended/org-role-alone denies are
> the same branch). This is not a defect — it is the defense-in-depth the
> matrix requires, now observed for message threads. The org-role-alone
> branch (active member, no assignment) has no live demo account to
> exercise (only `8fa94af0-…` is a member, and it is assigned) — that
> branch is pinned by the battery's 06.04 row in the rehearsal
> (`docs/messages_rehearsal_evidence_r1_2026-08-07.md` §4).

## 4. Trigger-condition sweep (rollback_plan §5)

No trigger fired: no matrix negative row started passing (every deny actor
returned 0); no cross-tenant data visible (all four threads in org
`ef43087b-…`, org-mismatch join probe = 0); no credential/token/PII in any
output (generic demo titles + participant names only); the narrow grant
surface held (`anon_sel = false`, verified in §2.1). **Rollback pairing
standing by (approval §4.3):** `06_message_threads.down.sql` drops the
table (and its policy dies with it; the seeded rows go with it) + the
targeted demo-row delete (`delete from public.message_threads where
matter_id in (the four demo matter ids)`) + `git revert` of the policy
commit — redundant with the drop but standing by per the approval's
wording — clean inverse, never fix-forward.

## 5. Ledger / state

- **Applied and verified on the dev project `eutmvevpskerzpqmwplv`,
  2026-08-07**, under the dated approval `38494e3` (APPLY APPROVED).
- The `message_threads` table + `message_threads_select_assigned` policy +
  demo seed are now live; the client surface (plan **T7**, the env-gated
  `SupabaseMessageGateway`) is the next slice and will consume this applied
  posture in configured builds. T6 (dated matrix §4 addendum for the "View
  a message thread (metadata)" row) precedes T7 per the plan.
- Nothing pushed (this record + the approval land on local
  `feat/messages-real-read`).
