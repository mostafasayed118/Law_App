# ADR-0004: Enforce the shared/ second-use rule; retain ViewStateView

- Status: Accepted
- Date: 2026-07-30
- Related: `INSTRUCTIONS.md` §4.1 (Feature-first Clean Architecture), B8 (shared
  state widgets), `docs/legalhub_bootstrap_specification.md` §3.9.
- Supersedes: none.

## Context

`INSTRUCTIONS.md` §4.1 requires that code live in `shared/` "only after a real
second use or a demonstrated app-level cross-cutting responsibility." An audit
of `lib/shared/widgets/` found that the barrel (`widgets.dart`) violated its own
documented rule:

- **Dead code:** `ActionTray` had zero consumers anywhere in the codebase.
- **Single-consumer widgets mis-housed in `shared/`:**
  - `SecurityBadge`, `EditorialDivider`, `LoadingElevatedButton`, `SocialButton`
    — used only by `sign_in_screen`.
  - `OtpFieldRow` — used only by `forgot_password_otp_screen`.
  - `SectionHeader`, `StatusChip`, `IdentityCard`, `PracticeAreaCard` — used
    only by `home_screen`.
- **No feature had wired the B8 `ViewStateView` primitive** into any screen;
  it was built in B8 but never rendered.

This was speculative extraction: widgets placed in the shared surface before a
second use materialized, which couples every feature import to widgets only one
screen owns and makes "what is actually reusable" unanswerable by inspection.

## Decision

1. **Delete `ActionTray`** — it had no consumers and no demonstrated future use.
2. **Relocate single-consumer widgets to their owning features** (no behavior
   change, import-path-only):
   - `SecurityBadge`, `EditorialDivider`, `LoadingElevatedButton`,
     `SocialButton` → `lib/features/auth/presentation/widgets/auth_buttons.dart`.
   - `OtpFieldRow` → `lib/features/auth/presentation/forgot_password/otp_field_row.dart`.
   - `SectionHeader`, `StatusChip`, `IdentityCard`, `PracticeAreaCard` →
     `lib/features/home/presentation/widgets/home_cards.dart`.
3. **Retain `ViewStateView` in `lib/shared/widgets/view_state_view.dart`.**

> **Later deleted:** `SecurityBadge` was removed in `df6e5f4` (2026-08-02) —
> the presentational encrypted-connection badge was dropped from the sign-in
> screen together with the `AuthScaffold.bottomNavigationBar` param it consumed.

`legalhub_components.dart` now contains only `LegalHubAppBar` (the one genuinely
cross-feature component used by `AuthScaffold`). The `widgets.dart` barrel was
trimmed to export only genuinely-shared widgets: `LabelledField`,
`LegalHubTextField`, `PasswordField`, `AuthScaffold`, `IconHeroBadge`, and
`LegalHubAppBar` (via `legalhub_components.dart`).

### Why ViewStateView is retained despite zero current renderers

`ViewStateView` differs from the relocated widgets on two axes:

- It is not a leaf UI affordance tied to one screen; it is the **generic
  renderer for the `ViewState<T>` sealed type** defined in
  `lib/core/state/view_state.dart` (a core B4 primitive). It maps every
  `ViewState` variant (`ViewLoading`, `ViewSuccess`, `ViewEmpty`, `ViewError`,
  `ViewOffline`, `ViewUnauthorized`) to a localized, semantics-annotated
  (`Semantics.liveRegion`) widget. Its responsibility is the cross-cutting
  "render this app's canonical async-state vocabulary" — an app-level concern,
  which is the explicit alternative to "a second use" in §4.1.
- B8 (`docs/legalhub_bootstrap_specification.md` §3.9, ticket B8) authorized a
  shared set of reusable state widgets as foundation. `ViewStateView` is the
  widget half of that contract; `ViewState` is the data half. Deleting it would
  discard approved foundation work that later Cubits (Batch 4's
  `PasswordRecoveryCubit`) are designed to consume.

Retaining an unused-today foundation primitive is a different decision from
retaining a single-use leaf widget: the former is a contract waiting for its
first consumer that the architecture already promises; the latter is a coupling
risk. The ADR makes the distinction reviewable.

## Scope boundary

This ADR records the relocation and the `ViewStateView` retention rationale only.
It does not:

- relocate genuinely-shared widgets (`validators`, `AuthScaffold`,
  `PasswordField`, `LegalHubTextField`, `LabelledField`, `IconHeroBadge`,
  `LegalHubAppBar`);
- change any widget's appearance or behavior (the move is import-path-only); or
- wire `ViewStateView` into a feature (that is a later slice's decision).

## Consequences

- The `shared/` barrel now exposes only widgets with ≥2 consumers or a
  demonstrated app-level responsibility. "What is reusable" is answerable by
  reading the barrel.
- Single-consumer widgets now live next to their consumers, so a feature's
  presentation folder is self-contained for its own affordances.
- `ViewStateView` remains the renderer-of-record for `ViewState`. The
  retention question re-opens if no feature adopts `ViewState` by the time the
  first `ViewState`-driven Cubit lands; at that point it stops being
  "foundation awaiting a consumer" and becomes either proven-shared or dead
  code to remove.
- A future audit can re-check the barrel against the same rule; this ADR is the
  baseline for that comparison.

## Open condition

`ViewStateView`'s retention is justified by its cross-cutting contract, but the
cleaner proof is a real consumer. Batch 4 of the audit plan (`PasswordRecoveryCubit`)
is the first slice intended to drive a `ViewState`-powered flow; wiring it there
converts "retained by contract" into "retained by use." If that slice is
cancelled, revisit this decision.
