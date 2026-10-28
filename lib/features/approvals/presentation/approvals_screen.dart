import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/approvals/domain/approvals_gateway.dart';
import 'package:legalhub/features/approvals/domain/pending_approval.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'approval_create_sheet.dart';
import 'approval_detail_sheet.dart';
import 'approval_labels.dart';
import 'approvals_cubit.dart';
import 'approvals_state.dart';

part 'approvals_tile.dart';

/// Org-scoped approvals list (design §3).
///
/// Status filter chips, a create FAB, and a detail sheet with the permitted
/// actions. [canDecide] and [currentUserId] are UX-only projections passed by
/// the router (the active membership's partner role and the caller's id); the
/// decide/cancel RPCs re-assert every gate server-side, so a refusal renders
/// the typed failure, never a success.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({
    super.key,
    this.canDecide = false,
    this.currentUserId,
  });

  final bool canDecide;
  final String? currentUserId;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  // The list surface's BlocProvider owns this cubit's lifecycle (it closes it
  // on unmount); the Scaffold-level FAB shares the same instance.
  late final ApprovalsCubit _cubit = ApprovalsCubit(
    serviceLocator<ApprovalsGateway>(),
    serviceLocator<MatterGateway>(),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.approvalsScreenTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: Text(l10n.approvalsCreateFab),
      ),
      body: CubitListSurface<ApprovalsCubit, ApprovalsState, PendingApproval>(
        createCubit: () => _cubit,
        project: (ApprovalsState state) => state.approvals,
        load: (ApprovalsCubit cubit) => cubit.load(),
        tileBuilder: (BuildContext context, PendingApproval approval) =>
            _ApprovalTile(
              approval: approval,
              onTap: () => _openDetail(approval),
            ),
        header: <Widget>[
          BlocBuilder<ApprovalsCubit, ApprovalsState>(
            buildWhen: (ApprovalsState previous, ApprovalsState next) =>
                previous.status != next.status,
            builder: (BuildContext context, ApprovalsState state) {
              return AppFilterChips<ApprovalStatus>(
                values: ApprovalStatus.values,
                selected: state.status,
                allLabel: l10n.approvalsFilterAll,
                labelOf: (ApprovalStatus status) =>
                    approvalStatusLabel(l10n, status),
                onSelected: _cubit.setStatus,
              );
            },
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
        ],
        empty: (BuildContext context, ApprovalsState state) => Padding(
          padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
          child: Text(
            l10n.approvalsEmptyFiltered,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        errorCopy: l10n.approvalsError,
        localOnlyNote: backendIsLocalOnly
            ? l10n.approvalsLocalOnlyNote
            : l10n.approvalsStoredNote,
      ),
    );
  }

  Future<void> _openCreate() async {
    final bool? created = await showApprovalCreateSheet(context, cubit: _cubit);
    if (!mounted || created != true) {
      return;
    }
    _showSnack(AppLocalizations.of(context).approvalCreateSuccess);
  }

  Future<void> _openDetail(PendingApproval approval) async {
    final ApprovalDetailOutcome? outcome = await showApprovalDetailSheet(
      context,
      approval: approval,
      cubit: _cubit,
      canDecide: widget.canDecide,
      currentUserId: widget.currentUserId,
    );
    if (!mounted || outcome == null) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    _showSnack(switch (outcome) {
      ApprovalDetailOutcome.approved => l10n.approvalDecidedApproved,
      ApprovalDetailOutcome.rejected => l10n.approvalDecidedRejected,
      ApprovalDetailOutcome.cancelled => l10n.approvalCancelled,
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
