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