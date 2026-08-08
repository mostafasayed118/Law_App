# LegalHub — Screen-Completeness Matrix (Consumable Record, 2026-08-09)

> **Record type:** Persisted output of the screen-completeness audit run on
> 2026-08-09 (read-only; grounded in doc reads, `lib/` globs, and git facts —
> no invented screens). Status date: **2026-08-09, `origin/main` @ `b7380d2`**.
>
> **Method:** every screen named or described in
> `docs/legalhub_specification.md` (§4 MVP / v1 / §6 remediation rows),
> `docs/legalhub_bootstrap_specification.md` (B1–B13), — plus roadmap
> (`docs/features_roadmap_2026-08-03.md`) Phase 1–12 and the §14
> un-deferrals — is matched against the actual presentation surface
> (`lib/features/*/presentation/*_screen.dart`) and git state
> (`git status` clean at `b7380d2`, pushed to `origin/main`).
>
> **Status vocabulary:** DONE_COMMITTED (built + tested + committed + pushed,
> with a test file present) · PARTIAL (built but not the designed shape, or
> only a section/reuse) · DEFERRED_PHASE (assigned to a later phase, cited) ·
> DEFERRED_DECIDED (explicit owner decision cited) · OUT_OF_SCOPE_MVP (cited
> scope line) · NOT_STARTED (designed, no decision — the gap list).
>
> **Verification basis:** 27 screens under `lib/features/**/presentation/`;
> full gate stack green on the record commit: `dart format` clean ·
> `flutter analyze` 0 issues · `flutter test` **1112 pass** ·
> `scripts/verify_ledger.sh` **PASS 115/0/0** (README suite 1109 in lockstep).

---

## 1. Designed-by-document screens

| Screen (designed) | Spec source | Status as of 2026-08-09 | Evidence |
|---|---|---|---|
| sign_in | legalhub §6 row 148; P3.1 | DONE_COMMITTED | `lib/features/auth/presentation/sign_in_screen.dart`; test `test/features/auth/sign_in_screen_test.dart` |
| sign_up | legalhub §6:148; P3.1 | DONE_COMMITTED | `sign_up_screen.dart`; test `sign_up_screen_test.dart`; check-inbox state (roadmap 4.2) |
| forgot_password_email_recovery / otp_verification / reset_password | legalhub §6:149 | DONE_COMMITTED | `forgot_password_{email,otp,reset}_screen.dart`; tests `forgot_password_steps_test.dart`, `forgot_password_threading_test.dart` |
| onboarding / onboarding_success | legalhub §6:150; LBS B13 | DONE_COMMITTED | `onboarding_screen.dart`, `onboarding_success_screen.dart`; both tests file-level |
| home_dashboard (role shell, entry cards, search field) | legalhub §6:151; roadmap 11 (D-S4) | DONE_COMMITTED | `home_screen.dart`; `home_screen_test.dart`, `home_cards_test.dart` |
| attorney_search / attorney_profile | legalhub §6:152; Phase 6 | DONE_COMMITTED | `discovery/.../attorney_search_screen.dart`, `attorney_profile_screen.dart`; both tested |
| consultation_type / select_date_time / review_confirm_booking / booking_success | legalhub §6:153; Phase 5 | DONE_COMMITTED | `booking_screen.dart` (4-step wizard); `booking_cubit_test.dart`, `booking_screen_test.dart` |
| message_center / matter_discussion | legalhub §6:154; Phase 9 + §14 realtime | DONE_COMMITTED | `message_list_screen.dart`, `message_thread_detail_screen.dart`; both tested |
| document_vault | legalhub §6:155; Phase 8 + §14 read | DONE_COMMITTED | `document_list_screen.dart`; tests incl. `document_list_screen_test.dart` |
| case_management_dashboard / case_details / shared_case_workspace | legalhub §6:156; Phase 7/10 | DONE_COMMITTED | `matter_list_screen.dart`, `matter_details_screen.dart` (+ documents/messages/files/invoices sections); `matter_list_screen_test.dart`, `matter_details_screen_test.dart` |
| user_profile / settings_localization | legalhub §6:157 | DONE_COMMITTED | `profile_screen.dart`, `settings_screen.dart`; both tested |
| notification_settings | legalhub §6:157 | DONE_COMMITTED | `notification_settings_screen.dart`; `notification_settings_screen_test.dart` |
| partner_notification_settings | legalhub §6:157 | **DECIDED CLOSED** — intentionally satisfied by shared screen; **D-T7** (`docs/tracked_deviations.md`, 2026-08-09) | no duplicate built; cross-ref `legalhub_specification.md` row 157 |
| billing_invoices | legalhub §6:158; D-11 | **DONE_COMMITTED** (2026-08-09 slice) | `billing_invoices_screen.dart` + `/invoices` (commit `f4396cf`); test `billing_invoices_screen_test.dart`; D-11 = no live payment |
| video_consultation | legalhub §6:159; v1 | DEFERRED_PHASE (v1; D-11 open) | no screen |
| collaboration_task_board / pending_approvals_queue | legalhub §6:160; v1 | DEFERRED_PHASE (v1) | no screen |
| compliance_alerts | legalhub §6:168; v1 | DEFERRED_PHASE (v1 read-only) | no screen |
| conflict_check_search / disclosure_* / report / resolution dashboards / analytics / alert_detail | legalhub §6:161–163 | DEFERRED_DECIDED (D-03/D-06, spec §4 "do NOT build now") | no screen |
| request_conflict_waiver / waiver_approval_detail / waiver_status / approval_detail | legalhub §6:164 | DEFERRED_DECIDED (D-06) | no screen |
| resolution_action_ethical_wall / take_action_conflict_resolution | legalhub §6:165 | REF passed (D-06) | no screen |
| regulatory_filings_dashboard / filing_submission_workspace | legalhub §6:166 | DEFERRED_DECIDED (D-03 + provider) | no screen |
| legal_research_ai_assistant / citation_manager / statutory_browser / draft_workspace / legal_library | legalhub §6:167 | DEFERRED_DECIDED (D-07/D-08; §14 AI-only path) | no screen |
| global_compliance_map / risk_dashboard / advanced_analytics | legalhub §6:169 | DEFERRED_DECIDED (validated data + D-03) | no screen |

