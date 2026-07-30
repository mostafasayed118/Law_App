# LegalHub — Product & Technical Specification (Planning Phase)

> Planning artifact only. No application code, SQL, migrations, RLS, edge functions, or production config is defined here. `INSTRUCTIONS.md` is not modified by this document.
> **Revision 2 (2026-07-27):** Applies confirmed decisions **D-01 (brand = LegalHub)** and **D-10 (single canonical design system)**. Adds canonical token proposal, brand/token remediation list, and a project-bootstrap readiness checklist.

---

# 0. Note on `plan.md` availability

`plan.md` was **not accessible in this project workspace** at the time of this revision. A full recursive scan of `c:/flutter_projects/law_app` on 2026-07-27 returned `INSTRUCTIONS.md`, the `stitch_legalhub_mobile_app/` design exports, this `docs/` folder, and the `.rar` archive — no `plan.md`.

This is a statement about **workspace accessibility only**. The product owner has indicated `plan.md` was uploaded earlier in chat; it may exist outside the model's file workspace. It is **not asserted that `plan.md` does not exist globally.** To reconcile it in the next pass, please place `plan.md` in the project workspace alongside `INSTRUCTIONS.md`.

---

# 1. Specification status

**STATUS: SPECIFICATION PARTIALLY READY — HIGH-RISK FEATURES DEFERRED**

D-01 and D-10 are now confirmed, which unblocks the **project-bootstrap** work package (foundation only). High-risk legal workflows (conflicts, waivers, ethical walls, filings, research/AI, payments) remain deferred pending D-02..D-09 and reconciliation of `plan.md`. This document is ready to support approval of the **bootstrap specification**, not the full app build.

---

# 2. Confirmed decisions applied

| ID | Decision | Confirmed outcome |
|---|---|---|
| **D-01** | Product brand | **LegalHub** is the product name. All visible **"Lexis" / "Lex Juris"** labels, logos, and page titles in the design assets must be replaced with **LegalHub**. Rationale: "Lexis" collides with an established legal-information brand (naming/confusion risk). |
| **D-10** | Canonical design system | The design-system artifacts are the **single source of truth**. The `lexis_design_system*` source is adopted and conceptually renamed **`legalhub_design_system`**. **One** Flutter theme is derived from it. Per-screen HTML token values **must not** override the canonical system. |

---

# 3. Updated decision register

| ID | Decision | Status | Owner | Trigger | Impacted scope |
|---|---|---|---|---|---|
| D-01 | Product brand (LegalHub) | **CONFIRMED** | Product owner | — | Branding, titles, logos |
| D-10 | Canonical design system (single source) | **CONFIRMED** | Design lead | — | Theme, all UI |
| D-02 | Product legal model (firm / marketplace / portal / combo) | open | Product owner + counsel | Before scope lock | Permission & tenant model |
| D-03 | Target jurisdiction(s) + legal-policy owner | open (legal review) | Product owner + counsel | Before any high-risk spec | Conflicts, waivers, filings, compliance |
| D-04 | Data residency & cross-border transfer | open (legal review) | Product owner + counsel | Before Supabase region config | Hosting, storage, backups |
| D-05 | Retention / deletion / legal-hold / export | open (legal review) | Compliance + counsel | Before data-model spec | Documents, messages, audit, matters |
| D-06 | Human review/approval authority (conflicts/waivers/walls/filings) | open | Compliance/partner owner | Before high-risk workflow spec | High-risk workflows |
| D-07 | Legal research data source/license/freshness | open (legal review) | Product owner + vendor/legal | Before research spec | Research, citations, statutory browser |
| D-08 | AI usage policy (store/show/rely; review) | open (legal review) | Product owner + counsel | Before AI/drafting spec | AI research, legal drafting |
| D-09 | Payment provider / tax / PCI scope | open | Product owner + finance | Before billing/payment spec | Billing, booking payment |
| D-11 | Video consultation provider & data-handling | open | Product owner | Before video spec | Video consultation |
| D-12 | `plan.md` / discovery report availability | open | Product owner | Immediately | Full specification reconciliation |
| **D-13** | Canonical body typeface | **CONFIRMED** | Design lead | Resolved at bootstrap-spec approval | Typography theme — see `docs/legalhub_bootstrap_specification.md` |
| **D-14** | Dark-theme token values | **CONFIRMED** (approved as-is per ADR-0002) | Design lead | Resolved 2026-07-30 | All dark-mode screens |

---

# 4. Revised MVP scope

Unchanged in shape from Rev 1; now anchored to the confirmed brand and canonical design system. High-risk workflows remain deferred.

