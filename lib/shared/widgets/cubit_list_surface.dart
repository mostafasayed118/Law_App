import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/legalhub_theme.dart';
import '../../core/state/view_state.dart';
import 'view_state_list.dart';

part 'cubit_list_surface_body.dart';

/// The cubit-scoped list-surface shell (audit 2026-09-21, M-10).
///
/// Five screens — approvals, compliance alerts, task board, billing invoices
/// and the notification feed — repeated this skeleton near-verbatim: a
/// `Scaffold` body that provides a cubit, a surface widget whose `initState`
/// schedules the first load in a post-frame callback, and a `SafeArea` +
/// `BlocBuilder` rendering a [ViewStateList]. The audit found the duplication
/// was not just the switch but the *scaffolding around* it, with three pairs
/// byte-identical.
///
/// Each call site now supplies only what actually differs: the cubit factory,
/// the state→rows projection, the load call, the row tile, and the copy.
///
/// Not every list screen fits: `document_list_screen` and
/// `message_list_screen` each drive **two** cubits (their list plus the matter
/// list that resolves the matter-ref chips), so they keep their own shells.
class CubitListSurface<C extends Cubit<S>, S, ItemT> extends StatelessWidget {
  const CubitListSurface({
    required this.createCubit,
    required this.project,
    required this.load,
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

  /// Builds the screen's cubit, e.g.
  /// `() => ApprovalsCubit(serviceLocator<ApprovalsGateway>())`.
  final C Function() createCubit;

  /// Projects the cubit state onto the rows this surface renders.
  final ViewState<List<ItemT>> Function(S state) project;

  /// Runs the load. Invoked once from a post-frame callback on mount — the
  /// repo's pattern, because the cubit's initial state is already loading and
  /// a synchronous call in `initState` would emit during the first build —
  /// and again from the error arm's retry.
  final void Function(C cubit) load;

  /// One row.
  final Widget Function(BuildContext context, ItemT item) tileBuilder;

  /// The empty copy. A builder rather than a widget because it may depend on
  /// state: the notification feed's muted-empty copy differs from its plain
  /// empty copy.
  final Widget Function(BuildContext context, S state) empty;

  /// The feature's error copy, rendered above the retry button.
  final String errorCopy;

  /// The footer note under the empty copy and the rows.
  final String localOnlyNote;

  /// Optional widgets that scroll with the content, above every arm.
  final List<Widget> header;

  /// The list padding.
  final EdgeInsetsGeometry listPadding;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<C>(
      create: (BuildContext context) => createCubit(),
      child: _CubitListSurfaceBody<C, S, ItemT>(
        project: project,
        load: load,
        tileBuilder: tileBuilder,
        empty: empty,
        errorCopy: errorCopy,
        localOnlyNote: localOnlyNote,
        header: header,
        listPadding: listPadding,
      ),
    );
  }
}
