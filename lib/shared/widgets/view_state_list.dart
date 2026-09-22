import 'package:flutter/material.dart';

import '../../app/legalhub_theme.dart';
import '../../core/state/view_state.dart';
import '../../l10n/app_localizations.dart';

/// A scrollable variant of [ViewStateSwitch] for list screens whose arms are
/// `ListView`s with a local-only-note footer.
///
/// Follow-up extraction (designed 2026-08-11): the approvals, compliance,
/// and task-board screens duplicated this exact switch — a `spaceXl`-padded
/// loading spinner, a note-wrapped empty arm, a ListView error arm, and a
/// success ListView of tiles followed by the same footer note. Each call
/// site supplies its feature's empty widget, error copy, retry callback,
/// local-only note, and tile builder; the arms render identically
/// everywhere.
///
/// Behavior note: the offline/unauthorized arms render the same
/// note-wrapped empty ListView as the empty arm — normalized per the owner
/// decision recorded in the design doc's §4 (previously they rendered the
/// plain empty copy, an inconsistency of the pre-extraction screens).
///
/// Lazy success arm (audit 2026-09-21, P4): the widget is generic over the
/// **item** type ([ItemT]) and its success arm is a [ListView.builder] —
/// tiles are built on demand for the visible viewport instead of eagerly
/// mapping the whole data list into children. The inter-tile `spaceSm` gap,
/// the pre-footer `spaceLg` gap, and the footer note are owned by the
/// widget; call sites supply only the tile for one item via [tileBuilder].
///
/// Optional [header] (audit 2026-09-21, M-20 follow-up): screens that keep a
/// filter row or search field inside the same scroll view pass it here
/// instead of wrapping this widget in another scrollable. The header is
/// prepended to every arm's children, so it scrolls away with the content.
class ViewStateList<ItemT> extends StatelessWidget {
  const ViewStateList({
    required this.state,
    required this.onRetry,
    required this.tileBuilder,
    required this.empty,
    required this.errorCopy,
    required this.localOnlyNote,
    this.header = const <Widget>[],
    this.listPadding = const EdgeInsetsDirectional.all(
      LegalHubTheme.marginMobile,
    ),
    super.key,
  });

  /// The state driving the switch. The success payload is the item list.
  final ViewState<List<ItemT>> state;

  /// Retry callback wired to the error arm's `TextButton`.
  final VoidCallback onRetry;

  /// The success arm's tile for one item. Built lazily — only for indices
  /// inside the visible viewport. The inter-tile gap is rendered by this
  /// widget, not the builder.
  final Widget Function(BuildContext context, ItemT item) tileBuilder;

  /// The feature's plain empty copy, rendered inside the note-wrapped
  /// ListView for empty, offline, and unauthorized alike.
  final Widget empty;

  /// The feature's error copy, rendered above the retry button.
  final String errorCopy;

  /// The footer note under the empty copy and the success tiles.
  final String localOnlyNote;

  /// Optional widgets that scroll with the content, above every arm — the
  /// filter chips or search field of screens that keep a header inside the
  /// same scroll view (matters, discovery).
  ///
  /// They are **prepended to the arm's children** rather than wrapped around
  /// the list: that is exactly how those screens already compose the header
  /// today, so the header keeps scrolling away with the content instead of
  /// being pinned, and no nested scrollable is created (an inner `ListView`
  /// inside a `ListView` would have unbounded height).
  final List<Widget> header;

  /// The ListView padding on the empty, error, and success arms.
  final EdgeInsetsGeometry listPadding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget note = Text(
      localOnlyNote,
      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
    return switch (state) {
      ViewLoading<List<ItemT>>() => const Padding(
        padding: EdgeInsetsDirectional.all(LegalHubTheme.spaceXl),
        child: Center(child: CircularProgressIndicator()),
      ),
      ViewEmpty<List<ItemT>>() => ListView(
        padding: listPadding,
        children: <Widget>[
          ...header,
          empty,
          const SizedBox(height: LegalHubTheme.spaceLg),
          note,
        ],
      ),
      // Offline is retryable; unauthorized is not (no retry affordance).
      // Both used to render the empty arm (audit M-1) — a denial then read as
      // "nothing here yet" rather than "you may not see this".
      ViewOffline<List<ItemT>>() => ListView(
        padding: listPadding,
        children: <Widget>[
          ...header,
          Text(
            l10n.stateOffline,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
      ViewUnauthorized<List<ItemT>>() => ListView(
        padding: listPadding,
        children: <Widget>[
          ...header,
          Text(
            l10n.stateUnauthorized,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      ViewError<List<ItemT>>() => ListView(
        padding: listPadding,
        children: <Widget>[
          ...header,
          Text(
            errorCopy,
            style: text.bodyMedium?.copyWith(color: scheme.error),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
      // An empty SUCCESS renders the empty arm. Some cubits emit
      // `ViewSuccess(<empty>)` rather than `ViewEmpty` — the research slice
      // does exactly that for a no-match query — and "loaded, but there is
      // nothing" is the empty state either way. Every ViewStateSwitch call
      // site used to re-implement this with `list.isEmpty ? empty : Column(…)`;
      // owning it here is what lets those sites drop the branch (M-10/M-20).
      ViewSuccess<List<ItemT>>(data: final List<ItemT> data)
          when data.isEmpty =>
        ListView(
          padding: listPadding,
          children: <Widget>[
            ...header,
            empty,
            const SizedBox(height: LegalHubTheme.spaceLg),
            note,
          ],
        ),
      ViewSuccess<List<ItemT>>(data: final List<ItemT> data) =>
        _SuccessListView<ItemT>(
          items: data,
          tileBuilder: tileBuilder,
          localOnlyNote: note,
          listPadding: listPadding,
          header: header,
        ),
    };
  }
}

/// The success arm as a lazily-built list: [ListView.builder] constructs
/// only the visible rows. The layout matches the previous eager arm —
/// tile, `spaceSm` gap, tile, … last tile, `spaceLg` gap, footer note —
/// expressed as `header.length + items.length + 2` rows, where the optional
/// header occupies the leading rows and the two trailing rows are the
/// pre-footer gap and the note.
class _SuccessListView<ItemT> extends StatelessWidget {
  const _SuccessListView({
    required this.items,
    required this.tileBuilder,
    required this.localOnlyNote,
    required this.listPadding,
    required this.header,
  });

  final List<ItemT> items;
  final Widget Function(BuildContext context, ItemT item) tileBuilder;
  final Widget localOnlyNote;
  final EdgeInsetsGeometry listPadding;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final int headerCount = header.length;
    final int contentCount = items.length + 2;
    final int itemCount = headerCount + contentCount;
    return ListView.builder(
      padding: listPadding,
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        if (index < headerCount) {
          return header[index];
        }
        final int i = index - headerCount;
        if (i == contentCount - 1) {
          return localOnlyNote;
        }
        if (i == contentCount - 2) {
          return const SizedBox(height: LegalHubTheme.spaceLg);
        }
        final Widget tile = tileBuilder(context, items[i]);
        if (i == contentCount - 3) {
          return tile;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            tile,
            const SizedBox(height: LegalHubTheme.spaceSm),
          ],
        );
      },
    );
  }
}