**MVP (safe to build):** Authentication (sign in/up, forgot-password email→OTP→reset) · Role-aware app shell & navigation · Attorney discovery (read-only) · Consultation booking (no live payment) · Matter-scoped messaging · Document vault (scoped, no e-signature) · Case/matter dashboard & details (read-first) · Settings & localization (EN/AR/TR, light/dark) — all rendered from the **LegalHub** brand and the single canonical theme.

**v1 (after MVP):** Billing/invoices (D-09) · Video consultation (D-11) · Collaboration task board / shared workspace · Notification delivery · Compliance audit-trail read-only viewer.

**Deferred (do NOT build now):** Conflict check/disclosure/analytics (D-03/D-06) · Waivers (D-06) · Ethical walls (D-06) · Regulatory filing submission (D-03) · Research AI assistant / citation manager / statutory browser / legal draft workspace (D-07/D-08) · Global compliance map / risk & advanced analytics (validated data + D-03).

**Out of scope:** Any regulatory-compliance / legal-advice / conflict-"clearance" claim · Real payment capture or filing submission until governed · Client-only authorization.

---

# 5. Canonical token proposal (`legalhub_design_system`)

Derived by normalizing the three design-system files. Two files (`lexis_design_system`, `lexis_design_system_2`) are **identical** — the **"Fidelity / Parchment" blue variant**. The third (`lexis_design_system_1`) is a **"Warm / Paper" variant** that diverges on surfaces and body typography. **Recommendation: adopt the blue "Fidelity" variant as canonical** (it is the 2-of-3 majority and matches the primary app screens such as `home_dashboard`). Divergences are captured as open decisions **D-13** (body typeface) and **D-14** (dark theme).

> The per-screen HTML mockups contain their own inline `tailwind.config` token blocks that **disagree** with each other and with the design-system files (e.g., `home_dashboard` radius scale ≠ `conflict_check_search` radius scale). Per D-10 these inline values are **non-authoritative** and must not be copied. Only the table below is authoritative.

### 5.1 Color — canonical light theme
| Token (Flutter/M3 role) | Hex | Notes |
|---|---|---|
| primary | `#0b1d2e` | Midnight/Ink Blue. **Discrepancy:** design files list `primary:#000000` but the narrative + `primary-container` describe Midnight Blue `#0b1d2e`/`#041627`. Canonical = Midnight Blue; confirm at D-10 sign-off. |
| on-primary | `#ffffff` | |
| primary-container | `#0b1d2e` | |
| on-primary-container | `#74859b` | |
| secondary | `#775a19` | "Old Gold / Legal Bronze" — accent & important statuses |
| on-secondary | `#ffffff` | |
| secondary-container | `#fdd587` | |
| on-secondary-container | `#785a19` | |
| tertiary-container | `#2d1605` | |
| on-tertiary-container | `#a27c64` | |
| error | `#ba1a1a` | Muted crimson — errors & conflict flags (never used alone; pair with text/icon) |
| on-error | `#ffffff` | |
| error-container | `#ffdad6` | |
| on-error-container | `#93000a` | |
| background | `#f8f9ff` | Cool white |
| on-background | `#0d1c2e` | |
| surface | `#f8f9ff` | |
| surface-container-lowest | `#ffffff` | Card "document" surface |
| surface-container-low | `#eff4ff` | |
| surface-container | `#e6eeff` | |
| surface-container-high | `#dce9ff` | |
| surface-container-highest | `#d5e3fc` | |
| surface-variant | `#d5e3fc` | |
| on-surface | `#0d1c2e` | |
| on-surface-variant | `#44474c` | |
| outline | `#74777d` | |
| outline-variant | `#c4c6cd` | 1px structural borders |
| inverse-surface | `#233144` | |
| inverse-on-surface | `#eaf1ff` | |
| accent-gold | `#c5a059` | Decorative "seal" accent |

> **Status semantics:** the design uses green "Clear"/red "Conflict" badges. Per `INSTRUCTIONS.md` §4.4 and §4.5, status must never rely on color alone and conflict results must **not** be labeled as "Clear"/clearance. Define semantic status tokens (`status-info`, `status-attention`, `status-critical`) with **text + icon**, not standalone green/red. (Green is not in the palette and must be added deliberately if used.)

### 5.2 Dark theme — **D-14 (approved)**
The design-system files define **light values only**, yet ~40 `*_dark_mode` screens exist. Canonical dark tokens were derived (M3 tonal inversion) and wired in `lib/app/legalhub_theme.dart`; dark mode is **approved as-is** per ADR-0002 (retroactively accepted 2026-07-30), closing D-14. New dark-mode design work may build on the existing dark tokens without a separate per-screen dark-token approval.