## 2. Roadmap / post-P0 adds (not part of the §6 mockup set)

| Surface | Source | Status | Evidence |
|---|---|---|---|
| org hub + create-org + roster + invite sheet | P3 spec / roadmap P1 | DONE_COMMITTED | `orgs/presentation/*` (4 screens + sheet); 4 tests |
| accept-invitation (paste + deep link) | P3.4; roadmap 2.4/4.1 D-P34.2 | DONE_COMMITTED | `accept_invitation_screen.dart` + `app/deep_link/*`; tests |
| platform admin (orgs/members/audit) | P3.5 + §14 under-deferrals | DONE_COMMITTED | `admin/platform_admin_screen.dart`; tests |
| **org audit (partner)** | P3 follow-up scope `partner_org_audit_scope_2026-08-09.md` | **DONE_COMMITTED** (commit `eab0736`/`b7380d2`) | `org_audit_screen.dart` + route `/organizations/audit`; tests `org_audit_cubit_test.dart`, `org_audit_screen_test.dart` |
| read-only audit trail (owner, platform) | audit-surfacing bin (2026-08-08) | DONE_COMMITTED | platform-admin Audit section |
| message thread detail (+ composer) | §14 realtime + send | DONE_COMMITTED | `message_thread_detail_screen.dart` |

## 3. Summary counts

| Status | Count |
|---|---|
| DONE_COMMITTED (incl. post-P0/org screens) | 27 screens present in `lib/features/**/presentation/` |
| PARTIAL | 0 |
| NOT_STARTED (no decision) | 0 |
| DONE_WIP (uncommitted) | 0 |
| DEFERRED_PHASE | 4 groups (video, task board, approvals, compliance alerts) |
| DEFERRED_DECIDED | 24 groups (conflicts, waivers, walls, filings, research/AI, analytics, compliance map) |
| OUT_OF_SCOPE_MVP | 2 inert home affordances (practice-area cards, notifications bell — D-S4) |

## 4. Gap list (designed, no blocking decision, no build) — **EMPTY as of 2026-08-09**

The single 2026-08-09 gap (`partner_notification_settings`) was closed by
**D-T7** (decision, not a duplicate screen). With `org_audit_screen.dart` and
`billing_invoices_screen.dart` shipped, **every designed line has a status and
an evidence anchor.**

## 5. Screens claimed built but missing tests — **NONE**

Each `*_screen.dart` has a test file in `test/features/**`, verified during
the audit (list maintained in the audit record; full suite 1112 pass).

## 6. Open (owner-side) items NOT blocking the matrix

- Supabase console **Redirect URL** (`com.legalhub.app://auth/v1/callback`) — deep-link recovery inactive until added (owner action; roadmap 4.1 R1).
- `docs/p0_decision_capture.md` §3 **P4 row** (security review + controlled rollout) — status BLOCKED / owner OPEN.
- **D-45.1 provider-loop Phase 2** dev-project smoke — needs a controlled inbox (owner-side).
- v1 queue decisions (compliance alerts, task board, approvals) — owner decision, no code.