# ADR-0006: primaryContainer remains #1A2B3C (tracked deviation from spec #0b1d2e)

- Status: Superseded by ADR-0008 (2026-08-01)
- Date: 2026-07-31
- Related: ADR-0005 (canonical `primary` = `#0b1d2e`), D-10 (canonical design
  system), `docs/legalhub_specification.md` §5.1, ADR-0002 (dark theme approved
  as-is).
- Supersedes: the untracked "follow-up finding" note in ADR-0005's scope
  boundary and open condition.

## Context

`docs/legalhub_specification.md` §5.1 names the light-theme `primary-container`
token as `#0b1d2e` (identical to `primary`). ADR-0005 reconciled the `primary`
token to `#0b1d2e` but explicitly left `primary-container` out of scope, noting
it as a "separate, visible-surface deviation" to be tracked.

`lib/app/legalhub_theme.dart` declares `primaryContainer` as `#1A2B3C`, not the
spec's `#0b1d2e`. Unlike the `primary` drift ADR-0005 fixed (which was an
undocumented third value matching no spec reference), this is a deliberate
two-value divergence:

- The spec says `primary-container = #0b1d2e` (same as `primary`).
- The code uses `#1A2B3C` — a lighter ink-navy that gives ElevatedButton
  surfaces and card containers visible separation from the `primary` app-bar
  foreground.

`primary-container` backs rendered container surfaces (ElevatedButton
backgrounds, card containers), so changing it is a visible-surface change, not
a near-invisible tone shift like the `#041627` → `#0b1d2e` `primary` fix. It
must be reviewed under EN/AR/RTL + light/dark before adoption, and it may turn
out that `#1A2B3C` is the better product value — in which case the spec, not
the code, should change. Either way, the divergence is currently undocumented
in any decision record, which makes the single-source-of-truth (D-10) invariant
uncheckable.

## Decision

Record `primary-container = #1A2B3C` as an **accepted, tracked deviation** from
the spec value `#0b1d2e`. Do **not** silently reconcile it here. The
reconciliation is deferred to a dedicated design-review slice that:

1. renders the affected container surfaces (ElevatedButton, cards) under
   EN/AR/RTL and light/dark with both candidate values;
2. decides whether the code (`#1A2B3C`) or the spec (`#0b1d2e`) is canonical;
3. updates the *other* side to match — i.e. if `#1A2B3C` wins, the spec table in
   `docs/legalhub_specification.md` §5.1 is updated, not the code; if
   `#0b1d2e` wins, the code is updated; and
4. records the outcome as a superseding ADR.

Until that slice, `#1A2B3C` is the value of record for `primary-container`, and
the existing theme test (`test/app/legalhub_theme_test.dart`) that pins
`light primaryContainer is #1A2B3C — a tracked deviation from spec #0b1d2e`
remains the regression guard.

## Scope boundary

This ADR records the deviation and its deferred-resolution path only. It does
**not**:

- change `primary-container` in `lib/app/legalhub_theme.dart`;
- change the spec value in `docs/legalhub_specification.md` §5.1;
- alter any dark-theme token (ADR-0002 approved the dark set as-is); or
- decide which value is canonical — that is the deferred design review's job.

## Consequences

- The D-10 "single source of truth" invariant is *checkable* again: the
  divergence is now named in a decision record rather than buried in a prose
  README paragraph, so a future audit can find it by reading the ADR log.
- The theme test pinning `#1A2B3C` is now justified by an ADR, not an
  untracked comment.
- A future reviewer who reconciles `primary-container` has a single ADR to
  supersede rather than a scattered note to hunt for.

## Open condition

The reconciliation slice (Batch 5 of the current audit plan, or a dedicated
design-review batch) must render both candidate values under EN/AR/RTL +
light/dark and supersede this ADR with the chosen value. Until then, this ADR
is the standing record that the code and spec disagree on purpose, not by
accident.

**Closed by ADR-0008 (2026-08-01):** Batch 5 rendered both candidates, chose
the code value `#1A2B3C`, and updated the spec table — this ADR is superseded.
