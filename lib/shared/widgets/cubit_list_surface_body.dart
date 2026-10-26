part of 'cubit_list_surface.dart';

class _CubitListSurfaceBody<C extends Cubit<S>, S, ItemT>
    extends StatefulWidget {
  const _CubitListSurfaceBody({
    required this.project,
    required this.load,
    required this.tileBuilder,
    required this.empty,
    required this.errorCopy,
    required this.localOnlyNote,
    required this.header,
    required this.listPadding,
  });

  final ViewState<List<ItemT>> Function(S state) project;
  final void Function(C cubit) load;
  final Widget Function(BuildContext context, ItemT item) tileBuilder;
  final Widget Function(BuildContext context, S state) empty;
  final String errorCopy;
  final String localOnlyNote;
  final List<Widget> header;
  final EdgeInsetsGeometry listPadding;

  @override
  State<_CubitListSurfaceBody<C, S, ItemT>> createState() =>
      _CubitListSurfaceBodyState<C, S, ItemT>();
}

class _CubitListSurfaceBodyState<C extends Cubit<S>, S, ItemT>
    extends State<_CubitListSurfaceBody<C, S, ItemT>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.load(context.read<C>());
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<C, S>(
        // Rebuild tiles only when the projected list actually changes — a
        // filter/prefs emission on the same rows must not re-run the list.
        buildWhen: (S previous, S current) =>
            !_sameProjection(widget.project(previous), widget.project(current)),
        builder: (BuildContext context, S state) {
          final C cubit = context.read<C>();
          return ViewStateList<ItemT>(
            state: widget.project(state),
            onRetry: () => widget.load(cubit),
            tileBuilder: widget.tileBuilder,
            empty: widget.empty(context, state),
            errorCopy: widget.errorCopy,
            localOnlyNote: widget.localOnlyNote,
            header: widget.header,
            listPadding: widget.listPadding,
          );
        },
      ),
    );
  }

  /// Same arm and same payload: the loading/empty/offline/unauthorized arms
  /// carry no data, a success arm compares its items (identity first, then
  /// value), and an error arm compares the typed error.
  bool _sameProjection(ViewState<List<ItemT>> a, ViewState<List<ItemT>> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.runtimeType != b.runtimeType) {
      return false;
    }
    return switch (a) {
      ViewSuccess<List<ItemT>>(data: final List<ItemT> items) => switch (b) {
        ViewSuccess<List<ItemT>>(data: final List<ItemT> other) => _sameItems(
          items,
          other,
        ),
        _ => false,
      },
      ViewError<List<ItemT>>(error: final error) => switch (b) {
        ViewError<List<ItemT>>(error: final other) => error == other,
        _ => false,
      },
      _ => true,
    };
  }

  /// Element-wise equality, with the identity fast path for the common case
  /// where the cubit carried the same list instance through an emission.
  bool _sameItems(List<ItemT> a, List<ItemT> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
