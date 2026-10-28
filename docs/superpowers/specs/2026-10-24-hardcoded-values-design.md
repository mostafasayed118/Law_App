# Hardcoded Values Remediation — Design

- **Status:** approved in chat 2026-10-24 (architecture, waves, verification). Not committed.
- **Repo:** `C:\flutter_projects\law_app` (LegalHub, Flutter 3.x, feature-first Clean Architecture).
- **Scope owner decision:** "Everything, including cosmetics."
- **Baseline:** 450 Dart files / ~49.7k lines. Suite size claimed 1924 in README; the real count is measured at implementation start and treated as the baseline.

## 1. Problem

A five-agent read-only census (2026-10-24) found that most visual values are
already tokenized, but hardcoded values remain in six areas: motion/cosmetic
one-offs, configuration and wire names, domain limits and timeouts, user-facing
failure copy, and demo data that can reach configured builds. Two of these are
correctness issues, not cosmetics:

1. The deep-link parser hardcodes the production scheme (`com.legalhub.app`)
   while dev builds register `com.legalhub.app.dev`; dev accept/recovery links
   cannot classify correctly.
2. The home "Recent Activity" fixture renders unconditionally in every build,
   including configured/production builds.

Project rule `INSTRUCTIONS.md` §4.5 already requires theme tokens and
localizable user-facing strings, so this work is rule enforcement, not a new
policy.

## 2. Scope

**In scope**

- Theme/motion cosmetic extraction; component-local named constants.
- User-facing literal strings (failure-copy inventory: 175 census; 161
  occurrences / 127 distinct measured at baseline) → ARB keys, EN/AR/TR, with
  review flags.
- Config: URLs, deep-link scheme/host/path, env templates.
- Supabase wire names: tables, buckets, RPCs, edge functions.
- Timeouts, server-mirrored length caps, pagination constants, domain enums,
  MIME/extensions, locale list, role mapping, SQLSTATE/HTTP codes.
- Demo corpus centralization and posture gating.

**Out of scope**

- Pagination UI or new `p_offset` plumbing (flagged follow-up).
- Live Supabase changes, RLS, migrations, edge-function deploys.
- Native Android/iOS identifier dedupe (duplicated by necessity).
- Generated `lib/l10n/app_localizations*.dart`.
- Commits/pushes (per-wave GO required).
- Secret rotation (no committed secrets were found; `.env` files are untracked).

## 3. Constant architecture

No junk drawer. Each value goes to the narrowest canonical home. Component-only
values become `static const` in the owning widget file.

| Home | Owns |
|---|---|
| `lib/app/legalhub_theme.dart` | existing `space*`/`radius*`/`margin*` tokens; add `space2xs = 2`, `radius2xl = 24` |
| `lib/app/legalhub_motion.dart` (new) | `durationFast = 200ms`, `durationBase = 300ms`, `debounce = 300ms`, `curveStandard = Curves.easeOut` |
| `lib/core/contracts/server_limits.dart` (new) | `kTitleMaxLength = 160`, `kDescriptionMaxLength = 4000`, `kDecisionNoteMaxLength = 2000`, `kAttorneyNameMaxLength = 120`, `kAttorneyBioMaxLength = 2000`, `kBookingTopicMaxLength = 2000`, `kResearchFindingsMax = 12` |
| `lib/core/pagination.dart` (new) | `kSearchPageSize = 30`, `kListRowCap = 200` (data guard re-exports, no duplicate) |
| `lib/data/supabase_wire.dart` (new) | `SupabaseTables` (10 names), `SupabaseBuckets` (`matter-files`), `SupabaseRpcs` (48 names), `SupabaseEdgeFunctions` (3 names) |
| `lib/data/supabase_seam.dart` | single `kSupabaseRequestTimeout` used by RPC/table/storage **and** all three `functions.invoke` call sites |
| `lib/core/errors/app_message_key.dart` (new) | `AppMessageKey` enum, one value per distinct failure literal; placeholder args for interpolated copy |
| `lib/l10n/app_message_l10n.dart` (new) | exhaustive `appMessage(AppLocalizations, AppMessageKey, args)` switch |
| `lib/app/deep_link/` | one scheme/host/path holder fed by `AppConfig.deepLinkScheme`; parser and auth callback consume it |
| `lib/shared/demo/demo_corpus.dart` (new) | demo org/user/attorney/matter IDs and titles; imported only by fakes and tests |
| Feature domain files | `ApprovalStatus` wire mapper, `AuditOutcome`, signed-URL TTL, payment poll constants, MIME + extensions, research wire codes, role reverse mapper |
| `.env*.example` | document `PAYMENTS_MODE`; remove dead `API_BASE_URL` after test-wide consumer check |

