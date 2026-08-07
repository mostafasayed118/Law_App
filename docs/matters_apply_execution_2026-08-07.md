# LegalHub — Matters Apply Execution Evidence (2026-08-07)

> **Record type:** Execution evidence for the real-matters read slice apply
> (plan `docs/matters_real_data_plan_2026-08-07.md` T5), under the dated
> apply approval `docs/matters_apply_approval_2026-08-07.md` (APPROVED
> 2026-08-07). Mechanism: `supabase db query --linked` (Management API as
> postgres), the R1 rehearsal's established apply path.
>
> **Status: APPLIED 2026-08-07 — up sequence complete and verified on the
> dev project (`eutmvevpskerzpqmwplv`), with the observed output recorded
> verbatim below. Rollback pairing standing by (`04_matters.down.sql` drops
> the table + policy; seed rows removed with it).**

---

## 1. Baseline probe (read-only, before the up sequence)

| Probe | Observed | Expected | Verdict |
|---|---|---|---|
| `matters` table exists? | `0` | 0 (absent) | ✅ baseline matches the rehearsal posture |
| `pg_policies` (public) count | `5` | 5 (→ 6 after apply) | ✅ |
| Demo orgs | `ef43087b-adf4-4480-9bb2-28c26f46ec71` "al3tar", `eb0b8cb8-eb4e-474e-8c76-ddde71582a38` "al3tar" | present | ✅ |
| Demo accounts | `9acfd3b4…` al3tar@gmail.com · `187fc8d6…` al3tar1@gmail.com · `8fa94af0…` al3tar66@gmail.com · `0c54d251…` al3tar4545@gmail.com | present | ✅ |
| Memberships | only `8fa94af0…` (partner/active) in **both** orgs; the other three demo accounts have **no membership** | — | ✅ (drives the smoke expectation below) |

## 2. Up sequence (each step applied + verified)

| # | Step | Mechanism | Result |
|---|---|---|---|
| 1 | `supabase/migrations/04_matters.sql` | `db query --linked --file` | ✅ applied cleanly (exit 0, no errors) |
| 2 | `supabase/policies/matters.sql` | `db query --linked --file` | ✅ applied cleanly (exit 0) |
| 3 | Demo seed (4 rows, real dev ids) | `db query --linked` INSERT | ✅ 4 rows; ids resolved from the dev project's own `auth.users` (never guessed) |

### 2.1 Mid-apply verification (after steps 1–2)

| Check | Observed | Verdict |
|---|---|---|
| `matters` table + RLS | `rowsecurity = true` | ✅ |
| Policy | `matters_select_assigned` (SELECT) | ✅ |
| Grants | `authenticated` SELECT only; **anon absent**; postgres owner-role privs | ✅ (narrow Q5 surface) |
| `pg_policies` count | `6` | ✅ (5 → 6, the re-scoped pin) |

### 2.2 Seeded demo rows (org `ef43087b…`, generic D-M4 titles, no real PII)

| id | title | practice_area | status | client | attorney |
|---|---|---|---|---|---|
| `a6715e17-15a6-4456-96e3-78fc56630cfe` | Demo matter — acquisition review | corporate | active | 9acfd3b4… | 8fa94af0… |
| `d155dc92-f2df-4780-a1fb-99d73b8f80b6` | Demo matter — lease consultation | civil | open | 187fc8d6… | 8fa94af0… |
| `4f4a935f-c2bc-45f3-929e-130e51e97555` | Demo matter — procedural review | criminal | closed | — | 8fa94af0… |
| `575391b6-a9ee-4125-8f16-bdc14454c144` | Demo matter — family consultation | family | open | 0c54d251… | — |

## 3. Post-apply smoke (role-impersonated reads, R1 pattern)

`set local role authenticated` + `request.jwt.claim.sub`/`claims` — the
RLS gate on the live dev project:

| Actor | Observed | Expectation | Verdict |
|---|---|---|---|
| `8fa94af0…` (partner/active, **org member**, attorney on 1,2,3) | **3** rows | 3 | ✅ **positive** — assigned attorney sees exactly its set |
| `0c54d251…` (assigned **client** on matter 4, **NOT an org member**) | **0** rows | 1* | ✅ **membership guard confirmed live** — see note |
| `9acfd3b4…` (assigned **client** on matter 1, **NOT an org member**) | **0** rows | 1* | ✅ **membership guard confirmed live** — see note |

> **Honest expectation note (\*):** the seed design assumed the assigned
> clients would read their matters, but only `8fa94af0…` holds a dev
> membership row — the other three demo accounts are not org members. The
> policy (D-MR1: `is_active_member(organization_id)` **and** assignment)
> therefore correctly denies them: **assignment alone is insufficient — the
> org-membership guard is live on the dev project**, exactly as designed
> and rehearsed (the battery's cross-org/suspended denies are the same
> branch). This is not a defect — it is the defense-in-depth the matrix
> requires, now observed on the dev project. For a fuller client-side demo,
> the owner may later add memberships for the demo client accounts — a
> deliberate, separate data action outside this slice's §3 scope.

## 4. Trigger-condition sweep (rollback_plan §5)

No trigger fired: no matrix negative row started passing (the denies held);
no cross-tenant data visible; no credential/token/PII in any output; the
narrow grant surface held (anon absent). **Rollback pairing standing by:**
`04_matters.down.sql` drops the table (and its policy dies with it; the
seeded rows go with it) — clean inverse, never fix-forward.

## 5. Ledger / state

- Applied and verified on the dev project `eutmvevpskerzpqmwplv`,
  2026-08-07, under the dated approval `0181cfa`.
- The matters table + policy + demo seed are now live; the client surface
  (plan **T7**, the env-gated `SupabaseMatterGateway`) is the next slice and
  will consume this applied posture in configured builds.
- Nothing pushed (this record + the approval land on local `main`).
