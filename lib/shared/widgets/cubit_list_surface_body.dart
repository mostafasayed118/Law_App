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
}
