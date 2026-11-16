# LegalHub accessibility statement

This statement describes what is actually verified in this repository. It is
not a claim of full WCAG 2.2 conformance.

## Tested automatically

- **Flutter guideline matchers** (`test/accessibility/guideline_test.dart`) run
  on a representative set of surfaces: sign-in, sign-up, home, matters,
  messages, library index, saved, settings, account, profile, privacy and
  terms. For each surface the suite checks:
  - `labeledTapTargetGuideline` — every tappable semantics node carries a
    label (this is why icon-only controls have tooltips, and why the sign-up
    checkbox and legal links carry explicit `Semantics` labels);
  - `androidTapTargetGuideline` — tappable nodes are at least 48×48dp (this is
    why the "View matter" chip and the inline legal links have a 48dp floor).
- **Theme token contrast** (`test/accessibility/theme_contrast_test.dart`)
  computes WCAG relative luminance for 14 foreground/background token pairs
  (7 in light, 7 in dark) and requires at least **4.5:1** for body text. All 14
  pairs pass; the tightest is `onSecondaryContainer`/`secondaryContainer` at
  4.58:1. Nothing was recolored in this pass.
- **Responsive/RTL matrix** (`test/responsive/responsive_matrix_test.dart`)
  pumps every route — including the new `/privacy`, `/terms` and
  `/settings/account` — at six widths (320–1024px), at text scales 1.0, 2.0
  and 3.0, with an Arabic RTL case. A layout overflow fails the suite.
- **Localized plural**: the Home unread badge uses an ICU plural so zero, one
  and many render naturally in English, Arabic and Turkish
  (`test/features/notifications/notification_badge_test.dart`). The displayed
  count caps at `99+` and the full count is exposed in the Semantics label.

## Fixed in the Polish pass

- Password visibility toggle: was an unlabeled icon-only button; now has a
  localized `Show password` / `Hide password` tooltip.
- Sign-in / sign-up back buttons: were unlabeled icon buttons; now use the
  existing localized `Back` label as a tooltip.
- Sign-up terms checkbox: now carries a Semantics label naming both linked
  documents and its checked state.
- Inline Privacy/Terms links: were 24px-tall inline spans; now have a 48dp
  target without changing their visual weight.
- "View matter" chip in message/document rows: was a 24px-tall target; now has
  a 48dp minimum height.

## Not verified here

- **Real screen-reader passes** (TalkBack on Android, VoiceOver on iOS) have
  not been run on a device. Semantics labels are asserted in widget tests,
  which is not the same as a human listening to the announced output.
- Full WCAG conformance (including focus order, reading order, error
  identification beyond labels, non-text contrast for icons/borders, and
  text-spacing overrides) is **not** asserted.
- The built-in `textContrastGuideline` matcher is not used on whole screens:
  custom widgets derive colors from the theme at several levels, so the
  token-level test above is the meaningful contrast signal. A widget-level
  contrast failure would need a manual review rather than a matcher swap.

## Owner actions

- Run a device TalkBack / VoiceOver pass on the surfaces listed above before
  release.
- If golden baselines shift because of the 48dp tap-target fixes, regenerate
  them with `gh workflow run ci.yml -f update_goldens=true` and review the
  diff; do not hand-edit PNGs.
