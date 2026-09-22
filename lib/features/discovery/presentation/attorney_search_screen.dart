import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/practice_area.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/attorney.dart';
import '../domain/attorney_gateway.dart';
import 'discovery_cubit.dart';
import 'discovery_state.dart';
part 'attorney_search_surface.dart';
part 'attorney_search_field.dart';
part 'attorney_search_tile.dart';

/// Attorney-discovery search surface (Phase 6, slice 6.1).
///
/// A `/discovery` route that loads the profile list from the [AttorneyGateway]
/// seam (the dev fake in env-less runs, owner decision D-A2). Search is a
/// client-side filter over that list (D-A5): a free-text query plus
/// practice-area chips; no server search RPC exists. All copy is local-only —
/// the synthetic list must never read as a real directory (R1/D-A4). Profile
/// navigation lands in slice 6.2, so the list rows are not tappable yet; the
/// tile's tap affordance (and chevron) arrives with profile navigation.
class AttorneySearchScreen extends StatelessWidget {
  const AttorneySearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DiscoveryCubit>(
      create: (BuildContext context) =>
          DiscoveryCubit(serviceLocator<AttorneyGateway>()),
      child: const _SearchSurface(),
    );
  }
}
