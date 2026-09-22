import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/matter.dart';
import '../domain/matter_gateway.dart';
import 'matter_cubit.dart';
import 'matter_labels.dart';
import 'matter_state.dart';
import 'matter_status_chip.dart';

part 'matter_list_surface.dart';

/// Matter-dashboard list surface (Phase 7, slice 7.1).
///
/// A `/matters` route that loads the matter list from the [MatterGateway]
/// seam (the dev fake in env-less runs, owner decision D-M2). The status
/// filter is a client-side projection over that list (D-M5); no server
/// search RPC exists. All copy is local-only — the synthetic list must never
/// read as real cases (R1/D-M4). Tapping a row (slice 7.2) navigates to the
/// read-only details surface (`/matters/:id`, AC-3).
class MatterListScreen extends StatelessWidget {
  const MatterListScreen({super.key, this.canCreateMatter = false});

  /// F-01 step 2 client swap (C-D6/Q5): whether the create-matter entry is
  /// offered. A UX-only partner gate resolved by the router (the shell's
  /// capability pattern); `create_matter` re-asserts F2-D1 server-side, so
  /// this is a navigation hint, never an authorization grant.
  final bool canCreateMatter;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MatterCubit>(
      create: (BuildContext context) =>
          MatterCubit(serviceLocator<MatterGateway>()),
      child: _ListSurface(canCreateMatter: canCreateMatter),
    );
  }
}
