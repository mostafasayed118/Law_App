# LegalHub — Screen-Completeness Matrix (Consumable Record, 2026-08-09)

> **Record type:** Persisted output of the screen-completeness audit run on
> 2026-08-09 (read-only; grounded in doc reads, `lib/` globs, and git facts —
> no invented screens). Status date: **2026-08-09, `origin/main` @ `b7325f8`**
> (the v1-queue slice landed; suite 1127, ledger PASS 115/115).
>
> **Method:** every screen named or described in
> `docs/legalhub_specification.md` (§4 MVP / v1 / §6 remediation rows),
> `docs/legalhub_bootstrap_specification.md` (B1–B13), the roadmap
> (`docs/features_roadmap_2026-08-03.md`) Phase 1–12 and the §14
> un-deferrals, plus the 2026-08-09 v1 scope drafts — is matched against the
> actual presentation surface (`lib/features/*/presentation/*_screen.dart`)
> and git state (`git status` clean at `b7325f8`, pushed to `origin/main`).
>
> **Status vocabulary:** DONE_COMMITTED (built + tested + committed + pushed,
> with a test file present) · PARTIAL (built but not the designed shape, or
> only a section/reuse) · DEFERRED_PHASE (assigned to a later phase, cited) ·
> DEFERRED_DECIDED (explicit owner decision cited) · OUT_OF_SCOPE_MVP (cited
> scope line) · NOT_STARTED (designed, no decision — the gap list).
>
> **Verification basis:** 30 `*_screen.dart` files under
> `lib/features/**/presentation/`; full gate stack green on the record
> commit: `dart format` clean · `flutter analyze` 0 issues · `flutter test`
> **1127 pass** · `scripts/verify_ledger.sh` **PASS 115/0/0** (README suite
> count 1124 in lockstep).

---

## 1. Designed-by-document screens

| Screen (designed) | Spec source | Status as of 2026-08-09 | Evidence |
|---|---|---|---|
| sign_in | legalhub §6:148; P3.1 | DONE_COMMITTED | `sign_in_screen.dart`; `sign_in_screen_test.dart` |
| sign_up | legalhub §6:148; P3.1 | DONE_COMMITTED | `sign_up_screen.dart`; `sign_up_screen_test.dart`; check-inbox state (roadmap 4.2) |
| forgot_password_email_recovery / otp_verification / reset_password | legalhub §6:149 | DONE_COMMITTED | `forgot_password_{email,otp,reset}_screen.dart`; steps + threading tests |
| onboarding / onboarding_success | legalhub §6:150; LBS B13 | DONE_COMMITTED | `onboarding_screen.dart`, `onboarding_success_screen.dart`; tests present |
| home_dashboard | legalhub §6:151; roadmap 11 (D-S4) | DONE_COMMITTED | `home_screen.dart`; `home_screen_test.dart`, `home_cards_test.dart` |
| attorney_search / attorney_profile | legalhub §6:152; Phase 6 | DONE_COMMITTED | `attorney_search_screen.dart`, `attorney_profile_screen.dart`; tests |
| consultation_type – booking_success (4 steps) | legalhub §6:153; Phase 5 (D-B1..D-B7) | DONE_COMMITTED | `booking_screen.dart`; `booking_screen_test.dart`, `booking_cubit_test.dart` |
| message_center / matter_discussion | legalhub §6:154; Phase 9 + §14 read | DONE_COMMITTED | `message_list_screen.dart`, `message_thread_detail_screen.dart`; tests |
| document_vault | legalhub §6:155; Phase 8 + §14 read | DONE_COMMITTED | `document_list_screen.dart`; tests |
| case_management_dashboard / case_details / shared_case_workspace | legalhub §6:156; Phase 7/10 | DONE_COMMITTED | `matter_list_screen.dart`, `matter_details_screen.dart` (incl. sections); tests |
| user_profile / settings_localization | legalhub §6:157 | DONE_COMMITTED | `profile_screen.dart`, `settings_screen.dart`; tests |
| notification_settings | legalhub §6:157 | DONE_COMMITTED | `notification_settings_screen.dart`; test |
| partner_notification_settings | legalhub §6:157 | **DECIDED CLOSED** — D-T7 (2026-08-09): satisfied by shared screen; no duplicate | `tracked_deviations.md` D-T7; spec row cité |
| billing_invoices | legalhub §6:158; D-11 | DONE_COMMITTED (2026-08-09, `f4396cf`) | `billing_invoices_screen.dart`; `billing_invoices_screen_test.dart` |
| video_consultation | legalhub §6:159; v1 | DEFERRED_PHASE (v1; D-15 open) | no screen |
| collaboration_task_board | legalhub §6:160; v1 | **DONE_COMMITTED demo** (2026-08-09, `b7325f8`) | `task_board_screen.dart`; `task_board_screen_test.dart` |
| pending_approvals_queue | legalhub §6:160; v1 | **DONE_COMMITTED demo** (2026-08-09) | `approvals_screen.dart`; `approvals_screen_test.dart` |
| compliance_alerts | legalhub §6:168; v1 read-only | **DONE_COMMITTED demo** (2026-08-09) | `compliance_alerts_screen.dart`; `compliance_alerts_screen_test.dart` |
| conflict_check_search / disclosure_* / report / resolution dashboards / analytics / alerts | legalhub §6:161–163 | DEFERRED_DECIDED (D-03/D-06, spec §4 lines 62–63) | no screen |
| request_conflict_waiver / waiver_approval_detail / waiver_status | legalhub §6:164 | DEFERRED_DECIDED (D-06) | no screen |
| resolution_action_ethical_wall / take_action_conflict_resolution | legalhub §6:165 | DEFERRED_DECIDED (D-06) | no screen |
| regulatory_filings_dashboard / filing_submission_workspace | legalhub §6:166 | DEFERRED_DECIDED (D-03 + provider) | no screen |
| legal_research_ai_assistant / citation / statutory browser / draft / library | legalhub §6:167 | DEFERRED_DECIDED (D-07/D-08; §14 AI-only path) | no screen |
| global_compliance_map / risk_dashboard / advanced_analytics | legalhub §6:169 | DEFERRED_DECIDED (D-03 + validated data) | no screen |

