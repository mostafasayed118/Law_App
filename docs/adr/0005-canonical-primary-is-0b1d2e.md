# ADR-0005: Canonical primary token is Midnight Blue #0b1d2e

- Status: Accepted
- Date: 2026-07-30
- Related: D-10 (canonical design system), `docs/legalhub_specification.md`
  §5.1, `docs/legalhub_bootstrap_specification.md` §5.1, ADR-0002.
- Supersedes: the undocumented use of `#041627` as `primary` in
  `lib/app/legalhub_theme.dart`.

## Context

The canonical design-system specification names the light-theme `primary`
token in four places, all consistently:

- `docs/legalhub_specification.md` §5.1 primary row: `#0b1d2e`
  (Midnight/Ink Blue), with a note that the design files' `primary:#000000`
  is to be overridden.
- `docs/legalhub_specification.md` §5.1 `primary-container` row: `#0b1d2e`.
- `docs/legalhub_bootstrap_specification.md` §1: "Canonical primary is
  **Midnight Blue `#0b1d2e`** (not `#000000`)."
- `docs/legalhub_bootstrap_specification.md` §7 (B5 acceptance): the theme
  package passes when `primary=#0b1d2e`.

Despite this, `lib/app/legalhub_theme.dart` declared
`static const Color primary = Color(0xFF041627)`. The value `#041627` is
mentioned in the spec only once, parenthetically, as an alternate Midnight
Blue candidate alongside `#0b1d2e` in the `primary-container` narrative; it
is never named as the canonical `primary`. The spec's own readiness
checklist still had `[ ] primary value confirmed as Midnight Blue #0b1d2e`
unchecked.

This is a D-10 (single source of truth) deviation: the code's `primary`
matched neither the documented canonical value nor the design files' raw
value — it was an undocumented third option. The `primary` token drives
app-bar foreground, display/headline text colors, the sign-up link, the OTP
focus border, and home/icon tints, so the drift was already propagating.

## Decision

Adopt **`#0b1d2e`** as the canonical light-theme `primary` token in
`lib/app/legalhub_theme.dart`, matching the value named as canonical in every
specification reference. The dark-theme `darkOnPrimary` remains `#041627`
(it is a distinct dark-surface tone and is out of scope for this decision).

The change is a small, contained shift between two near-identical ink-navy
shades (`#041627` → `#0b1d2e`), but it brings the code into compliance with
the single-source design contract and closes the open readiness-checklist
item for `primary`.

## Scope boundary

This ADR records the `primary` reconciliation only. It does **not**:

- reconcile `primary-container` (spec says `#0b1d2e`; code uses `#1A2B3C`).
  That is a separate, visible-surface deviation (it backs ElevatedButton and
  card backgrounds) and is tracked as a follow-up finding, not silently
  fixed here, because it changes rendered containers and warrants its own
  review;
- alter the dark-theme token set (approved as-is by ADR-0002); or
- introduce any new token.

## Consequences

- The light-theme `primary` now matches the documented canonical value; the
  B5 acceptance criterion (`primary=#0b1d2e`) is satisfied.
- The D-10 "single source of truth" invariant is restored for `primary`.
- A regression is detectable: any future drift can be checked against this
  ADR and the spec table.
- `primary-container` remains a known, tracked deviation to be reconciled
  in a later slice with a design review.

## Open condition

`primary-container` (`#1A2B3C` in code vs `#0b1d2e` in spec) is a separate
deviation recorded here for traceability. It should be reconciled in a
follow-up batch that reviews the rendered container surfaces under
EN/AR/RTL + light/dark before adopting the spec value.
