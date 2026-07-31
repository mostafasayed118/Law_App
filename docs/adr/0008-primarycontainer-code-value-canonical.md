# ADR-0008: primaryContainer canonical value is #1A2B3C (spec table updated)

- Status: Accepted
- Date: 2026-08-01
- Related: ADR-0006 (tracked deviation, superseded), ADR-0005 (canonical
  `primary` = `#0b1d2e`), D-10 (canonical design system),
  `docs/legalhub_specification.md` §5.1.
- Supersedes: ADR-0006.

## Context

ADR-0006 recorded `primary-container = #1A2B3C` in code vs `#0b1d2e` in the
spec as an accepted, tracked deviation, and required a dedicated
reconciliation slice that:

1. renders the affected container surfaces (ElevatedButton, cards) under
   EN/AR/RTL and light/dark with both candidate values;
2. decides whether the code (`#1A2B3C`) or the spec (`#0b1d2e`) is canonical;
3. updates the *other* side to match; and
4. records the outcome as a superseding ADR.

This ADR is that superseding record. The render was produced on 2026-08-01 as
a side-by-side comparison of both candidates on the real consumer surfaces:
the onboarding Continue button (ElevatedButton with
`primaryContainer`/`onPrimaryContainer`), the home-greeting avatar, the
carousel page-indicator active dot, and the practice-area icon chip
(`primaryContainer`/`onPrimary`). WCAG 2.1 contrast for both pairs was
computed live from relative luminance.

## Decision

**`#1A2B3C` (the code value) is canonical for light-theme `primary-container`.**
The spec table in `docs/legalhub_specification.md` §5.1 is updated to match
the code — not the reverse. The paired `on-primary-container` row is likewise
updated from spec `#74859b` to code `#8192a7` so the container surface pair is
internally consistent.

Rationale, from the render and token semantics:

- **The container role collapses at the spec value.** Spec `#0b1d2e` is
  *identical* to `primary`. A `primaryContainer` that equals `primary` makes
  ElevatedButton surfaces, avatars, dots, and icon chips indistinguishable
  from the solid-primary app-bar foreground — the very separation the M3
  container token exists to provide. `#1A2B3C` (a lighter ink-navy) keeps a
  visible tonal step between `primary` and the container surfaces.
- **Contrast is a tie — both pairs pass AA for normal text.** Code pair
  `#1A2B3C`/`#8192A7` ≈ 4.54:1; spec pair `#0b1d2e`/`#74859b` ≈ 4.53:1;
  the `onPrimary` icon chips exceed 14:1 on both. Accessibility does not
  decide between the candidates.
- **The spec value is an artifact of the §5.1 primary-row normalization.**
  §5.1's primary row already notes the design files listed `primary:#000000`
  and the narrative normalized everything to Midnight Blue; the
  `primary-container` row inherited that normalization. It is not a
  separately-designed container value, whereas `#1A2B3C` is the value that has
  shipped, rendered, and been reviewed across the onboarding and home
  surfaces.
- **Dark tokens are untouched** (ADR-0002 approved the dark set as-is;
  `darkPrimaryContainer = #D2E4FB` is unaffected).

## What changed

- `docs/legalhub_specification.md` §5.1: `primary-container` row
  `#0b1d2e` → `#1a2b3c`; `on-primary-container` row `#74859b` → `#8192a7`.
- No code change: `lib/app/legalhub_theme.dart` already declares the
  canonical values (`primaryContainer = #1A2B3C`,
  `onPrimaryContainer = #8192A7`).
- The theme regression guard (`test/app/legalhub_theme_test.dart`) continues
  to pin `#1A2B3C`, now justified by this ADR rather than as a deviation.

## Consequences

- D-10 "single source of truth" is restored for the container pair: spec and
  code now agree at `#1A2B3C`/`#8192a7`.
- ADR-0006 is superseded; its "Open condition" is closed by this ADR.
- ADR-0005's open condition ("primary-container is a separate deviation to be
  reconciled in a follow-up batch") is now also closed by this ADR.
- A future change to the container value requires updating both the spec
  table and the theme pin — the D-10 invariant stays checkable.
