# LegalHub — Design: Invoice Tile Joins `AppTile` (2026-08-11)

> **Record type:** dated design doc for the second documented residual of the
> E1–E6 refactor close-out (`docs/refactor_close_out_2026-08-11.md` §4.2) —
> the billing `_InvoiceTile`, which does not fit `AppTile`'s single-subtitle
> row shape and carries a stray trailing gap.
>
> **Status: DESIGNED 2026-08-11** — not yet implemented. This doc pins the
> API change, the one-line behavior note, the tests, and the single owner
> decision before any code lands.
>
> **Relationship to E2:** `AppTile` (extracted) renders one optional
> `subtitle:` line; the invoice row needs **two** metadata lines and has no
> tap affordance. Rather than adding a second-line flag for one screen
> (flag sprawl), this design generalizes `subtitle: String?` to
> `subtitles: List<String>` — the honest shape for "one or more metadata
> lines" — and re-points the 9 existing call sites mechanically.

## 1. The duplication (as it stands today)

`_InvoiceTile` (`billing_invoices_screen.dart:110-172`) is the same
`radiusLg` outlined card row as every `AppTile` (avatar, title, metadata
lines, non-tappable), with two differences:

1. **Two metadata lines** — each preceded by the same 2px gap:
   ```
   Text('${invoice.currency} $amount · $status', bodySmall onSurfaceVariant),
   SizedBox(height: 2),
   Text('${invoice.matterRef} · $issued', bodySmall onSurfaceVariant),
   ```
2. **A stray trailing gap** — the Row ends with `SizedBox(width: spaceSm)`
   and nothing after it. This is the tappable-pattern leftover (`…, gap,
   chevron` with the chevron removed): the tile is non-tappable, so the
   empty 16px right inset has no function. No other non-tappable `AppTile`
   (document, approval, task rows) has it.

The row also differs from `AppTile` in nothing else: same Material, padding,
avatar+icon, title style.

## 2. The API change: `subtitle: String?` → `subtitles: List<String>`

In `lib/shared/widgets/app_tile.dart`:

```dart
class AppTile extends StatelessWidget {
  const AppTile({
    required this.title,
    this.subtitles = const <String>[],   // was: this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    super.key,
  });

  /// The metadata lines under the title (`bodySmall`, `onSurfaceVariant`),
  /// each separated by the standard 2px gap.
  final List<String> subtitles;
  ...
}
```

Rendering (byte-identical for the current single-line case):

```dart
for (final String line in subtitles) ...<Widget>[
  const SizedBox(height: 2),
  Text(line, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
],
```

### Re-points (mechanical)

| Site | Change |
|---|---|
| 9 `AppTile` call sites (search ×4, matter_list, document_list, message_list, approvals, tasks) | `subtitle: X` → `subtitles: <String>[X]` |
| `app_tile_test.dart` pump helper + assertions | `subtitle:` → `subtitles:` |
| `_InvoiceTile` | new `AppTile` call (below) |

All 9 current call sites pass a non-null single line, so no call site has
null-handling semantics to preserve; the empty default is unused today but
keeps the param optional.

## 3. The invoice tile

`_InvoiceTile` keeps its three computed strings (`amount`, `status`,
`issued`) and delegates:

```dart
return AppTile(
  icon: Icons.request_quote_outlined,
  title: invoice.invoiceNumber,
  subtitles: <String>[
    '${invoice.currency} $amount · $status',
    '${invoice.matterRef} · $issued',
  ],
);
```

(`onTap: null` — non-tappable, no InkWell, no chevron, matching today.)

## 4. Behavior note — the stray trailing gap (owner decision)

- **Recommended: drop it.** The `SizedBox(width: spaceSm)` is a leftover from
  the tappable pattern; the tile is non-tappable, and every other
  non-tappable `AppTile` renders without it. Dropping it removes a 16px
  right inset that has no function, making the billing row consistent with
  the document/approval/task rows. The two metadata lines, colors, fonts,
  and paddings are otherwise untouched.
- **Alternative (pure preservation):** keep the gap by rendering it only for
  this tile — a `trailingGap`-style flag on `AppTile` for a single leftover
  artifact. Rejected as flag sprawl unless the owner insists on
  pixel-perfection for the empty inset.
- **Decision required:** owner ratifies the cleanup (one-line note in this
  doc suffices) before the implementation lands; the gap removal is the only
  visual delta in the whole change.

## 5. Tests

`test/shared/widgets/app_tile_test.dart`:

1. Rename the existing subtitle assertions to `subtitles: <String>['Tile subtitle']`.
2. New: **two subtitle lines render both, each with the 2px gap** — find
   both texts; assert the render stays overflow-free at 320px (the invoice
   lines are the longest metadata the tile renders).
3. New: **empty `subtitles` renders no metadata lines.**
4. Existing render/tap/D-C2/D-MSG1/leading/trailing/theme/RTL tests stay,
   only the subtitle param name changes.

No existing screen tests change — billing's suite finds the same invoice
text lines. The responsive smoke suite already covers the billing screen at
320px.

## 6. Execution checklist

- [x] `app_tile.dart`: `subtitle` → `subtitles: List<String>` + doc comment
- [x] Re-point 9 `AppTile` call sites + the test helper
- [x] `_InvoiceTile` → `AppTile` with `subtitles: [line1, line2]` (gap
      dropped, owner-ratified)
- [x] `app_tile_test.dart`: rename + 2-line + empty-list tests (2 new)
- [x] README count 1231 → 1233; gates green: `dart format` clean,
      `flutter analyze` 0 issues, `flutter test` 1236 passed,
      `verify_ledger.sh` PASS, `verify_policy_tests.sh --check` PASS
- [x] Update `docs/refactor_close_out_2026-08-11.md` §4.2 → addressed
- [ ] Commit as `refactor(shared): generalize AppTile subtitles to multi-line (invoice tile)`

Estimated size: **S**. Risk: low — one param rename (9 mechanical sites) +
one tile delegation; the only judgment call (the stray gap) is explicit in
§4 for owner ratification.