**Refusals**

- Single-site RPC names are still constants per the owner's "everything" scope,
  but generated in one file, not scattered.
- One-off avatar/OTP/illustration dimensions stay `static const` in their
  widget; they are not global design tokens.
- `Colors.transparent` stays: it is semantic, not a palette value.

## 4. Delivery: Wave 0 + five code waves + close-out

Branch `refactor/hardcoded-values` in an isolated worktree. No commits without
per-wave GO. Subagents receive exclusive file ownership per wave; the parent
verifies every report at source.

### Wave 0 — Inventory and baseline

- Write `docs/hardcoded_values_inventory_2026-10-24.md`: every finding with
  `file:line`, literal, category, verdict (`extract` / `component-local` /
  `leave`), wave, and status.
- Measure the real baseline: `flutter analyze`, full `flutter test`, test count.
- If the baseline is red, stop and report.

### Wave 1 — Theme and motion cosmetics

- Add `LegalHubMotion`, `space2xs`, `radius2xl`.
- Replace UI motion literals (200/300 ms, `easeOut`, 300 ms debounce).
- Swap one-off spacing/radius literals that exactly match existing tokens
  (2/4/6/8/12).
- Name component-local dimensions (`static const`): avatars 40, OTP 56,
  onboarding art 240, card 160x192, max widths 520/360/320.
- Reuse `AppSectionHeader` instead of the repeated `titleSmall + w700` header
  style only where it is pixel-equivalent; otherwise keep the local style and
  name it.
- No visual change (golden/widget tests must confirm).

### Wave 2 — Config and wire names

- Add `SupabaseTables`, `SupabaseBuckets`, `SupabaseRpcs`,
  `SupabaseEdgeFunctions`; replace 19 table sites, 3 bucket sites, 48 named
  RPCs across 51 call sites, 3 edge-function sites, and the realtime
  `public/messages` topic.
- One `kSupabaseRequestTimeout`; remove 7 duplicated `Duration(seconds: 15)`.
- Add the missing timeout to `functions.invoke` in video, payment, research.
- Centralize deep-link scheme/host/path; `AppLinkParser` and
  `AuthCallbackUri` read the configured scheme. Production values unchanged.
- Add `PAYMENTS_MODE` to env templates. Remove `API_BASE_URL` if a test-wide
  grep confirms zero consumers; otherwise document and keep.

### Wave 3 — Domain contracts and correctness

- Add `server_limits.dart` and wire:
  - approval title 160 / description 4000 / decision note 2000;
  - compliance copies;
  - attorney headline 160 / city 120 / bio 2000;
  - booking topic 2000;
  - research findings 12.
- Add the two missing client caps: attorney `display_name` 120 and booking
  topic 2000.
- `ApprovalStatus` gets public `toWire`/`fromWire`; `denied → rejected` lives
  in one place. Today's writes are already correct; this prevents a future
  `.name` write from violating the DB CHECK.
- `kSearchPageSize`, `kListRowCap`; data guard re-exports the same constant.
  No pagination UI; `p_offset` remains a follow-up.
- SQLSTATE/HTTP constants and one shared status mapper.
- Research wire error codes enum with explicit unknown-code fallback.
- `AuditOutcome` enum.
- Signed-URL TTL, payment poll intervals, MIME + extensions, locale list,
  role reverse mapping: one canonical source each.
- `PAYMENTS_MODE` behavior unchanged.

### Wave 4 — Failure copy localization

- Deduplicate the measured failure-copy set (161 occurrences / 127 distinct at
  baseline; the census 175 was not reproducible) by exact literal.
- Add `AppMessageKey`; `AppError` gains `messageKey` + optional placeholder
  args, retaining the English `userMessage` for logs and tests.
- Add one ARB key per distinct literal in `app_en.arb`, `app_ar.arb`,
  `app_tr.arb`; AR/TR entries carry
  `"description": "[REVIEW] machine-drafted; human review required before release"`.
- Write `docs/l10n/translation_review_2026-10-24.md` listing every key and its
  EN/AR/TR copy.
- Presentation resolves through the exhaustive mapper; raw `userMessage` is
  never rendered.
- Regenerate with `flutter gen-l10n`; never hand-edit generated files.

### Wave 5 — Demo corpus and posture gating

- `DemoCorpus` centralizes demo org/user/attorney/matter IDs and titles; fix
  the `demo-org` vs `org-demo` drift and the six duplicated matter-title maps.
- Gate home "Recent Activity" on `backendIsLocalOnly`; configured builds get
  an honest empty state, not fake cases.
- Make demo-label helpers posture-aware; configured rows pass through server
  values. This fixes the latent "Demo notification — …" mislabel.
- Gate unconditional demo copy: search notes, home entry subtitles, research
  no-match.
