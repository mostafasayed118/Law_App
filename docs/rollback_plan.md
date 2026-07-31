# LegalHub — Rollback Plan (P1 precondition)

> Satisfies the "rollback plan exists for schema, policy, configuration, and
> client release" precondition in `docs/p0_decision_capture.md` §2. Kept
> deliberately simple — this is a solo-developer, non-production, synthetic-
> data project (see `p0_decision_capture.md` header context).

## 1. Schema / migrations (P2+)

- Every migration file ships with a corresponding `down` migration (or, if
  using Supabase's migration tooling, a paired revert script) before it is
  applied to the dev project.
- Migrations are applied to the **non-production dev project only**. There
  is no staging/production Supabase project yet — that decision is deferred
  until P4.
- Before applying a migration: `supabase db diff` (or equivalent) is
  reviewed and pasted into the PR/commit description.
- Rollback procedure: run the paired `down` migration against the dev
  project; verify with `flutter test` + a manual smoke check of sign-in/
  sign-up/reset against the restored schema.

## 2. RLS / storage / RPC policies (P2+)

- Policies are version-controlled as SQL files alongside migrations (not
  edited ad hoc via the Supabase dashboard) so a policy change is a
  reviewable diff with a revert path (`git revert` + re-apply the prior
  policy file).
- Every policy change is validated against `docs/permission_matrix.md`
  before and after applying — if a negative-test row starts passing when it
  shouldn't, revert immediately.

## 3. Client configuration (env / dart-define)

- `.env` (or equivalent dart-define file) holding the Supabase URL + anon
  key is **git-ignored**, never committed. `.env.example` stays name-only
  with empty values (existing project convention, bootstrap spec §4.6).
- Rollback = regenerate the local env file from `.env.example` + the actual
  dev-project values; no code change is needed to "roll back" a
  configuration mistake since nothing sensitive is in version control.
- If a wrong key is ever accidentally committed: rotate the key in the
  Supabase dashboard immediately, then scrub history if needed
  (`git filter-repo` or BFG) before any push — per `INSTRUCTIONS.md`'s
  secret-scan discipline already used in Batch 0.5 of the audit plan.

## 4. Client release (app rollback)

- No production app distribution exists yet (P4 is not authorized). Until
  then, "release rollback" means: `git revert` the merge commit for the
  batch/slice, re-run `flutter test` + `flutter analyze`, confirm green.
- Once P4 introduces real distribution, this section will be revised to
  cover store rollback / staged rollout halt — not needed before then.

## 5. Trigger conditions for rollback

Roll back immediately (don't "fix forward") if any of the following are
observed after a P2+ deploy to the dev project:

- Any negative test in `docs/permission_matrix.md` starts passing (a denial
  that should happen, doesn't).
- Any credential, token, or PII appears in logs, error reports, or audit
  records where it shouldn't (contract §2 rule 6, §8).
- Cross-tenant data becomes visible in a manual smoke test (contract §9
  tenant/membership block).

---

**Status:** drafted 2026-07-31, Project Owner. This closes the last open
item in `p0_decision_capture.md` §2 that didn't depend on external input.
