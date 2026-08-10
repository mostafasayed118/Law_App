import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).approvalsTitle)),
      body: BlocProvider<ApprovalsCubit>(
        create: (BuildContext context) =>
            ApprovalsCubit(serviceLocator<ApprovalsGateway>()),
        child: const _ApprovalsSurface(),
      ),
    );
  }
}

class _ApprovalsSurface extends StatefulWidget {
  const _ApprovalsSurface();

  @override
  State<_ApprovalsSurface> createState() => _ApprovalsSurfaceState();
}

class _ApprovalsSurfaceState extends State<_ApprovalsSurface> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ApprovalsCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return SafeArea(
      child: BlocBuilder<ApprovalsCubit, ApprovalsState>(
        builder: (BuildContext context, ApprovalsState state) {
          final Widget empty = Padding(
            padding: const EdgeInsetsDirectional.only(
              top: LegalHubTheme.spaceMd,
            ),
            child: Text(
              l10n.approvalsEmpty,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          );
          return ViewStateList<List<PendingApproval>>(
            state: state.approvals,
            onRetry: () => context.read<ApprovalsCubit>().load(),
            itemBuilder:
                (
                  BuildContext context,
                  List<PendingApproval> approvals,
                ) => <Widget>[
                  for (final PendingApproval approval in approvals) ...<Widget>[
                    _ApprovalTile(approval: approval),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                ],
            empty: empty,
            errorCopy: l10n.approvalsError,
            localOnlyNote: l10n.approvalsLocalOnlyNote,
          );
        },
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
