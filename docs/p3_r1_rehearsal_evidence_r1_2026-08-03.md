# P3 R1 — Rehearsal evidence r1 (2026-08-03)

Slice: `supabase/rpc/list_org_members_metadata.sql` (reviewed file) + `rpc/_down.sql`
drop line — per `docs/p3_r1_roster_rpc_design_2026-08-03.md` §3 and
`docs/p3_r1_rehearsal_plan_2026-08-03.md`.

## 0. Ephemeral project

| Item | Value |
|---|---|
| Project | `law-app-p3-r1-rehearsal-r1` |
| Ref | `iqmesfjgbzcczcncdbdt` |
| Org | `oouytakxadxxuykbmbof` |
| Region | Central EU (Frankfurt, `eu-central-1`) |
| Created | 2026-08-03 13:02:07 UTC |
| Deleted | 2026-08-03 (teardown complete; DB password file removed) |
| Mechanism | supabase CLI 2.109.1 + `supabase db query --linked` (Management API as `postgres`); role impersonation via `set local role authenticated` + `set_config('request.jwt.claims'/'request.jwt.claim.sub')` (P2 pattern) |
| Dev project | Untouched (`eutmvevpskerzpqmwplv`; repo `.temp` link undisturbed) |

Pre-up baseline verified: 0 tables / 0 functions / 0 policies / 0 enums.

## 1. Finding A1 — reviewed UNION ORDER BY defect (found, fixed, re-probed)

- **Symptom:** first execution of the reviewed file's function failed at runtime:
  `ERROR: 0A000: invalid UNION/INTERSECT/EXCEPT ORDER BY clause — Only result
  column names can be used, not expressions or functions`.
- **Cause:** the member branch's `null::uuid`, `null::text`,
  `coalesce(...)`, `coalesce(...)` expressions carry no output aliases, so
  `ORDER BY ... display_name, email` cannot resolve those result-column names.
  The function *creates* cleanly (PL/pgSQL defers query planning); the defect
  only surfaces on first call.
- **Fix (exactly the reviewed intent, no behavior change):** alias the
  expressions —
  `null::uuid as invitation_id, null::text as email,
  coalesce(p.display_name, '(no profile)') as display_name,
  coalesce(p.locale, 'en') as locale`.
- **Verification:** re-applied; row-1 positive probe then returned the full
  roster (7 rows) with correct column names. All subsequent matrix rows ran on
  the fixed function.
- **Classification:** NOT a trigger condition (no second RPC, no policy
  change, no data exposure — Q5 minimality intact; §5 trigger list unaffected).
  Recorded per plan §6 and the amended slice (alias lines) is what any dev
  apply must carry.

## 2. Up sequence — applied cleanly (per-step evidence)

| Step | Apply | Verified |
|---|---|---|
| 0 | Baseline: P2 slice (migrations 01–03, 6 policy files, 17 RPCs) | ✅ 6 tables / 24 functions / 5 policies / 3 enums; snapshots 1–5 captured |
| 1 | Reviewed file (with fix A1) | ✅ 18 RPCs; grant matrix: authenticated ✅ / anon ❌ / public ❌ / service_role ✅ — matches design §3 |
| 2 | Amended `rpc/_down.sql` artifact | ✅ `git diff` vs repo file = **exactly one added line** (`drop function if exists public.list_org_members_metadata(uuid);`), no other change |
| 3 | Inventory re-assert | ✅ snapshots 2–5 **byte-equal** to baseline (no table-grant / policy / default-privilege / policy-eval-grant change); snapshot 1 gained exactly the one function |

Fixtures (all synthetic `.test` identities, provisioned through the **real**
invite → accept flow with matching JWT email claims):
org-a `ef5b424d-0134-46db-84dd-c0ab9976638c`: partner/client/attorney/compliance
(active), suspended & removed (partner role, `suspended`/`removed` status),
1 pending invite. org-b `0bf551d3-ab41-4ccf-afa7-7d5a44c28239`: partner/client
(active). Owner account (no org-a membership). 8 fixture users +
owner = 9 `auth.users` rows; profiles auto-created by the signup trigger
(except owner, created pre-trigger, inserted manually).

## 3. Matrix §4 — row by row (all PASSED)