- Move the 30 rendered untranslated demo values into the localized/gated path.
- Update fixture-pinned tests by import/expectation only; assertions keep
  their strength.

### Wave 6 — Close-out

- `flutter analyze` (zero errors), full `flutter test`, `dart format` check on
  touched files.
- Reconcile the inventory doc and README/ledger test count.
- Full diff review with the owner; no commit until explicit GO.

## 5. Behavior changes (each proven by a test)

1. Dev deep links classify and open with `com.legalhub.app.dev`; dev invite
   share links and recovery email links target the configured scheme;
   production is unchanged.
2. A stalled edge-function call fails after `kSupabaseRequestTimeout` instead
   of hanging.
3. Attorney display name >120 and booking topic >2000 are rejected client-side
   instead of round-tripping to a server validation error.
4. Failure copy renders in the active locale (EN/AR/TR) instead of raw English.
5. Configured builds no longer show the fake Recent Activity fixture or demo
   notification copy.
6. Unknown research wire codes map to an explicit localized unavailable state
   instead of silently falling back to generic copy.

Approval wire mapping is behavior-preserving today and listed as hardening, not
a behavior change.

## 6. Verification

Per wave, in order:

1. `flutter analyze` — zero errors.
2. Targeted `flutter test <touched areas>`.
3. Full `flutter test`; compare against the Wave 0 baseline and explain every
   count delta.
4. `dart format --output=none --set-exit-if-changed` on touched files.
5. Stage new files with `git add` so count/ledger scripts can see them. No
   commit.

New tests:

- deep-link dev/prod parse and accept/recovery URI;
- `ApprovalStatus` wire round-trip;
- server-limit boundaries;
- `AppMessageKey` completeness and EN/AR/TR non-empty parity;
- configured-posture demo gating;
- edge-function timeout with a delayed fake client.

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| ~127×3 machine-drafted translations | `[REVIEW]` metadata + review doc + explicit release gate |
| Large cross-cutting diff | isolated worktree, wave-scoped subagent ownership, parent source verification |
| 46 fixture-pinned test files | imports/expectations only; no assertion weakening |
| Generated l10n files edited by mistake | regenerate via `flutter gen-l10n`; generated paths are read-only |
| Untracked files invisible to git-grep gates | `git add` new files before count checks |
| Behavior change is unwanted | each change isolated to its wave and revertable |

## 8. Acceptance criteria

- [ ] Inventory covers every category in §3 with a verdict and status.
- [ ] Zero raw literals remain in targeted categories outside their canonical
      homes.
- [ ] `flutter analyze` clean; full suite green; count delta explained.
- [ ] All six behavior changes have a dedicated passing test.
- [ ] AR/TR review doc exists and every generated key is marked `[REVIEW]`.
- [ ] Configured-build smoke test shows no demo fixture/labels.
- [ ] No commit, push, deploy, or live Supabase change occurred.

## 9. Source evidence (verified 2026-10-24)

- `lib/app/deep_link/app_link_parser.dart:55,89,104` hardcodes
  `com.legalhub.app`; `lib/app/flavor.dart:145` exposes
  `deepLinkScheme => applicationId`; `lib/data/auth/auth_callback.dart:23,31,49`
  duplicates scheme/host. Parser never reads the config.
- `lib/data/video/supabase_video_api_impl.dart:41`,
  `lib/data/billing/supabase_payment_api_impl.dart:24`,
  `lib/data/research/supabase_research_api_impl.dart:42` call
  `functions.invoke` with no timeout.
- `lib/data/supabase_seam.dart:41,53` hardcode `Duration(seconds: 15)`.
- `lib/features/home/presentation/home_screen.dart:95` renders
  `_homeActivityCards(context)` unconditionally; the class comment calls the
  content deterministic sample fixtures.
- `lib/shared/demo_labels.dart` maps known demo values by shared wire `type`
  and has no posture parameter; `backendIsLocalOnly` is used in the
  notification feed screen but not in the label helpers.
- `lib/data/approvals/supabase_approval_gateway.dart` maps
  `ApprovalStatus.denied → 'rejected'` in a private helper; `decide` writes raw
  `'approved'/'rejected'`.
- `apiBaseUrl` appears only in `lib/app/flavor.dart`; no Dart consumer.
- Census counts: 53 raw color matches (all theme definitions except one
  `Colors.transparent`), 24 `Duration(` matches (7 UI, rest network/fixtures),
  533 spacing matches (~97% already tokens), 10 tables/19 sites, 48 RPCs/51
  sites, 3 buckets/3 sites, 3 edge functions, 161 measured failure-copy
  occurrences / 127 distinct (census 175), 46 fixture-pinned test files.
