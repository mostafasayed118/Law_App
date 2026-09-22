import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/approvals_gateway.dart';
import '../domain/pending_approval.dart';
import 'approvals_cubit.dart';
import 'approvals_state.dart';

/// Pending-approvals list screen (v1 queue; spec §6
/// `pending_approvals_queue`, v1).
///
/// Read-only demo of the synthetic redacted queue — **no approve/deny
/// action** (the real human-review workflows are deferred, D-06; this surface
/// never implies an approval authority). Rows show entity type, reference,
/// and status as text+icon — never color alone (§4.5).
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.approvalsTitle)),
      // The shared cubit-scoped list shell (audit 2026-09-21, M-10): the
      // provider, the post-frame first load, the SafeArea + BlocBuilder and
      // the ViewStateList wiring used to be repeated in this file verbatim.
      body: CubitListSurface<ApprovalsCubit, ApprovalsState, PendingApproval>(
        createCubit: () => ApprovalsCubit(serviceLocator<ApprovalsGateway>()),
        project: (ApprovalsState state) => state.approvals,
        load: (ApprovalsCubit cubit) => cubit.load(),
        tileBuilder: (BuildContext context, PendingApproval approval) =>
            _ApprovalTile(approval: approval),
        empty: (BuildContext context, ApprovalsState state) => Padding(
          padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
          child: Text(
            l10n.approvalsEmpty,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        errorCopy: l10n.approvalsError,
        localOnlyNote: l10n.approvalsLocalOnlyNote,
      ),
    );
  }
}

/// A read-only approval row: entity type + reference + status as text+icon
/// (never color alone); **no approve/deny affordance**.
class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({required this.approval});

  final PendingApproval approval;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData, String) status = switch (approval.status) {
      ApprovalStatus.pending => (
        Icons.hourglass_top,
        l10n.approvalStatusPending,
      ),
      ApprovalStatus.approved => (
        Icons.check_circle_outline,
        l10n.approvalStatusApproved,
      ),
      ApprovalStatus.denied => (
        Icons.cancel_outlined,
        l10n.approvalStatusDenied,
      ),
    };
    final String date = formatMediumDate(l10n, approval.createdAt);
    return AppTile(
      leading: Icon(status.$1, size: 20, color: scheme.onSurfaceVariant),
      title: '${approval.entityType} · ${approval.reference}',
      subtitles: <String>['${status.$2} · $date'],
    );
  }
}
