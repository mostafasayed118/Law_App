part of 'view_state_list.dart';

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
