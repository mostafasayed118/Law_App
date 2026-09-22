import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/roles/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../../discovery/domain/attorney.dart';
import '../../discovery/domain/attorney_gateway.dart';
import '../../documents/domain/document.dart';
import '../../documents/domain/document_gateway.dart';
import '../../documents/presentation/document_labels.dart';
import '../../documents/presentation/document_type_chip.dart';
import '../../matters/domain/matter.dart';
import '../../matters/domain/matter_gateway.dart';
import '../../matters/presentation/matter_labels.dart' show matterStatusLabel;
import '../../matters/presentation/matter_status_chip.dart';
import '../../messaging/domain/message_gateway.dart';
import '../../messaging/domain/message_thread.dart';
import '../../messaging/presentation/message_count_chip.dart';
import '../domain/search_results.dart';
import 'search_cubit.dart';
import 'search_state.dart';

part 'search_surface.dart';

/// Unified-search surface (Phase 11, slice 11.1, owner decisions D-S2/D-S3/D-S4).
///
/// A `/search?q=…` route that seeds the [SearchCubit] with the `q` query
/// param and lets the user refine with a debounced field. Results render as
/// capability-gated groups (D-S2 — nav hints only, never authorization) and
/// every row navigates to an **existing read-only route** (D-S3): matter →
/// `/matters/:id`, document → `/vault`, thread → `/messages`, attorney →
/// `/discovery/:id`. **Metadata only**: rows render the same non-PII fields
/// as the standalone surfaces — never a document body, message text,
/// thread-open affordance, preview, or send/reply (the Phase 8/9 AC-2
/// absence lines, D-S3). An empty query shows the no-query state, not
/// results (D-S4), and the surface carries the local-only demo note (D-S5).
class SearchScreen extends StatelessWidget {
  const SearchScreen({
    required this.capabilities,
    this.initialQuery = '',
    super.key,
  });

  /// UX-only capability projection (the D-W5 posture) injected by the router
  /// from the session role; a group renders only when its capability is
  /// granted.
  final RoleCapability capabilities;

  /// The `q` query param; a non-blank value seeds the first search on open.
  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    // Feature-scoped cubit composed from the four gateway seams (slice 11.0);
    // the surface below reads it via BlocBuilder.
    return BlocProvider<SearchCubit>(
      create: (BuildContext context) => SearchCubit(
        serviceLocator<MatterGateway>(),
        serviceLocator<DocumentGateway>(),
        serviceLocator<MessageGateway>(),
        serviceLocator<AttorneyGateway>(),
      ),
      child: _SearchSurface(
        capabilities: capabilities,
        initialQuery: initialQuery,
      ),
    );
  }
}