| Row | Probe | Result |
|---|---|---|
| 1 | Partner reads own org roster | ✅ 7 rows: 6 members (display_name, locale) + 1 pending invite (invitation_id, email, status `invited`) |
| 1 | Non-partner roles (client/attorney/compliance) | ✅ all 3 → `permission denied` |
| 2 | R1 extension: invitation ids | ✅ 1 invited row with invitation_id + email; 6 member rows with NULL id/email; 0 token-material values in email/display_name/locale |
| 3 | Pending-only invites | ✅ pending invite present before revoke (1), after `revoke_invitation` → 0 `invited` rows; revoked row left the roster |
| 4 | Cross-org param swap (partner@org-a, org-b id) | ✅ `permission denied` |
| 5 | Suspended partner / removed partner (both partner-role fixtures) | ✅ both → `permission denied` (stale session notwithstanding) |
| 6 | Own-row-only: client raw profiles select of partner | ✅ 0 rows |
| 7 | D-T6 pair | ✅ raw profiles select of other member → 0 rows **while** the RPC returns that member's `display_name` (`client-a`) |
| 8 | Owner without org-a membership | ✅ RPC → `permission denied`; owner's `list_members_metadata` still returns 8 rows (owner surface intact) |
| 9 | anon | ✅ denied before the guard (`permission denied for function list_org_members_metadata`) |
| 10 | Cross-org invite leakage | ✅ org-b roster: 0 invited rows; 0 org-a invites leaked |
| 11 | Generic denial, no enumeration | ✅ client, suspended, removed, owner — identical `permission denied` text |
| 12 | Orphan-membership defense (LEFT JOIN + COALESCE) | ✅ after deleting one member's `profiles` row via elevated SQL: membership still returned; `display_name` = `(no profile)`, `locale` = `en`; no uuid/email leakage in fallbacks |

Cross-cutting (all PASSED):
- R-4 canary: policy-gated roster read as active member → 6 rows; `write_audit`
  to authenticated → `permission denied for function write_audit`.
- Existing RPC spot-checks: `invite_member` minted a token (hash only);
  `accept_invitation` with wrong token → identical `invalid invitation` (no
  enumeration); `revoke_invitation` OK; `list_members_metadata` to non-owner →
  `permission denied`.
- Audit: exactly **one** `partner:list_org_members` / `allowed` row per
  successful read (delta=1 for a single read); **0** `denied` rows for the
  action.

## 4. Down sequence — rollback pairing proven

| Step | Apply | Verified |
|---|---|---|
| 1 | Amended `rpc/_down.sql` (full file) | ✅ executed cleanly; 0 slice RPCs remain; new function gone (Postgres error 42883 on call — backticks omitted so the ledger hash sweep does not misread the error code as a commit ref) — full-rollback path |
| 1′ | Pairing drop line (exactly the one added line) | ✅ 17 RPCs; `list_org_members_metadata` absent; `has_function_privilege` → false |
| 2 | Inventory re-assert | ✅ snapshots 1–4 byte-equal to §3 baseline; snapshot 5 byte-equal **after re-running the migration-02 helper grants** (blanket revoke in the full-file down removes them; baseline restores them — documented, not a slice defect) |
| 3 | Surface sanity | ✅ R-4 canary green (policy read 6 rows; `write_audit` denied); invitations policy partner=7 / client=0 rows; dropped RPC absent |

No §5 trigger condition fired at any point.

## 5. Exit criteria — rehearsal PASSED (r1)

1. ✅ Up sequence applied cleanly with per-step evidence (finding A1 recorded,
   fix applied, re-probed — never dev-ward with a failing assertion).
2. ✅ Every §4 positive row passed; every negative row denied (≥1-positive /
   ≥1-negative contract met), recorded row by row.
3. ✅ No credential, token, or PII in RPC output, audit, or logs (token-material
   probes 0/0/0).
4. ✅ No cross-tenant visibility; no policy change; no second RPC (Q5
   minimality intact — the only change is alias lines inside the single RPC).
5. ✅ Down sequence restored the §3 baseline byte-equal; no trigger fired.

**Verdict: r1 PASSED** for the amended slice (design §3 SQL + alias fix A1 +
amended `_down.sql` drop line).

## 6. Carry-forward for dev apply (NOT authorized here)

- The reviewed file, when created at apply time, must include fix A1's aliases.
- The amended `_down.sql` diff is exactly one added line (verified).
- This evidence record is the input to a separate, dated **apply approval**;
  per plan §7 nothing was applied to the dev project, nothing was pushed,
  and the working tree beyond the approved docs commit is untouched.

## 7. Apply record (2026-08-03, owner dated approval)

- Owner recorded the dated apply approval after the r1 pass; the slice
  (fix-A1 version) was applied to the dev project `eutmvevpskerzpqmwplv`.
- Verified on dev: 18 slice RPCs (17 P2 + R1); grant matrix
  authenticated ✅ / anon ❌ / public ❌ / service_role ✅ — byte-identical
  to the rehearsal's post-up state; deployed definition carries fix A1
  aliases and the `(no profile)`/`en` fallbacks; policy count unchanged (5).
- Backout in place: amended `rpc/_down.sql` drop line (exactly one added
  line, as rehearsed).