## 2. Roadmap / post-P0 additions (not in the §6 mockup set)

| Surface | Source | Status | Evidence |
|---|---|---|---|
| org hub + create-org + roster + invite sheet | P3 spec; roadmap P1 (slices 1.1–1.6) | DONE_COMMITTED | `orgs/presentation/*` (4 screens + sheet); org_cubit-etc tests |
| accept-invitation (paste + deep link) | P3.4; roadmap 2.4/4.1 D-P34.2 | DONE_COMMITTED | `accept_invitation_screen.dart` + `app/deep_link/*`; tests |
| platform admin (orgs/members/audit) | P3.5 + §13 under-deferrals | DONE_COMMITTED | `platform_admin_screen.dart` + `_AuditSection`; tests |
| **org audit (partner)** | `partner_org_audit_scope_2026-08-09.md` (2026-08-09) | DONE_COMMITTED (`eab0736`/`b7380d2`) | `org_audit_screen.dart` + `/organizations/audit`; tests |
| message read/thread detail (+ composer) | §14 realtime + send | DONE_COMMITTED | `message_thread_detail_screen.dart`; tests |

## 3. Summary counts (2026-08-09, @ `b7325f8`)

| Status | Count |
|---|---|
| DONE_COMMITTED | **30** `*_screen.dart` in `lib/features/**/presentation/`, each with a committed test file |
| PARTIAL | 0 |
| NOT_STARTED | 0 |
| DONE_WIP (uncommitted) | 0 |
| DEFERRED_PHASE | video (v1, D-15 open) |
| DEFERRED_DECIDED | 8 groups (conflicts, waivers, walls, filings, research/AI, citations, compliance map/risk/analytics) |
| OUT_OF_SCOPE_MVP | inert home practice-area cards + notification bell (D-S4) |

## 4. Gap list (designed, no blocking decision, no build) — **EMPTY 2026-08-09**

Closed entries: `partner_notification_settings` → D-T7; `org_audit_screen` and
`billing_invoices_screen` shipped; the three v1 queue demo surfaces shipped
(2026-08-09). **Every designed line now has a status and an evidence anchor.**

## 5. Screens claimed built but missing tests — **NONE**

Each `*_screen.dart` has a test file in `test/features/**` (list maintained in
the audit record; suite 1127 pass).

## 6. Open (owner-side) items NOT blocking the matrix

- Supabase console **Redirect URL** (`com.legalhub.app://auth/v1/callback`) — deep-link recovery inactive until added (owner action; roadmap 4.1 R1).
- `docs/p0_decision_capture.md` §3 **P4 row** (security review + controlled rollout) — BLOCKED / owner OPEN.
- **D-45.1 provider-loop Phase 2** dev-project smoke — needs a controlled inbox.
- The three v1 demo surfaces' *real-data* path (server table + RLS + matrix addendum vs demo-only） — one dated owner decision per surface.
- AR/TR copy semantic pass for the 2026-08-09 strings (native-speaker review).

---

# Addenda — appended after 2026-08-09

> Addenda preserve the original 2026-08-09 record; new dated sections record
> changes that do not invalidate the snapshot above.

## A1. Screen count and suite size as of 2026-09-23 (audit §12.14)

**Tree state.** Same `main` branch, tracked tree clean post-extraction slice
(audit doc §12.14 / the same commit; see `git log --oneline -1` for the
commit hash). The slice is a pure readability split — every modified
`<feature>_screen.dart` gained `part '<name>_*.dart';` references and lost its
private widget class; no route, no screen name, no public widget signature
changed.

