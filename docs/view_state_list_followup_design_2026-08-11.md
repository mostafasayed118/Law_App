# LegalHub — Design: `ViewStateList` for the Pattern-B Screens (2026-08-11)

> **Record type:** dated design doc for the first documented residual of the
> E1–E6 refactor close-out (`docs/refactor_close_out_2026-08-11.md` §4.1) —
> the approvals, compliance-alerts, and task-board screens whose
> loading/empty/error/offline/unauthorized arms are ListView-wrapped with a
> local-only note, structurally different from the `ViewStateSwitch` arms
> extracted in E3.
>
> **Status: DESIGNED 2026-08-11** — not yet implemented. This doc pins the
> API, the rendering contract, the behavior-preservation notes, the tests,
> and the single owner decision before any code lands.
>
> **Relationship to E3:** `ViewStateSwitch` (extracted) renders the
> non-scrollable arms + a success `builder`; the pattern-B screens need a
> **scrollable** variant whose empty/error/success arms are ListViews with a
> footer note. Rather than adding scroll/note flags to `ViewStateSwitch`
> (flag sprawl), this design introduces a sibling `ViewStateList<T>` that
> shares the same visual vocabulary (identical loading arm, same error color
> scheme, same l10n `retry` label) but owns the ListView + note layout.

## 1. The duplication (as it stands today)

All three screens — `approvals_screen.dart`, `compliance_alerts_screen.dart`,
`task_board_screen.dart` — contain this exact switch, differing only in the
state field, the l10n keys, and the row tiles:

```dart
return switch (state.x) {                       // x = approvals | alerts | tasks
  ViewLoading() => Padding(all: spaceXl, Center(spinner)),
  ViewEmpty() => ListView(
    padding: marginMobile,
    children: [empty, SizedBox(spaceLg), Text(localOnlyNote, bodySmall onSurfaceVariant)],
  ),
  ViewError() => ListView(
    padding: marginMobile,
    children: [Text(error, bodyMedium error), TextButton(retry)],
  ),
  ViewOffline() || ViewUnauthorized() => empty,     // ← the quirk: plain, NOT note-wrapped
  ViewSuccess<List<X>>(data: list) => ListView(
    padding: marginMobile,
    children: [
      for (final item in list) ...[tile(item), SizedBox(spaceSm)],
      SizedBox(spaceLg),
      Text(localOnlyNote, bodySmall onSurfaceVariant),
    ],
  ),
};
```

| Screen | state field | empty | error | local-only note |
|---|---|---|---|---|
| approvals | `state.approvals` | `approvalsEmpty` | `approvalsError` | `approvalsLocalOnlyNote` |
| compliance | `state.alerts` | `alertsEmpty` | `alertsError` | `alertsLocalOnlyNote` |
| tasks | `state.tasks` | `tasksEmpty` | `tasksError` | `tasksLocalOnlyNote` |

Retry callbacks: `context.read<XxxCubit>().load()` per screen. Tiles:
`_ApprovalTile`, `_AlertTile`-equivalent, `_TaskTile` (each already a thin
`AppTile` wrapper after E2).

## 2. The shared widget: `ViewStateList<T>`

New file `lib/shared/widgets/view_state_list.dart` (barrel-exported), a
sibling of `ViewStateSwitch`:

```dart
class ViewStateList<T> extends StatelessWidget {
  const ViewStateList({
    required this.state,
    required this.onRetry,
    required this.itemBuilder,     // List<T> → the tile widgets (incl. inter-tile gaps)
    required this.empty,           // the plain empty copy widget (Padding + Text)
    required this.errorCopy,       // String
    required this.localOnlyNote,   // String — the footer note
    this.listPadding = const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
    super.key,
  });

  final ViewState<T> state;
  final VoidCallback onRetry;
  final List<Widget> Function(BuildContext context, List<T> data) itemBuilder;
  final Widget empty;
  final String errorCopy;
  final String localOnlyNote;
  final EdgeInsetsGeometry listPadding;
}
```

### Rendering contract (byte-identical to today's arms)

