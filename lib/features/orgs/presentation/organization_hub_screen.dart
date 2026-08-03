import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/service_locator.dart';
import '../../../core/auth/session.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../auth/presentation/auth_cubit.dart';
import 'create_organization_screen.dart';
import 'member_roster_screen.dart';
import 'org_cubit.dart';

/// Hub for the organization surface (P3 slice 1.5).
///
/// Resolves the active-org context from [Session.activeMembership] (or an
/// organization created in this visit) and renders the roster when an org
/// exists, or the create-org form when it does not. Provides the shared
/// [OrgCubit] so create → roster shares one gateway-backed state machine.
class OrganizationHubScreen extends StatefulWidget {
  const OrganizationHubScreen({super.key});

  @override
  State<OrganizationHubScreen> createState() => _OrganizationHubScreenState();
}

class _OrganizationHubScreenState extends State<OrganizationHubScreen> {
  String? _createdOrganizationId;

  @override
  Widget build(BuildContext context) {
    final Session? session = context.watch<AuthCubit>().state.session;
    final String? organizationId =
        _createdOrganizationId ?? session?.activeMembership?.organizationId;
    return BlocProvider<OrgCubit>(
      create: (BuildContext context) =>
          OrgCubit(serviceLocator<OrganizationGateway>()),
      child: organizationId == null
          ? CreateOrganizationScreen(
              onCreated: (OrganizationSummary organization) {
                setState(() => _createdOrganizationId = organization.id);
              },
            )
          : MemberRosterScreen(organizationId: organizationId),
    );
  }
}