### 5.3 Typography — canonical (D-13 confirmed)

> **D-13 resolved at bootstrap-specification approval:** body/UI face is **Noto Sans** (verified Arabic + Turkish coverage); **Playfair Display** is retained only for optional English display headings, falling back to Noto Sans / Noto Naskh Arabic for Arabic. See `docs/legalhub_bootstrap_specification.md` §2.1 and B6. The earlier "Inter" proposal is superseded.

| Role | Family | Size / Line | Weight | Tracking |
|---|---|---|---|---|
| display-lg | Playfair Display (AR fallback: Noto Sans / Noto Naskh Arabic) | 48 / 56 | 700 | -0.02em |
| headline-lg | Playfair Display (AR fallback) | 30 / 38 | 700 | -0.01em |
| headline-lg-mobile | Playfair Display (AR fallback) | 26 / 32 | 700 | — |
| headline-md | Playfair Display (AR fallback) | 22 / 28 | 600 | — |
| body-lg | **Noto Sans** | 18 / 28 | 400 | — |
| body-md | **Noto Sans** | 16 / 24 | 400 | — |
| body-sm | **Noto Sans** | 14 / 20 | 400 | — |
| label-caps | Noto Sans | 12 / 16 | 600 | 0.05em, UPPERCASE |

### 5.4 Spacing — canonical
4px base unit · `xs 4` · `sm 8` · `md 16` · `lg 24` · `xl 32` · `section-gap 32` · `margin-mobile 20` · `margin-desktop 40` · `container-max 1280`. Use `EdgeInsetsDirectional` for all values (RTL).

### 5.5 Radius — canonical
`sm 2px (0.125rem)` · `DEFAULT 4px (0.25rem)` · `md 6px (0.375rem)` · `lg 8px (0.5rem)` · `xl 12px (0.75rem)` · `full 9999px`. (Overrides the inconsistent per-screen HTML radius scales.)

### 5.6 Elevation
Tonal layering + subtle ambient shadow. Card = `surface-container-lowest` + `0 4px 12px rgba(4,22,39,0.08)`. Structural sections = 1px `outline-variant` border, no shadow. Modal scrim = `primary/60` with backdrop blur. Alert cards may use a low-diffusion `shadow-sm`.

### 5.7 Iconography
**Material Symbols Outlined** (Google) across all screens. Map to a Flutter equivalent (Material Symbols icon font or `material_symbols_icons`); use directional icons where meaningful for RTL.

---

# 6. Screen-by-screen brand / token remediation list

Two remediation types apply to **every** exported screen (light + dark): **(B)** replace "Lexis"/"Lex Juris" brand text/titles/logos with **LegalHub**; **(T)** rebind hard-coded inline tokens to the canonical `legalhub_design_system` theme (do not copy inline `tailwind.config` values).

| Screen group (light + dark unless noted) | (B) Brand fix | (T) Token rebind | Additional remediation |
|---|---|---|---|
| sign_in, sign_up | Yes — "Lexis" logo/title → LegalHub | Yes | Auth branding is first impression; verify AR/RTL |
| forgot_password_email_recovery / otp_verification / reset_password | Yes | Yes | — |
| onboarding, onboarding_success | Yes — likely brand-heavy hero copy | Yes | — |
| home_dashboard | Yes — header shows "Lexis" (page `<title>Lexis - Home`) | Yes — its inline token block diverges from canonical | Role-aware content |
| attorney_search, attorney_profile | Maybe | Yes | Remove any legal-advice/compliance-claim copy |
| consultation_type, select_date_time, review_confirm_booking, booking_success | Maybe | Yes | No live payment copy |
| message_center, matter_discussion | Maybe | Yes | — |
| document_vault | Maybe | Yes | — |
| case_management_dashboard, case_details, shared_case_workspace | Maybe | Yes | — |
| user_profile, settings_localization, notification_settings, partner_notification_settings | Maybe | Yes | Localization screen must reflect EN/AR/TR |
| billing_invoices | Maybe | Yes | Defer real payment (D-09) |
| video_consultation | Maybe | Yes | Defer (D-11) |
| collaboration_task_board, pending_approvals_queue | Maybe | Yes | v1 |
| conflict_check_search | Yes — `<title>Lexis Conflict Check` | Yes | **Safety:** remove green **"Clear"** badge & "prevent professional ethical breaches" copy (violates §4.4). **Deferred.** |
| conflict_disclosure_* (matter_selection, party_identification, analysis_findings, final_review) | Maybe | Yes | **Deferred (D-03/D-06)** |
| conflict_report_details, conflict_resolution_dashboard, conflict_resolution_overview, conflict_analytics_* , alert_detail_conflict_detected | Maybe | Yes | **Deferred**; correct any "clearance" language |
| request_conflict_waiver, waiver_approval_detail, conflict_waiver_status, approval_detail_conflict_waiver | Maybe | Yes | **Deferred (D-06)** |
| resolution_action_ethical_wall, take_action_conflict_resolution | Maybe | Yes | **Deferred (D-06)** |
| regulatory_filings_dashboard, filing_submission_workspace | Maybe | Yes | **Deferred (D-03)**; no "submitted" without provider response |
| legal_research_ai_assistant, citation_manager, statutory_research_browser, legal_draft_workspace, legal_library | Maybe | Yes | **Deferred (D-07/D-08)**; preserve citation/source metadata |
| compliance_alerts, compliance_audit_trail | Maybe | Yes | **Deferred → v1 read-only** |
| global_compliance_map, risk_dashboard_overview, advanced_analytics | Maybe | Yes | **Deferred** (validated data) |
| lexis / lexis_design_system(_1/_2) | Rename asset to `legalhub_design_system`; drop the "Warm" variant per D-10/D-13 | N/A (source of truth) | Resolve `primary:#000000` vs Midnight Blue discrepancy |

