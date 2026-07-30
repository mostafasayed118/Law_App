# ADR-0001: Product brand is LegalHub

- Status: Accepted
- Date: 2026-07-30
- Supersedes: the stale "Lexis" / "Lex Juris" wordmarks present in early
  bootstrap drafts.
- Related decision: D-01 (product decision log), D-10 (design tokens).

## Context

Early bootstrap code and design-archive references used "Lexis" as the
wordmark and "Lex Juris" as the design-system name. The confirmed product
decision (D-01) mandates the brand name **LegalHub**. Before the auth and
onboarding screens were reused more widely, the violation was propagating:
every screen that embedded `LegalHubAppBar` or the `newToLexis` localization
key inherited the wrong brand.

## Decision

The product brand is **LegalHub**. The wordmark is sourced from the localized
`AppLocalizations.appTitle` getter — not hardcoded — so all three locales
(EN/AR/TR) render the same canonical brand. The design-system documentation
references LegalHub (D-10) instead of "Lex Juris". The `newToLexis` localization
key was renamed to `newToLegalHub` across the `.arb` files and the generated
bindings were regenerated with `flutter gen-l10n`.

## Consequences

- User-facing strings and the app-bar wordmark consistently read "LegalHub".
- A regression is detectable: `test/auth/sign_in_screen_test.dart` asserts
  `find.textContaining('Lexis')` finds nothing on the sign-in screen.
- Any new screen that needs the wordmark must use `AppLocalizations.appTitle`
  rather than a string literal.
