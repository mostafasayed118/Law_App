import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/admin/platform_admin_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../orgs/presentation/org_error_messages.dart';
import 'platform_admin_cubit.dart';

part 'platform_admin_audit_section.dart';
part 'platform_admin_lists.dart';
part 'platform_admin_member_row.dart';
part 'platform_admin_states.dart';

/// Platform-owner admin surface (P3.5, permission matrix §5).
///
/// Two metadata-only sections — organizations and members — loaded in
/// parallel. The owner-only RPCs gate server-side: a non-owner sees the
/// distinct denied state (`permission denied`), never an empty-success list
/// (AC-7). Actions (platform suspend/reactivate, delete demo account) go
/// through the [PlatformAdminCubit]; every outcome renders as returned, and
/// failures surface as localized, non-sensitive messages.
///
/// The section widgets live in the `part` files below (Phase-4 readability
/// split): the lists shell + member rows, the audit section (with its
/// fetch-on-mount lifecycle), and the denied/failed terminal states. All
/// are feature-local private widgets; nothing is exported beyond this
/// screen.
class PlatformAdminScreen extends StatefulWidget {
  const PlatformAdminScreen({this.gateway, super.key});

  /// Test seam: production leaves this null and the screen resolves the
  /// locator's registered [PlatformAdminGateway]; tests inject a gateway to
  /// pin owner/non-owner/action behavior without the DI graph.
  final PlatformAdminGateway? gateway;

  @override
  State<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends State<PlatformAdminScreen> {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // The feature-scoped cubit is provided here (the roster pattern: the org
    // hub provides OrgCubit above the roster; this screen is its own hub).
    // [gateway] is the test seam; production resolves the locator's seam.
    return BlocProvider<PlatformAdminCubit>(
      create: (_) => PlatformAdminCubit(
        widget.gateway ?? serviceLocator<PlatformAdminGateway>(),
      ),
      child: _LoadOnMount(
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.platformAdminTitle)),
          body: BlocBuilder<PlatformAdminCubit, PlatformAdminState>(
            builder: (BuildContext context, PlatformAdminState state) {
              switch (state) {
                case PlatformAdminLoaded(
                  organizations: final List<OrganizationSummary> organizations,
                  members: final List<OrgMember> members,
                  pendingUserId: final String? pendingUserId,
                  platformAudit: final List<AuditEntry> platformAudit,
                  orgAudit: final List<AuditEntry> orgAudit,
                  selectedAuditOrgId: final String? selectedAuditOrgId,
                  auditLoading: final bool auditLoading,
                  auditError: final OrgFailureKind? auditError,
                ):
                  return _AdminLists(
                    organizations: organizations,
                    members: members,
                    pendingUserId: pendingUserId,
                    platformAudit: platformAudit,
                    orgAudit: orgAudit,
                    selectedAuditOrgId: selectedAuditOrgId,
                    auditLoading: auditLoading,
                    auditError: auditError,
                  );
                case PlatformAdminDenied():
                  return _DeniedState();
                case PlatformAdminFailed(
                  error: _,
                  kind: final OrgFailureKind kind,
                ):
                  return _FailedState(kind: kind);
                case PlatformAdminInitial() || PlatformAdminLoading():
                  return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Loads the admin lists once after the first frame.
///
/// Lives BELOW the screen's BlocProvider so its context resolves the cubit
/// (the member roster's arrival pattern: load whenever the lists are not
/// already visible or in flight).
class _LoadOnMount extends StatefulWidget {
  const _LoadOnMount({required this.child});

  final Widget child;

  @override
  State<_LoadOnMount> createState() => _LoadOnMountState();
}

class _LoadOnMountState extends State<_LoadOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final PlatformAdminState state = context.read<PlatformAdminCubit>().state;
      if (state is! PlatformAdminLoaded && state is! PlatformAdminLoading) {
        context.read<PlatformAdminCubit>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