| Status | Count |
|---|---|
| `*_screen.dart` in `lib/features/**/presentation/` | **33** (unchanged) |
| new extracted-widget files under `lib/` (86 `part of` extracts — `*_tile/_surface/_body/_state/_row/…` — + 7 standalone widget extractions) | **93** — extracted widgets; not screens; do not double-count |
| Test count (per `README.md:377` and `verify_ledger.sh` PASS row) | **1400** (was 1127 at the 2026-08-09 snapshot) |
| Full suite green on the landing commit | `flutter analyze` No issues · `flutter test` +1400 · `verify_ledger.sh` PASS 115/0/0 |

The historical "30 screens / suite 1127" record at the head of this document
is **frozen at 2026-08-09 / `b7325f8`** by design (the §1 status vocabulary
treats that commit as the audit's reference point). Subsequent additions and
the suite growth are tracked in the feature-slice completion evidence files
under `docs/` and the README's coverage paragraph (line 377 onwards).

**What changed vs the frozen record:**

- `notification_feed_screen.dart` and `notification_settings_screen.dart`
  shipped after the freeze (notification-feed slice).
- `ai_research_screen.dart` shipped 2026-09-02 (`235003f`).
- `attorney_profile_screen.dart` was the read-only profile view; the discovery
  refactor reorganized the package around 2026-08-11.
- `accept_invitation_screen.dart` was added by the P3.4 deep-link slice.
- `organization_hub_screen.dart` and `org_audit_screen.dart` were added by
  the org-hub + partner-audit slices.
- `member_roster_screen.dart` was promoted to a dedicated route from a
  sheet, post-freeze.
- `booking_screen.dart` added a `success_step` post-freeze; the screen count
  is unchanged.

**What the extraction slice did NOT change:** the screen count (33 still
matches the post-freeze reality), the route table (`lib/app/router.dart`'s
`AppRoutes` constants), and the surface area exposed to widget tests. The 94
new `part` files are private sub-widgets of their parent screen — the audit's
"every designed line has a status and an evidence anchor" property holds.

## A2. Open gaps from the 2026-08-09 matrix that remain open (verified 2026-09-23)

- **Supabase console Redirect URL** — still owner-action. See audit doc §1d
  and the recovery evidence trail.
- **`docs/p0_decision_capture.md` §3 P4 row** — still owner OPEN.
- **D-45.1 provider-loop Phase 2** — still needs a controlled inbox.
- **v1 demo surfaces' real-data path** — server table + RLS + matrix
  addendum; still one dated owner decision per surface (compliance alerts,
  task board, approvals).
- **AR/TR copy semantic pass** — still pending native-speaker review.
## A3. The D-15 video-consultation screen lands — 34 screens (2026-09-23, audit §12.16)

**Tree state.** Same `main` branch; this addendum records the
`video_consultation_screen.dart` slice (audit doc §12.16). The screen was the
last designed-but-unbuilt surface (§3's `DEFERRED_PHASE: video (v1, D-15
open)` row) and it lands in the **demo posture ratified by
`docs/video_scope_decision_2026-08-11.md`**: a synthetic `VideoGateway` seam
(C-1), zero real media and zero device permissions (C-2), zero writes (C-3),
living beside booking on the same `canBookConsultation` gate (A-2 — no new
role flag). The fake IS the product posture; the server table is a future
owner decision, same class as the other v1 demo surfaces.

| Status | Count |
|---|---|
| `*_screen.dart` in `lib/features/**/presentation/` | **34** (was 33 — `video_consultation_screen.dart` lands) |
| `DEFERRED_PHASE` rows remaining | **0** (D-15 closed in demo posture) |
| Test count (per `README.md` and `verify_ledger.sh` PASS row) | **1426 executed / 1423 tracked declarations** (was 1400 / 1397 at the A1 snapshot) |
| Full suite green on the landing commit | `flutter analyze` No issues · `flutter test` +1426 · `verify_ledger.sh` PASS |

**What the slice added beyond the screen:**

- `lib/features/video/` — domain (`ConsultationSession` VO, `VideoGateway`
  interface), data (`FakeVideoGateway`, 4 deterministic non-PII sessions),
  presentation (cubit/state/screen + `video_session_tile` /
  `video_call_surface` parts + `video_entry_card`), all l10n'd in EN/AR/TR.
- **D-S4 dead taps wired** (the §3 `OUT_OF_SCOPE_MVP` row is closed):
  notification bell → feed, avatar → profile, all four practice-area cards →
  discovery pre-filtered via the new `/discovery?area=` deep link (same
  screen — no count change), booking-success "Join demo call" CTA.
- Home entry stack: `VideoEntryCard` rides `canBookConsultation` directly
  under the booking card (A-2 posture).

**Historical frozen records unchanged:** the §1-§3 snapshot at
2026-08-09 / `b7325f8`, the A1 extraction record — addenda only, per the
document's own convention.
