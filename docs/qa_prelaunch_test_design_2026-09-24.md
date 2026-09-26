# LegalHub — Pre-launch QA Test Design & Coverage Analysis

**Author:** GStack QA Lead · **Date:** 2026-09-24 · **Gate:** pre-launch
**Method:** static coverage analysis (flutter test blocked on this host — see §3)

---

## Executive Summary

LegalHub carries an **unusually strong** Dart test estate: **163 files / 35,017 LOC**
(`find test -name '*.dart' | xargs wc -l`). Against a `lib/` of **16,132 LOC**
(`find lib -name '*.dart' | xargs wc -l`), of which **6,229 is generated l10n**,
hand-written `lib/` is **9,903 LOC** → a healthy **~3.5:1 test:hand-written-code**
ratio. A prior draft of this report mis-stated `lib/` as ~35k (a `cat`-based
double-count) and the brief's "16,200" was not the `features/` subtree either
(`lib/features/` is only **2,132 LOC**). Figures below are measured with `wc -l`.
The tree is well-layered (`core/ data/ features/ shared/ app/`), uses `bloc_test` +
`mocktail`, and the data layer has genuine `fake_*` ⇄ `supabase_*` parity testing
plus a separate 18-file SQL RLS battery. **This is a real strength and I confirm it.**

But the estate has **one systemic blind spot that is not a gap but a proven
defect class**: there is **zero navigation/back-stack testing** —
`grep` for `pop|maybePop|BackButton|handlePopRoute` across all 163 specs returns
**nothing**. The E2E report's **BUG-1** (system BACK exits the app from every
feature screen) shipped *precisely because* `router_test.dart` only ever calls
`router.go(...)` and never asserts back behaviour. That is a P0 launch blocker
and a P0 test gap in one.

**QA verdict: 🔴 Fail** — not on test *quantity* (which is excellent) but on
three P0 blockers: (1) broken system BACK on every feature screen, (2) the
Google/Apple buttons route to Create Account, (3) no integration/E2E tier exists
in-repo (`integration_test/` absent, SQL RLS battery not wired into CI), so the
whole class of navigation + multi-tenant real-DB behaviour is unverified.

> **Root-cause note (verified):** BUG-1 is not merely *untested* — there is
> **no pop-interception primitive in production code at all**: `grep -rE
> "PopScope|WillPopScope" lib/` → **0 matches** (and 0 in `test/`). All 19 home
> entries navigate via `context.go` (12 in `home_entry_cards.dart`, 7 in
> `home_screen.dart`) with **zero** `context.push`. The fix needs a navigation
> change (`go`→`push`) and/or a `PopScope` on the affected surfaces, not just a test.

---

## Deliverable 1 — Coverage Map & Gap Analysis

### 1a. Feature → test mapping

| Domain (`lib/features/`) | src files | test files | Status |
|---|---|---|---|
| auth | 26 | 18 | ✅ Excellent |
| matters | 33 | 9 | ✅ Good |
| notifications | 18 | 8 | ✅ Good |
| orgs | 21 | 8 | ✅ Good |
| messaging | 17 | 6 | ✅ Good |
| discovery | 12 | 5 | 🟡 OK |
| booking | 20 | 4 | 🟡 Partial |
| documents | 10 | 4 | 🟡 Partial |
| home | 10 | 4 | 🟡 Partial (no back-stack) |
| billing | 9 | 3 | 🟡 Partial |
| research | 11 | 3 | 🟡 Partial |
| video | 9 | 3 | 🟡 Partial |
| admin | 12 | 2 | 🟡 Thin |
| onboarding | 3 | 2 | ✅ OK |
| search | 5 | 2 | 🟡 Thin |
| storage | 5 | 2 | 🟡 Thin |
| **approvals** | 8 | **1** | 🔴 **Thin** |
| **compliance** | 8 | **1** | 🔴 **Thin** |
| **tasks** | 8 | **1** | 🔴 **Thin** |
| **profile** | 2 | **1** | 🟡 OK |

### 1b. Data-layer parity

Paired impls are generally covered under `*_impl_test.dart` / `*_gateway_test.dart`
(the naive "missing test" name-match is a false positive). Error-branch depth is
real: e.g. `supabase_matter_gateway_test` 14 tests, `storage_gateway` 14,
`billing_gateway` 15. **Genuine untested units:**

