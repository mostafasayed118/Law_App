import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/active_org_store.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../core/practice_area.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/forms/validators.dart';
import '../../../shared/widgets/practice_area_label.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../domain/matter_write_gateway.dart';
import 'matter_create_cubit.dart';
import 'matter_create_state.dart';
part 'matter_create_surface.dart';
part 'matter_create_form_view.dart';
part 'matter_create_assignee_dropdown.dart';
part 'matter_create_success_view.dart';
part 'matter_create_error_message.dart';

/// Create-matter form flow (F-01 step 2 client swap, C-D6).
///
/// A `/matters/new` route that sends the create intent through the
/// [MatterWriteGateway] seam (the dev fake in env-less runs, the Supabase
/// `create_matter` RPC in configured builds). The server is the authority —
/// this form sends ONLY the create intent; the org id is the ACTIVE org from
/// the [ActiveOrgStore] (a routing hint, D-08) and membership/owner/member
/// gates are re-derived in-function (F-11). Assignee dropdowns are
/// pre-filtered to the org's ACTIVE members via the roster seam (C-D2/Q2);
/// the platform owner holds no membership, so it is never offered (F2-D2),
/// and orphan creates (no assignees) are allowed (F2-D5).
///
/// The screen provides its OWN [MatterCreateCubit] (the [MatterListScreen]
/// pattern), so the route needs no external provider.
///
/// Honest UX (R1): on success the view shows the returned matter id and does
/// NOT promise list visibility — an assigned-to-partner create IS visible to
/// the partner (RLS read-back), an orphan create is not (the battery 13.16
/// pin). The create entry is a partner-only UX gate (the list FAB); the
/// server re-asserts F2-D1, so any caller reaching this screen gets the
/// typed denial, never empty success (AC-7).
class MatterCreateScreen extends StatelessWidget {
  const MatterCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MatterCreateCubit>(
      create: (BuildContext context) => MatterCreateCubit(
        serviceLocator<MatterWriteGateway>(),
        serviceLocator<OrganizationGateway>(),
      ),
      child: const _CreateSurface(),
    );
  }
}