| Arm | Render |
|---|---|
| `ViewLoading` | `Padding(all: spaceXl, Center(CircularProgressIndicator))` |
| `ViewEmpty` | `ListView(listPadding, [empty, SizedBox(spaceLg), Text(note, bodySmall onSurfaceVariant)])` |
| `ViewError` | `ListView(listPadding, [Text(errorCopy, bodyMedium error), TextButton(retry)])` |
| `ViewOffline` / `ViewUnauthorized` | `empty` — **plain, unwrapped** (the quirk is preserved, see §4) |
| `ViewSuccess(data)` | `ListView(listPadding, [...itemBuilder(context, data), SizedBox(spaceLg), Text(note, bodySmall onSurfaceVariant)])` |

The note text styling (`bodySmall` + `onSurfaceVariant`) and the
`spaceLg`/`spaceSm` gaps live inside the widget; the caller supplies the
tiles-with-gaps via `itemBuilder`, mirroring the `ViewStateSwitch.builder`
convention (the `spaceSm` inter-tile gap stays the caller's concern, exactly
as it is in the current success arms).

## 3. Re-pointed call sites (3 screens)

Each screen keeps its `empty` widget construction (the `Padding(top: spaceMd,
Text(<emptyKey>, bodyMedium onSurfaceVariant))` block), its l10n keys, and its
cubit's `load`:

```dart
return ViewStateList<List<PendingApproval>>(
  state: state.approvals,
  onRetry: () => context.read<ApprovalsCubit>().load(),
  itemBuilder: (BuildContext context, List<PendingApproval> approvals) => [
    for (final approval in approvals) ...<Widget>[
      _ApprovalTile(approval: approval),
      const SizedBox(height: LegalHubTheme.spaceSm),
    ],
  ],
  empty: empty,
  errorCopy: l10n.approvalsError,
  localOnlyNote: l10n.approvalsLocalOnlyNote,
);
```

Compliance/tasks mirror with their keys, cubits, and tiles. The per-screen
switch (~35 lines each) collapses to one call (~15 lines each). The `empty`
local stays (used by both the widget and nothing else in the builder).

## 4. Behavior preservation

- **Every arm renders byte-identically** to today: same paddings, gaps,
  colors, styles, note placement, retry label (`l10n.retry` resolved
  internally, like `showConfirmDialog`'s cancel).
- **The offline/unauthorized quirk is preserved**: those two arms render the
  *plain* `empty` copy while the empty arm renders the note-wrapped ListView.
  This is an existing inconsistency (offline users see no note), but it is
  today's behavior and is pinned, not silently "fixed".
- **Owner decision (optional, NOT required to ship):** if the owner wants
  offline/unauthorized to render the note-wrapped empty arm for consistency,
  that is a one-line change inside `ViewStateList` (route both arms to the
  empty-arm render) + a re-pinned test. It is recorded here as a separate
  decision so the extraction itself needs no behavioral judgment.

## 5. Tests

New `test/shared/widgets/view_state_list_test.dart`, mirroring the
`ViewStateSwitch` suite:

1. loading → spinner, no list
2. empty → note-wrapped ListView with the empty copy + note text
3. offline and unauthorized → plain empty copy, **no note** (the quirk pin)
4. error → error copy + retry, retry tap fires `onRetry`
5. success → items then `spaceLg`-gap then the note
6. RTL + 320px no-overflow

No existing tests are deleted or weakened; the three screens' suites must
stay green unchanged (they find the same text/labels).

## 6. Execution checklist

- [x] `lib/shared/widgets/view_state_list.dart` + barrel export
- [x] Re-point `approvals_screen.dart`, `compliance_alerts_screen.dart`,
      `task_board_screen.dart`
- [x] `test/shared/widgets/view_state_list_test.dart` (6 tests)
- [x] README count 1225 → 1231; gates green: `dart format` clean,
      `flutter analyze` 0 issues, `flutter test` 1234 passed,
      `verify_ledger.sh` PASS 115/0/0, `verify_policy_tests.sh --check`
      PASS 73/0/0
- [x] Update `docs/refactor_close_out_2026-08-11.md` §4.1 → addressed
- [ ] Commit as `refactor(shared): extract ViewStateList for note-wrapped list screens`

Estimated size: **S** (one widget + 3 mechanical re-points + one test file).
Risk: low — the rendering contract is pinned by tests; the only judgment
call (offline quirk) is explicitly preserved by default.
