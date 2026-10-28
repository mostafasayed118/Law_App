# LegalHub — Rollback Plan (P1 precondition)

> Satisfies the "rollback plan exists for schema, policy, configuration, and
> client release" precondition in `docs/p0_decision_capture.md` §2. Still
> deliberately simple — a solo-owner project — but no longer "non-production":
> one live Supabase project now serves the dev loop **and** release builds, and
> migrations 22–31 are applied (see §1).

## 1. Schema / migrations (P2+)

- Every migration file ships with a corresponding `down` migration
  (`supabase/migrations/*_down.sql`) before it is applied.
- **Live target — one project only:** `law_project`
  (`eutmvevpskerzpqmwplv`, `eu-west-2`). It serves both the day-to-day dev
  loop and release builds. There is still **no separate staging project**
  (owner-gated; no date set).
- **Applied surface (2026-10-28):** migrations **22–31** are applied, together
  with their policy files, the full RPC surface (56 files), and the
  `paymob-reconcile` / `research-analyze` / `video-token` edge functions.
  Authoritative record: `docs/live_apply_2026-10-28_audit_followups.md`
  (preflight measurements, post-apply verification, rollback notes).
- `supabase db push` remains **forbidden**: the live project has no
  `supabase_migrations.schema_migrations` table, so the CLI cannot reconcile
  applied state and would try to replay history. Live changes go through an
  approved, recorded apply window — the Supabase Management API
  (`database/query`), as used in the 2026-10-28 record.
- Before applying: capture the read-only snapshot (every table as JSON plus
  `policies.json` / `functions.json` / `indexes.json` / `grants.json`) and
  review the exact SQL in the apply record.
- Rollback procedure: §1.1, then `flutter test` + `flutter analyze`, plus a
  manual smoke check of sign-in/sign-up/reset against the restored schema.

### 1.1 Database rollback (down migrations)

Restore the pre-22 surface by running the matching `*.down.sql` in **reverse**
order — **31 → 22** — because later migrations reference objects created by
earlier ones:

- `31_profile_display_name_and_invite_email.down.sql` restores the old
  `handle_new_user()` body. Its **backfill is not reversed**: the previous
  value was the account email address — the PII the up migration removed — so
  re-running down leaves the sanitized display names in place.
- `30_profiles_mutations_rpc_only.down.sql` → `22_attorney_directory.down.sql`
  follow in descending order. Each down file drops only what its up file
  created.
- `21_matter_creator.down.sql` is **destructive**: it drops
  `public.matters.created_by` and `matters_created_by`, permanently losing
  creator attribution. It also requires restoring the pre-21 matters policy /
  `create_matter` body first — the policy references the column, so PostgreSQL
  refuses the drop while it exists. Last resort, and owner-approved.
- The RPC surface rolls back separately via `supabase/rpc/_down.sql` (drops the
  whole surface) — not recommended while a released client expects it.
- Edge functions: redeploy the previous version from the dashboard, or delete
  `research-analyze` / `video-token`.
- **Owner-only:** executing any `*.down.sql` against the live project is an
  owner-approved apply window. Nothing here runs automatically, and CI never
  touches the database.

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
- Since Batch 3.3 the client build consumes the URL + anon key via
  `--dart-define-from-file`, and the DI flip **refuses a non-anon key**
  (`SupabaseEnv.ensureAnonKey`): a service-role key in `.env` fails fast at
  configure time rather than wiring a privileged credential into the client.
- Rollback = regenerate the local env file from `.env.example` + the actual
  dev-project values; no code change is needed to "roll back" a
  configuration mistake since nothing sensitive is in version control.
- If a wrong key is ever accidentally committed: rotate the key in the
  Supabase dashboard immediately, then scrub history if needed
  (`git filter-repo` or BFG) before any push — per `INSTRUCTIONS.md`'s
  secret-scan discipline already used in Batch 0.5 of the audit plan.
- CI generates `.env.ci` on the runner from the `SUPABASE_URL` /
  `SUPABASE_ANON_KEY` repo secrets (never committed — `.env.*` is ignored);
  when either secret is absent the release AAB step is skipped instead of
  building an artifact that throws its missing-env guard on launch. Rolling
  back a bad build environment = edit the repository secrets and re-run CI.

## 4. Client release (app rollback)

- **Distribution status:** release AABs are built and signed by the owner
  (upload keystore, outside the repo). The CI bundle is a build-only proof and
  is never uploaded; see `.github/workflows/ci.yml`. iOS has no distribution.
- **Release halt — owner-only, Play Console:**
  1. Play Console → *Test and release* → the affected track → **Pause
     rollout** (or halt the staged rollout) so no further installs/updates are
     served from that track.
  2. **Keep the previous AAB/versionCode** in the same track. Play requires an
     already-published artifact to roll back to; never delete or replace the
     prior bundle.
  3. If the defect is server-side (RLS / RPC / edge function), roll back via
     §1.1 or the function step instead — a server fix needs no client release.
  4. Re-release only after `flutter test` + `flutter analyze` are green and the
     fixed build carries a higher `versionCode`.
- **There is no remote kill switch.** The client has no runtime feature-flag or
  remote-config service; every gate is compile-time (`--dart-define`), and
  `PAYMENTS_MODE` is the only feature gate in `lib/`. A halted release is
  therefore stopped by the store rollout controls above, not by flipping a
  server flag: disabling a shipped capability requires a new build.
- Code-level rollback remains: `git revert` the batch merge commit, re-run
  `flutter test` + `flutter analyze`, confirm green.

## 5. Trigger conditions for rollback

Roll back immediately (don't "fix forward") if any of the following are
observed after a deploy to the live project or after a store rollout:

- Any negative test in `docs/permission_matrix.md` starts passing (a denial
  that should happen, doesn't).
- Any credential, token, or PII appears in logs, error reports, or audit
  records where it shouldn't (contract §2 rule 6, §8).
- Cross-tenant data becomes visible in a manual smoke test (contract §9
  tenant/membership block).

---

**Status:** drafted 2026-07-31, Project Owner. This closes the last open
item in `p0_decision_capture.md` §2 that didn't depend on external input.

**Revised 2026-10-28 (R6):** replaced the "no staging/production project, no
distribution" assumptions with the measured state — one live project
(`eutmvevpskerzpqmwplv`), migrations 22–31 applied per
`docs/live_apply_2026-10-28_audit_followups.md`, a reverse-order DB rollback
procedure (§1.1), and a Play Console release-halt procedure (§4). Owner-only
steps are marked inline; store signing, Play Console access, live DB rollback,
and the Apple Team ID all remain owner-gated.
