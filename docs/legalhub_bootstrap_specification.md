# LegalHub — Bootstrap Specification (Foundation Only)

> **Scope authority.** This document authorizes *preparation for implementation* of the LegalHub foundation only. It does **not** authorize building any sensitive legal-workflow module. No Flutter, SQL, Supabase, or UI code is written in this document.
> **Governing inputs:** `INSTRUCTIONS.md`; `docs/legalhub_specification.md` (Rev 2); the canonical design-system artifacts; the design exports (visual reference only); `plan.md` *(not accessible in this workspace — see §2.4)*.
> **Date:** 2026-07-27.
> **Status:** ✅ **APPROVED 2026-07-27** (bootstrap spec only). Four hard gates remain: (1) final design-token sign-off, (2) AR/TR glyph + RTL validation, (3) dev-only config — no production credentials/real client data, (4) Flutter/Dart + Android + iOS version pinning. Implementation authorized to begin at ticket **B1** only.

---

## Confirmed decisions carried into this spec
- **Brand:** Product name is **LegalHub**. All "Lexis" / "Lex Juris" visual labels must be replaced before release.
- **Canonical design system:** The normalized **LegalHub design system** is the single source of truth. Individual HTML screen tokens are **non-authoritative**.
- **D-13 (body typeface):** **Noto Sans** for UI/body text (verified Arabic + Turkish coverage). **Playfair Display** retained only for optional English display headings, with a localized fallback for Arabic (headings fall back to Noto Sans / Noto Naskh Arabic in AR).
- **D-14 (dark theme):** **Deferred** from bootstrap/MVP. Bootstrap ships **light theme only**. Dark-mode screens remain visual references, not an approved accessible theme.
- **Primary color:** Canonical primary is **Midnight Blue `#0b1d2e`** (not `#000000`).
- **Deferred (not authorized here):** conflicts, waivers, ethical walls, regulatory filings, AI legal research/drafting, compliance claims, payments, analytics.

---

# 1. Bootstrap scope and explicit non-goals

## 1.1 In scope
Establish a runnable, testable, localized, themeable, role-aware **application skeleton** with quality gates — and nothing that collects or displays real legal data.

## 1.2 Explicit non-goals
- No feature business logic (no attorney search results, bookings, messages, documents, matters).
- No real authentication backend wiring beyond a typed integration **boundary** (no Supabase project keys embedded, no sign-in flow logic).
- No data models for matters/documents/messages/billing.
- No high-risk workflow UI or logic (see "Not Authorized Yet", §11).
- No dark theme, no payments, no AI, no analytics.
- No production or real user data in any environment.

---

# 2. Preconditions and unresolved decisions

## 2.1 Satisfied preconditions
- D-01 (brand), D-10 (canonical system), D-13 (typeface), D-14 (dark deferred), primary color — all confirmed.

## 2.2 Conditions to close before/within bootstrap
| Item | Needed for | Owner |
|---|---|---|
| Confirm final canonical color table (§5.1) incl. `primary=#0b1d2e` | Theme package ticket | Design lead |
| Verify Noto Sans + Playfair glyph coverage EN/AR/TR; select Arabic fallback | Typography ticket | Design lead |
| Provide a **dev-only** Supabase URL/anon key via env (no service-role key) | Auth boundary (interface only) | Product owner |
| Pin Flutter/Dart SDK versions (`INSTRUCTIONS.md` §1.1) | Project setup | Tech lead |
| Confirm min platform targets (iOS/Android versions) | Project setup | Tech lead |

## 2.3 Deferred decisions that do NOT block bootstrap
D-02..D-09, D-11 (product legal model, jurisdiction, residency, retention, review authority, research/AI/payment/video) — all deferred; bootstrap does not depend on them.

## 2.4 `plan.md` accessibility (limitation only)
`plan.md` is **not accessible in this project workspace**. This is recorded as a **workspace-accessibility limitation only**; it is not a claim that the file does not exist. If provided, it will be reconciled in a later pass. Bootstrap does not depend on it.

---

# 3. Approved foundation capabilities

Each is foundation-only (skeleton + boundary), not a feature.

