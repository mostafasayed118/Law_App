import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'discovery_cubit.dart';
import 'discovery_state.dart';

part 'attorney_search_field.dart';
part 'attorney_search_surface.dart';
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
  /// [initialPracticeArea] seeds the practice-area chip from the home
  /// dashboard's practice-area cards (`/discovery?area=…`, the D-S4 wiring):
  /// the list opens pre-filtered to the tapped area. Null (the plain
  /// `/discovery` entries) opens on "All".
  const AttorneySearchScreen({this.initialPracticeArea, super.key});

  final PracticeArea? initialPracticeArea;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DiscoveryCubit>(
      create: (BuildContext context) => DiscoveryCubit(
        serviceLocator<AttorneyGateway>(),
        initialPracticeArea: initialPracticeArea,
      ),
      child: const _SearchSurface(),
    );
  }
}