- `fake_auth_gateway` — the **demo-mode auth** used by env-less builds. No direct test; it is the gateway the E2E report exercised live, and its in-memory-only session is an *observation*, not a tested contract.
- `fake_approvals_gateway`, `fake_compliance_gateway`, `fake_task_gateway`, `fake_document_gateway`, `fake_matter_gateway`, `fake_message_gateway`, `fake_notification_gateway`, `fake_storage_gateway` — no dedicated fakes tests (partially exercised via cubit tests).
- `supabase_message_gateway_base` / `_messages` — split base/impl, no focused test on the base.

### 1c. Untested paths (class-level)

1. **Navigation back-stack** — 🔴 **0 specs**. Root cause of BUG-1.
2. **Integration / E2E tier** — 🔴 no `integration_test/` directory exists. E2E evidence is a manual doc, not an automated gate.
3. **SQL RLS battery** — 🟡 18 files exist in `supabase/tests/` but CI only runs `verify_policy_tests.sh --check` (static presence/FAIL-marker mode). **No live DB executes them in CI.**
4. **Real network error surfaces** — 🟡 the E2E report explicitly states demo build proves offline *resilience*, not error-state UI. 62 specs touch error types, but **no test drives a 401/403/500/timeout to a visible UI error** against the real impl.
5. **Golden / visual regression** — 🔴 none (no `*golden*`, no `.png`).
6. **RTL assertion strength** — 🟡 RTL appears in 12 widget specs, but AR layout correctness is asserted structurally, not pixel-wise; no AR screenshot baseline.
7. **Push notification deep-link** — 🟡 notification specs cover feed/read-flag; notification→route navigation is untested (and would have caught BUG-1's class).

### 1d. E2E report regression list (from `docs/e2e_live_test_report_2026-09-23.md`)

| ID | Severity | Defect | Folds into |
|---|---|---|---|
| BUG-1 | **High** | System BACK exits app from every feature screen (`context.go` not `push`) | TC-REG-01…03 |
| BUG-2 | Med-High | Google/Apple buttons open Create Account (`sign_in_screen.dart:173,181`) | TC-REG-04 |
| BUG-3 | Low | Stale validation error not cleared on edit | TC-REG-05 |
| BUG-4 | Low | Empty OTP submit gives no feedback | TC-REG-06 |
| INFRA-1 | High (artifact) | Debug APK missing `lib/x86_64/libflutter.so` → unusable on x86_64 | TC-REG-07 |

---

## Deliverable 2 — Test Checklist

Legend — **P**: 0=launch blocker · **Type**: U=unit W=widget I=integration E=E2E M=manual
**Status**: ✅ covered (spec named) · ⚠️ partial · ❌ gap

### Core functionality

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-AUTH-01 | Sign-in success → authenticated home | P0 | W | FakeAuthGateway, valid creds | enter valid email+password → submit | navigates to home, session set | ✅ `auth_cubit_test.dart` |
| TC-AUTH-02 | Sign-in wrong password | P0 | U | FakeAuthGateway rejects | submit bad creds | error shown, **stays on sign-in**, no session | ✅ `sign_in_error_test.dart` |
| TC-AUTH-03 | Sign-up field validation (empty/invalid email) | P1 | W | sign-up screen | submit empty & malformed email | inline errors, no gateway call | ✅ `sign_up_screen_test.dart` |
| TC-AUTH-04 | Sign-up duplicate email | P0 | U | gateway returns duplicate | submit existing email | "already registered"-class error surfaced | ✅ `supabase_sign_up_gateway_test.dart` |
| TC-AUTH-05 | Sign-up weak password | P1 | U | gateway rejects weak pw | submit `123` | weak-password error surfaced, not swallowed | ✅ `sign_up_cubit_test.dart` |
| TC-AUTH-06 | Forgot-password happy path | P0 | W | recovery gateway | email → OTP → reset → success | success message; reset call issued | ✅ `forgot_password_steps_test.dart` |
| TC-AUTH-07 | Session expiry mid-use | P0 | I | configured build, expired JWT | expire session → next call | user redirected to sign-in, **no crash**, no stale UI | ⚠️ `session_test.dart` (core only, no UI redirect) |
| TC-AUTH-08 | Sign-out clears state | P0 | U | signed-in cubit | `signOut()` | session null, all caches cleared | ✅ `auth_cubit_test.dart:315` |
| TC-AUTH-09 | Deep-link auth callback (invite) | P1 | W | deep-link pending store | open invite link unauthenticated | parks intent, resumes after auth | ✅ `app_link_parser_test.dart` |
| TC-AUTH-10 | Demo session not persisted (by design) | P2 | I | env-less build | sign in → force-stop → relaunch | returns to Sign In | ✅ E2E observation; add automated |
| TC-AUTH-11 | Empty OTP submit feedback | P1 | W | Verify Email screen | tap Verify with empty boxes | explicit disabled or inline error | ❌ **BUG-4** |

### Authorization / multi-tenant

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-AUTHZ-01 | Member sees own org's matters | P0 | I | two orgs, member of A | list matters | only org-A matters | ⚠️ `04_matter_rls.sql` (SQL only, not CI-run) |
| TC-AUTHZ-02 | Non-member denied another org's matter | P0 | I | user not in org B | GET matter-B by id | 403 / empty, **never leaks** | ⚠️ `04_matter_rls.sql` |
| TC-AUTHZ-03 | Role matrix member vs admin (invite/remove) | P0 | U | member & admin roles | member attempts invite/remove | denied for member, allowed for admin | ✅ `member_roster_screen_test.dart`, `permission_matrix.md` |
| TC-AUTHZ-04 | Invitation accept / expired / revoked | P0 | W | invite store seeded | accept valid, then expired, then revoked | valid→joined; expired/revoked→clear error | ✅ `accept_invitation_screen_test.dart` |
| TC-AUTHZ-05 | Platform-admin gating | P0 | W | non-admin user | open `/admin` | blocked/redirected | ✅ `platform_admin_screen_test.dart` |

### Matters & booking

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-MAT-01 | Create matter happy path | P0 | W | matter write gateway | fill form → save | matter created, list refreshed | ✅ `matter_create_screen_test.dart` |
| TC-MAT-02 | Edit matter permissions | P1 | U | non-owner client | attempt edit | save blocked with error | ⚠️ partial |
| TC-MAT-03 | Matter list empty state | P1 | W | empty gateway | open list | empty-state widget, no spinner stall | ✅ `matter_list_screen_test.dart` |
| TC-BOOK-01 | Booking wizard end-to-end | P0 | W | booking gateway | type→time→review→confirm | reference issued | ✅ `booking_screen_test.dart` |
| TC-BOOK-02 | Duplicate / conflict booking | P0 | U | slot taken | book taken slot | conflict error, no double-book | ⚠️ `booking_cubit_test.dart` (verify conflict branch) |
| TC-BOOK-03 | Cancellation | P1 | U | existing booking | cancel | status→cancelled, list updated | ⚠️ partial |

### Documents & storage

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-DOC-01 | Upload/download round-trip | P0 | U | storage gateway | upload → download | bytes match | ✅ `supabase_storage_gateway_test.dart` |
| TC-DOC-02 | Oversize file rejected | P0 | U | gateway size cap | upload > limit | rejected, clear error | ⚠️ verify size branch |
| TC-DOC-03 | Wrong MIME type | P1 | U | gateway MIME check | upload `.exe` | rejected | ⚠️ partial |
| TC-DOC-04 | Unauthorized access to doc | P0 | I | other-org user | fetch doc id | denied, no leak | ⚠️ `05_document_rls.sql` (not CI-run) |
| TC-DOC-05 | Delete document | P1 | U | owned doc | delete | removed; storage object gone | ⚠️ partial |

### Messaging

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-MSG-01 | Send message → appears in thread | P0 | W | message gateway | type → send | optimistic send, persists | ✅ `message_thread_detail_screen_test.dart` |
| TC-MSG-02 | Realtime delivery of inbound msg | P0 | U | realtime API impl | push frame | thread updated, no dup | ✅ `supabase_message_realtime_api_impl_test.dart` |
| TC-MSG-03 | Message ordering | P1 | U | out-of-order frames | deliver 3,2,1 | rendered chronological | ⚠️ partial |
| TC-MSG-04 | Offline send behaviour | P1 | I | offline | send while offline | queued/ clear failure, no silent drop | ❌ gap |
| TC-MSG-05 | Empty thread state | P2 | W | no messages | open thread | empty state, no crash | ✅ `message_list_screen_test.dart` |

### Notifications

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-NOT-01 | Push token registration | P1 | U | notification gateway | register token | token persisted once | ⚠️ verify |
| TC-NOT-02 | Read/unread flag toggle | P1 | U | feed seeded | mark read | flag persists; badge decrements | ✅ `notification_prefs_cubit_test.dart` |
| TC-NOT-03 | Notification deep-link → route | P0 | I | notification payload | tap notification | correct screen, **BACK returns home** | ❌ gap (same class as BUG-1) |

### Billing / invoices

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-BIL-01 | Invoice totals correct | P0 | U | line items | compute total | sum exact, **no float drift** | ✅ `billing_gateway_test.dart` |
| TC-BIL-02 | Currency / rounding | P0 | U | multi-currency fixtures | compute | correct currency symbol & rounding | ⚠️ verify rounding branch |
| TC-BIL-03 | Permission to view invoices | P0 | I | client vs admin | open billing | role-gated correctly | ⚠️ `11_invoice_rls.sql` (not CI-run) |

### Network / error paths

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-NET-01 | No connectivity | P0 | I | connectivity off | trigger fetch | visible error + retry, **not a spinner forever** | ❌ gap (E2E admits untested) |
| TC-NET-02 | 401 → re-auth | P0 | I | expired token stub | call API | redirect to sign-in, no crash | ⚠️ core only |
| TC-NET-03 | 403 surfaced | P0 | I | forbidden stub | call API | permission error shown | ⚠️ partial |
| TC-NET-04 | 500 / server error | P0 | I | 500 stub | call API | error surfaced, retry available | ✅ `app_centered_retry_test.dart` (widget) / ⚠️ not end-to-end |
| TC-NET-05 | Timeout + retry | P1 | U | delayed stub | exceed timeout | timeout error, retry succeeds | ⚠️ partial |
| TC-NET-06 | Malformed response | P1 | U | bad JSON | parse | `AppError` raised, no crash | ✅ `app_error_test.dart` |

### Localization / RTL

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-L10N-01 | EN/AR/TR key completeness | P0 | U | 3 ARB files | load locales | all keys present, no EN fallback silent-copy | ✅ `app_localizations_test.dart` |
| TC-L10N-02 | AR RTL layout mirroring | P0 | W | AR locale | render nav/rows | tab order mirrored, icons directional | ✅ `directional_icon_test.dart` + E2E pass |
| TC-L10N-03 | TR not a silent EN copy | P1 | U | TR locale | compare shared keys | values differ from EN | ✅ `app_localizations_test.dart` |

### List rendering & widget-identity (raised by product-reviewer CR-02/CR-03)

Verified against source: the **shared server-collection renderer is already lazy** —
`view_state_list.dart:161` → `_SuccessListView` → `ListView.builder`
(`view_state_success_list.dart:29`). The three screens flagged as growing-collection
risks are each already lazy: `member_roster_screen.dart:82` (`ListView.separated`),
`platform_admin_lists.dart:48` (`ListView.builder`), `attorney_search_surface.dart:61`
(`ViewStateList`). The 21 non-builder `ListView(` sites are bounded form/settings
surfaces. **CR-03 eager-build risk: not substantiated.** CR-02 (unkeyed loops) **is**
real — `_MemberRow` has no `key:`, and there are **zero list-mutation specs** in
orgs/admin.

| ID | Scenario | P | Type | Preconditions | Steps | Expected | Status |
|---|---|---|---|---|---|---|---|
| TC-LST-01 | Growing roster renders lazily | P1 | W | 500 members seeded | open roster | only visible rows built; no jank/all-children build | ⚠️ no scale test |
| TC-LST-02 | Roster insert → no child state bleed | P1 | W | roster with row-scoped state (pending flag) | insert member at head, pump | existing rows keep own state; no keyed-collision bleed | ❌ gap (CR-02) |
| TC-LST-03 | Roster remove → correct row removed | P1 | W | 3 members | remove middle member | correct row gone; remaining rows intact | ❌ gap |
| TC-LST-04 | Admin audit rows on insert/reorder | P2 | W | orgs list | insert org at head, pump | audit rows correspond to new order, no bleed | ❌ gap (CR-02) |
| TC-LST-05 | `mounted`-after-await guards hold | P1 | U | slow gateway | dispose screen mid-fetch | no "setState after dispose"; no crash | ⚠️ partial (static guards present, unasserted) |

### Regression (from E2E report)

| ID | Scenario | P | Type | Steps | Expected | Status |
|---|---|---|---|---|---|---|
| TC-REG-01 | **BUG-1** BACK from every feature screen | P0 | W | from Home open Messages → system BACK | returns to **Home**, not exit | ❌ **gap — root cause of BUG-1** |
| TC-REG-02 | BUG-1 coverage across all 19 home entries | P0 | W | iterate 12+7 entries, BACK each | all return Home | ❌ gap |
| TC-REG-03 | Bottom-nav `go` still replaces correctly | P1 | W | tap bottom tabs | tab nav unaffected by push fix | ⚠️ `router_test.dart` (go only) |
| TC-REG-04 | **BUG-2** Google/Apple buttons | P0 | W | tap Google, tap Apple | correct flow **or** honest disabled state | ❌ gap |
| TC-REG-05 | **BUG-3** stale validation error clears | P1 | W | mismatch → submit → correct both | error clears on edit | ❌ gap |
| TC-REG-06 | **BUG-4** empty OTP feedback | P1 | W | empty boxes → Verify | explicit disabled or error | ❌ gap |
| TC-REG-07 | **INFRA-1** debug APK x86_64 ABI | P1 | M | build debug APK, inspect `lib/x86_64/` | `libflutter.so` present, launches | ❌ gap (CI artifact) |

---

## Deliverable 3 — Verification Summary

**Executed vs static.** I attempted the suite once with the documented invocation.
It failed with the known host fault — `ProcessException: All pipe instances are
busy (OS error 231)` (crash report `flutter_09.log`), the same constraint the
2026-09-23 E2E report records. **I did not retry.** Everything above is **static
coverage analysis** (file inventory, grep-verified test presence, spec reads).
The "1426 executed / 1423 tracked" figure is corroborated by
`README.md:24,413` and `docs/audit/LegalHub_AUDIT_2026-09-21.md:949,951`; I
verified the *declaration* estate (163 files) but **cannot independently confirm
1426 green from this host.**

**Infrastructure quality — genuinely good.**
- Clean layering; fakes are first-class (`lib/**/fake_*` ~25 files) and used as
  the demo data source, so fakes are exercised by the app itself.
- `service_locator_test.dart` + `bootstrap_boundaries_test.dart` guard wiring.
- RLS battery (`supabase/tests/`, 18 files) mirrors all sensitive tables; the
  `verify_policy_tests.sh --check` static gate validates fixture UUIDs and FAIL
  markers. **Strong.**
- `bloc_test` + `mocktail` used consistently; error taxonomy `AppError` tested.
- **Flaky-risk:** low — mostly pure unit/widget; realtime and timeout tests
  (`supabase_message_realtime_api_impl_test`, TC-NET-05) are the only async-timing
  candidates; review for `Future.delayed` reliance.

**Blocking test gaps (untested P0 paths):**
1. **Navigation back-stack — zero specs.** Directly caused shipped BUG-1.
2. **No integration/E2E tier in-repo.** `integration_test/` absent; SQL RLS never executed in CI.
3. **Real error-state UI untested** (401/403/500/timeout → visible UI).
4. **Notification → deep-link navigation** untested (same class as #1).
5. **Debug-APK artifact integrity** unguarded (INFRA-1).

**Recommended additions:** golden tests for AR (RTL) home, retry-widget E2E for
TC-NET-01, an automated regression spec for BUG-4, list-mutation/identity specs
(TC-LST-02…04), and a CI job that runs the RLS battery against an ephemeral
Postgres.

**QA verdict: 🔴 Fail.** Test *volume* and *unit-layer discipline* are excellent
and above typical bar. The failure is narrow and fixable: five P0 gaps, three of
which are already proven live defects, and one of which (BACK navigation) the
estate's shape made inevitable. **Remediate the five gaps, ship BUG-1/2 fixes,
then re-verify → expected 🟡 Pass with Remediation.**

### Prioritised action items

1. **P0 — add back-stack widget tests** (TC-REG-01/02) and fix BUG-1 (`go`→`push` on home entries).
2. **P0 — fix BUG-2** (Google/Apple buttons) + add TC-REG-04.
3. **P0 — add an `integration_test/` tier** covering 401/403/500/timeout → UI error.
4. **P1 — run the SQL RLS battery in CI** against ephemeral Postgres.
5. **P1 — add notification deep-link test** (TC-NOT-03); regression specs for BUG-3/4.
6. **P1 — guard INFRA-1**: CI assert `lib/x86_64/libflutter.so` in debug APK.