1. **Flutter project setup** — single app, null-safe Dart 3, pinned SDK; platform folders for iOS/Android (web/desktop out of scope unless later approved).
2. **Environment configuration strategy** — build-time env (dev/staging/prod) via `--dart-define`/`--dart-define-from-file`; no secrets committed; dev-only Supabase anon config injected, never a service-role key.
3. **Localization foundation** — EN (default), **AR (RTL)**, TR via `flutter_localizations` + ARB files; locale resolution + persistence; no concatenated strings; date/number/currency via `intl`.
4. **Design-token & theme package** — a single `legalhub_design_system` theme built from §5 tokens; light theme only; no hard-coded colors elsewhere.
5. **Accessible role-aware application shell** — an app scaffold (top bar + bottom/rail navigation) whose destinations are driven by a **placeholder** role; semantics, focus order, min 48dp touch targets, contrast.
6. **Authentication integration boundary** — an abstract `AuthGateway`/`SessionRepository` contract + a fake/in-memory implementation for dev; **no** real credential flow. Presentation depends on the contract only.
7. **Placeholder role model & authorization boundary** — enum of the six roles; a client-side `RoleCapability` map used **only** for navigation/visibility, explicitly documented as **UX-only, not authorization**.
8. **Safe navigation structure** — GoRouter with named/typed routes, a redirect for unauthenticated state (UX only), and a route-guard seam that documents that real authorization is server-side (future).
9. **Error, loading, empty, offline, unauthorized states** — a shared set of reusable state widgets and a canonical `ViewState` pattern for Cubits.
10. **Observability / error-reporting boundary** — an `ErrorReporter` abstraction (no-op/console in dev; Supabase `error_logs`/Sentry later) with redaction rules; no PII/secrets/document bodies in logs.
11. **Test, lint, formatting, CI quality gates** — `flutter analyze`, `dart format`, `flutter_test`/`bloc_test`/`mocktail`, and a CI pipeline running format+analyze+test on PRs.

---

# 4. Architecture blueprint

## 4.1 Feature-first folder structure
```
lib/
  app/        # bootstrap, router, DI wiring, theme, localization
  core/       # errors, Result, base use case, ViewState, auth/security/logging primitives
  data/       # cross-feature services (env, error reporter, auth gateway impl)
  shared/     # reusable widgets (state views), extensions
  features/   # (empty at bootstrap; scaffold placeholder only)
```

## 4.2 Dependency direction
`presentation → domain → data`. Presentation never imports Supabase/transport. Repositories are the boundary; DTOs/exceptions never cross into presentation. `core`/`shared` depend on nothing feature-specific.

## 4.3 State-management conventions
BLoC/Cubit with immutable `Equatable` states; explicit `loading/success/empty/error/unauthorized/offline` via a shared `ViewState<T>`; `BlocBuilder` for render, `BlocListener` for side effects; guard against duplicate submissions and post-dispose navigation.

## 4.4 Routing and route guards
GoRouter with named routes and typed params; a redirect handles unauthenticated → sign-in placeholder (UX only). Guards are documented as **navigation UX**, not security; server-side enforcement is a future gate.

## 4.5 Dependency injection
GetIt: lazy singletons for stateless services/repositories; factories for Cubits. A single `configureDependencies()` in `app/`.

## 4.6 Configuration & secret handling
No secrets in source or VCS. Env via `--dart-define(-from-file)`; dev anon key only; service-role keys never on client. `.gitignore` excludes env files; a committed `.env.example` documents keys by **name** only.

---

# 5. Design-system implementation contract

## 5.1 Canonical token table (light) — decisions required before implementation
Adopt the normalized table in `docs/legalhub_specification.md` §5.1 **with `primary = #0b1d2e` (Midnight Blue)**. Before the theme ticket starts, Design lead must sign off that table verbatim (one open value: confirm `primary` override of the source `#000000`). No other token may be introduced from individual HTML mockups.

## 5.2 Typography & glyph validation
- Body/UI: **Noto Sans** (roles `body-lg/md/sm`, `label-caps`).
- Optional English display headings: **Playfair Display** (`display-lg`, `headline-*`), **falling back to Noto Sans / Noto Naskh Arabic for AR**.
- **Requirement:** validate EN + AR + TR glyph coverage and rendering (including Turkish dotted/dotless i and Arabic shaping) before finalizing the type scale; ship bundled fonts with correct licensing.

## 5.3 RTL layout requirements
All spacing via `EdgeInsetsDirectional`/`AlignmentDirectional`; directional icons where meaningful; verify mirrored navigation and back affordances under AR; no left/right hard-coding.

## 5.4 Theme scope
**Light theme only** in bootstrap. Dark theme **deferred (D-14)**; the theme package must be structured so a dark `ColorScheme` can be added later without refactor, but no dark values are defined now.

---

# 6. Access-control and data-safety boundaries

- **No client-side authorization reliance:** role/capability maps drive **visibility only**; every consequential action will require server-side enforcement (future gate). This must be stated in code comments at the seam.
- **No production data** in development or testing; synthetic fixtures only.
- **No sensitive legal data collection** in this work package (no matters/documents/messages/PII beyond a placeholder display name).
- **Future gate:** a mandatory Supabase schema + RLS + storage-policy review must pass **before** any real-data feature is built. Bootstrap only defines the `AuthGateway`/repository *interfaces*.

---

# 7. Ordered engineering backlog

