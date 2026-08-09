import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:intl/intl.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../l10n/app_localizations.dart';
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
          return switch (state.approvals) {
            ViewLoading() => const Padding(
              padding: EdgeInsetsDirectional.all(LegalHubTheme.spaceXl),
              child: Center(child: CircularProgressIndicator()),
            ),
            ViewEmpty() => ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                empty,
                const SizedBox(height: LegalHubTheme.spaceLg),
                Text(
                  l10n.approvalsLocalOnlyNote,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            ViewError() => ListView(
              padding: const EdgeInsetsDirectional.all(
                LegalHubTheme.marginMobile,
              ),
              children: <Widget>[
                Text(
                  l10n.approvalsError,
                  style: text.bodyMedium?.copyWith(color: scheme.error),
                ),
                TextButton(
                  onPressed: () => context.read<ApprovalsCubit>().load(),
                  child: Text(l10n.retry),
                ),
              ],
            ),
            ViewOffline() || ViewUnauthorized() => empty,
            ViewSuccess<List<PendingApproval>>(
              data: final List<PendingApproval> approvals,
            ) =>
              ListView(
                padding: const EdgeInsetsDirectional.all(
                  LegalHubTheme.marginMobile,
                ),
                children: <Widget>[
                  for (final PendingApproval approval in approvals) ...<Widget>[
                    _ApprovalTile(approval: approval),
                    const SizedBox(height: LegalHubTheme.spaceSm),
                  ],
                  const SizedBox(height: LegalHubTheme.spaceLg),
                  Text(
                    l10n.approvalsLocalOnlyNote,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          };
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
    final TextTheme text = Theme.of(context).textTheme;
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
    final String date = DateFormat.yMMMd(
      l10n.localeName,
    ).format(approval.createdAt);
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusLg),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
        child: Row(
          children: <Widget>[
            Icon(status.$1, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: LegalHubTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${approval.entityType} · ${approval.reference}',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${status.$2} · $date',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
