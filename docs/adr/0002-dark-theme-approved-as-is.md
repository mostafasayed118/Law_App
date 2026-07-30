# ADR-0002: Dark theme tokens approved as-is

- Status: **Accepted** (dark theme retroactively approved; implementation
  retained)
- Date: 2026-07-30 (deferred), 2026-07-30 (accepted)
- Related decision: D-14 (dark theme).
- Decision owner: Product/design owner (approval recorded 2026-07-30).

## Context

The approved bootstrap specification (`docs/legalhub_bootstrap_specification.md`)
originally scoped the foundation to a **light-only** theme; dark mode was
explicitly deferred (D-14). Despite that, the working tree defined full dark
token sets in `lib/app/legalhub_theme.dart` and `lib/main.dart` wired both
`darkTheme` and `themeMode: ThemeMode.system`, so a device in dark mode already
rendered a dark UI. This was scope creep relative to the original approved
bootstrap spec and was recorded in the Deferred status of this ADR.

## Decision

**Approve dark mode retroactively.** The product/design owner accepted option
(a) from the prior escalation: the dark tokens are in-scope and the existing
`darkTheme` + `ThemeMode.system` wiring in `lib/main.dart` and
`lib/app/legalhub_theme.dart` is the approved behavior. D-14 is therefore
closed in favor of dark mode being part of the foundation.

No code change is required as a result of this decision; the implementation
already in the tree is the approved state.

## Consequences

- Devices in system-dark mode render a dark LegalHub UI. This is the intended
  behavior and remains disclosed via the README coverage map.
- New dark-mode design work may build on the existing dark tokens; it does not
  require a separate per-screen dark-token approval, only the standard design
  review.
- Should the decision be reversed later, the removal is a single, contained
  change: drop the dark token sets, set `themeMode: ThemeMode.light`, and remove
  the `darkTheme:` parameter in `lib/main.dart`.
- D-14 ("dark theme") is resolved as **dark mode approved**, superseding its
  earlier "open"/"deferred" state in the decision register.