"Maybe" = confirm during implementation by inspecting each screen's header/title; treat every page `<title>` containing "Lexis" as a required brand fix.

---

# 7. Project-bootstrap readiness checklist

The bootstrap package builds **foundation only** — no features, no high-risk workflows.

- [x] D-01 brand confirmed (**LegalHub**)
- [x] D-10 single canonical design system confirmed
- [x] Canonical color/spacing/radius/elevation/icon tokens normalized (§5)
- [x] **D-13** — body typeface confirmed: **Noto Sans** (resolved at bootstrap-spec approval; Inter/Source proposal superseded)
- [x] **D-14** — dark-theme tokens approved as-is per ADR-0002 (dark mode retroactively accepted)
- [x] `primary` value confirmed as Midnight Blue `#0b1d2e` (resolve `#000000` discrepancy) — ADR-0005; code reconciled to `#0b1d2e`. `primary-container` (`#1A2B3C` vs spec `#0b1d2e`) remains a tracked deviation.
- [ ] Font licensing/glyph coverage verified for EN + **AR** + TR (Arabic fallback face identified)
- [ ] Supabase project (dev) provisioned; region pending D-04 (dev-only placeholder acceptable)
- [ ] Flutter/Dart SDK versions pinned per `INSTRUCTIONS.md` §1.1
- [ ] Repo initialized (currently **not a git repository**) with baseline `.gitignore`

**Bootstrap scope (for the separate bootstrap spec to be approved next):** Flutter project init · folder structure (`app/ core/ data/ shared/ features/`) · GetIt DI container · GoRouter skeleton (no protected feature routes) · `legalhub_design_system` theme (light; dark if D-14 closed) from §5 tokens · localization scaffolding (EN/AR/TR, RTL wiring) · `Result<T>`/`AppError` primitives · error-log abstraction · a single placeholder screen proving theme + localization + RTL. **No auth, no data models, no feature logic.**

---

# 8. Remaining decisions that block high-risk modules

| Module | Blocking decisions |
|---|---|
| Conflict checks / disclosure / analytics | D-02, D-03, D-06 |
| Waivers | D-03, D-06 |
| Ethical walls | D-03, D-06 |
| Regulatory filings | D-03, D-04, D-06, external provider |
| Legal research / statutory browser | D-03, D-07 |
| AI assistant / legal drafting | D-07, D-08 |
| Billing / payments | D-09, D-04 (residency), PCI scope |
| Video consultation | D-11, D-04 |
| Documents & messaging (retention aspects) | D-05 |
| Compliance/audit & analytics dashboards | D-03, D-05, validated data source |
| Full-spec reconciliation | D-12 (`plan.md`) |

---

# 9. Approval request (next step)

The immediate next step is approval of the **project-bootstrap specification only** — not the full app build. To proceed:

1. ~~Confirm **D-13** (body typeface) and either close **D-14** (dark tokens) or approve **light-only MVP** with dark deferred.~~ **D-13 confirmed (Noto Sans); D-14 resolved by ADR-0002 (dark theme approved as-is).**
2. Confirm `primary` = Midnight Blue `#0b1d2e`.
3. Authorize creation of a separate `docs/bootstrap_specification.md` covering §7 scope for review before any code.
4. When possible, add `plan.md` to the workspace so it can be reconciled (D-12).

All high-risk legal workflows remain deferred. No application code has been written.