| # | Ticket | Scope | Acceptance criteria | Dependencies / blockers |
|---|---|---|---|---|
| B1 | Project & tooling init | Flutter app, pinned SDK, `.gitignore`, `.env.example`, analysis_options | App builds & runs blank screen; `flutter analyze`/`format` clean | SDK pin, platform targets |
| B2 | CI quality gates | CI runs format+analyze+test on PR | PR fails on lint/test error; green on clean | B1 |
| B3 | Folder structure & DI | `app/core/data/shared/features` + GetIt `configureDependencies()` | Layers compile; DI resolves a sample service | B1 |
| B4 | Core primitives | `Result<T>`, `AppError`, `ViewState<T>`, base use case | Unit tests for Result/error mapping pass | B3 |
| B5 | Design-token & theme package (light) | `legalhub_design_system` ThemeData from §5.1 | No hard-coded colors; widget test renders tokens; primary=#0b1d2e | §5.1 sign-off |
| B6 | Typography + fonts (EN/AR/TR) | Bundle Noto Sans (+ Playfair display, Arabic fallback); type scale | Glyphs render in EN/AR/TR; licensing recorded | B5, glyph validation |
| B7 | Localization foundation | `flutter_localizations`, ARB (EN/AR/TR), locale persistence | Runtime locale switch; AR flips to RTL; no concatenated strings | B3 |
| B8 | Shared state widgets | loading/empty/error/offline/unauthorized views | Widget tests for each state | B4, B5 |
| B9 | Auth integration boundary | `AuthGateway`/`SessionRepository` contracts + fake impl | Cubit consumes fake session; no real keys; tests pass | B3, dev anon config |
| B10 | Placeholder role model + capability map | 6-role enum + UX-only capability map (documented) | Unit tests; comment states "not authorization" | B4 |
| B11 | Router + shell | GoRouter routes, unauth redirect, role-aware nav shell | Nav reflects placeholder role; RTL verified; back/focus correct | B7, B9, B10 |
| B12 | Observability boundary | `ErrorReporter` abstraction + redaction rules | Errors routed; test asserts no PII/secret leakage | B4 |
| B13 | Placeholder screen | One screen proving theme + l10n + RTL + a state view | Manual EN/AR check; widget test | B5, B7, B8, B11 |

---

# 8. Test plan and definition of done

**Test plan:** unit tests (Result/AppError, capability map, locale resolution); bloc_test for the shell/session Cubit (loading/success/unauthorized); widget tests for each shared state view and the placeholder screen; targeted EN + AR/RTL render checks (light only).

**Definition of done (bootstrap):**
- [ ] App builds/runs; `flutter analyze` & `dart format` clean; CI green.
- [ ] Light theme sourced entirely from `legalhub_design_system`; no stray hard-coded styling.
- [ ] EN/AR/TR localization works; AR is RTL; no concatenated strings.
- [ ] Auth is an interface with a fake impl; no real/secret keys committed.
- [ ] Role/capability is documented UX-only; no authorization claims.
- [ ] Shared states + placeholder screen tested.
- [ ] `git status`/`git diff` reviewed for secrets/real data.
- [ ] No high-risk module, dark theme, payment, AI, or analytics present.

---

# 9. Deliverables and approval gates

**Deliverables:** runnable skeleton app; theme+token package; localization scaffold; DI+router+shell; core primitives+state widgets; auth boundary; observability boundary; CI config; tests.

**Approval gates:** (1) this bootstrap spec approved; (2) §5.1 token table + typeface glyph validation signed off before B5/B6; (3) per-PR CI gate; (4) **mandatory Supabase/RLS review gate before any real-data feature** (post-bootstrap).

---

# 10. Risks, assumptions, and escalation triggers

**Risks:** brand replacement missed on some screens; inconsistent HTML tokens copied by mistake (mitigated by canonical-only rule); Arabic shaping/RTL regressions; env/secret mishandling.
**Assumptions:** the blue "Fidelity" variant is canonical; light-only is acceptable for MVP; dev Supabase anon config will be provided.
**Escalation triggers:** any request to add a high-risk module, embed a service-role key, ship dark theme without an approved accessible palette, collect real legal/PII data, or make a legal/compliance claim — **stop and escalate** per `INSTRUCTIONS.md` §8.

---

# Bootstrap readiness status

**READY WITH CONDITIONS.**

Conditions to satisfy before starting B5/B6 and B9:
1. Design lead sign-off on the §5.1 token table with **primary = `#0b1d2e`**.
2. Glyph-coverage validation for Noto Sans (+ Playfair, Arabic fallback) across EN/AR/TR.
3. Dev-only Supabase anon config (URL + anon key) provided via env — **no service-role key**.
4. Flutter/Dart SDK versions and min platform targets pinned.

## Exact approvals needed to begin implementation
- Approve this `docs/legalhub_bootstrap_specification.md`.
- Approve the §5.1 canonical token table (with Midnight Blue primary).
- Confirm typeface/glyph validation may proceed and fonts may be bundled.
- Provide dev environment configuration (anon key only).

## Not Authorized Yet (deferred high-risk modules)
Conflict check / disclosure / analytics · Conflict waivers · Ethical walls · Regulatory filings & submission · Legal research AI assistant / citation manager / statutory browser · Legal draft workspace · Compliance alerts / audit trail (write) · Global compliance map · Risk & advanced analytics dashboards · Billing / payments · Video consultation · Any dark-theme UI · Any real legal/PII data collection · Any legal/regulatory/compliance claim.
