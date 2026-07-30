# ADR-0002: Dark theme tokens are defined and wired but deferred

- Status: Deferred (implementation retained, approval pending)
- Date: 2026-07-30
- Related decision: D-14 (dark theme was explicitly out of the approved
  bootstrap scope).

## Context

The approved bootstrap specification (`docs/legalhub_bootstrap_specification.md`)
scoped the foundation to a **light-only** theme; dark mode was explicitly
deferred (D-14). Despite that, the working tree defines full dark token sets in
`lib/app/legalhub_theme.dart` and `lib/main.dart` wires both `darkTheme` and
`themeMode: ThemeMode.system`, so a device in dark mode already renders a dark
UI. This is scope creep relative to the approved bootstrap spec.

## Decision

**Do not delete the dark-theme implementation unilaterally.** The dark tokens
are implemented, tested indirectly by the boot widget flow, and cheap to keep.
Deleting them would discard verified work and is a destructive call that belongs
to the design owner, not engineering. Instead:

1. Keep `darkTheme` and `ThemeMode.system` wiring as-is for now.
2. Record this ADR so the deviation is visible to reviewers.
3. Escalate the actual decision to the design owner:
   - (a) Approve dark mode retroactively (accept the dark tokens as in-scope),
     or
   - (b) Remove the dark tokens and force `themeMode: ThemeMode.light` to match
     the original approved scope.

Until that call is made, the dark theme is treated as **deferred, not
approved**. No new dark-only design work should be built on top of these tokens
without the design owner's sign-off.

## Consequences

- Devices in system-dark mode currently render a dark LegalHub UI. This is
  visible to reviewers and must be disclosed (it is, via this ADR and the
  README coverage map).
- If the design owner chooses (b), the removal is a single, contained change:
  drop the dark token sets, set `themeMode: ThemeMode.light`, and remove the
  `darkTheme:` parameter in `lib/main.dart`.
- This ADR does not approve D-14; it records the deviation.
