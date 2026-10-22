import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../domain/pending_approval.dart';
import 'approval_error_messages.dart';
import 'approval_labels.dart';
import 'approvals_cubit.dart';

/// The action that closed the detail sheet, or null when it was dismissed.
enum ApprovalDetailOutcome { approved, rejected, cancelled }

/// Opens the read-only detail sheet with the caller's permitted actions.
///
/// [cubit] is the list's own [ApprovalsCubit] — re-provided around the sheet
/// because a modal's context sits under the Navigator, not under the caller's
/// provider scope. [canDecide] is the UX-only partner projection from the
/// router; the decide RPC is the authority. [currentUserId] gates the cancel
/// affordance for the requester.
Future<ApprovalDetailOutcome?> showApprovalDetailSheet(
  BuildContext context, {
  required PendingApproval approval,
  required ApprovalsCubit cubit,
  required bool canDecide,
  required String? currentUserId,
}) {
  return showModalBottomSheet<ApprovalDetailOutcome>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => BlocProvider<ApprovalsCubit>.value(
      value: cubit,
      child: ApprovalDetailSheet(
        approval: approval,
        canDecide: canDecide,
        currentUserId: currentUserId,
      ),
    ),
  );
}

/// Detail sheet for one approval request (design §3 Task 6).
///
/// Shows title, kind, status, description, and the decision note/time.
/// Approve/reject render only for a partner who is not the requester; cancel
/// renders only for the requester. Every action goes through the cubit and a
/// refusal renders the typed, localized failure copy — never a success.
class ApprovalDetailSheet extends StatefulWidget {
  const ApprovalDetailSheet({
    required this.approval,
    required this.canDecide,
    this.currentUserId,
    super.key,
  });

  final PendingApproval approval;
  final bool canDecide;
  final String? currentUserId;

  @override
  State<ApprovalDetailSheet> createState() => _ApprovalDetailSheetState();
}

class _ApprovalDetailSheetState extends State<ApprovalDetailSheet> {
  final TextEditingController _note = TextEditingController();

  bool _submitting = false;
  AppError? _actionError;
  String? _noteError;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _isRequester =>
      widget.currentUserId != null &&
      widget.approval.requestedBy == widget.currentUserId;

  bool get _canDecide =>
      widget.canDecide && widget.approval.isDecidable && !_isRequester;

  bool get _canCancel => _isRequester && widget.approval.isDecidable;

  Future<void> _decide({required bool approve}) async {
    if (!approve) {
      final String note = _note.text.trim();
      if (note.length < 2) {
        setState(
          () => _noteError = AppLocalizations.of(
            context,
          ).approvalRejectNoteRequired,
        );
        return;
      }
    }
    setState(() {
      _submitting = true;
      _actionError = null;
      _noteError = null;
    });
    final AppError? error = await context.read<ApprovalsCubit>().decide(
      widget.approval.id,
      approve: approve,
      note: _note.text,
    );
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(
        approve
            ? ApprovalDetailOutcome.approved
            : ApprovalDetailOutcome.rejected,
      );
      return;
    }
    setState(() {
      _submitting = false;
      _actionError = error;
    });
  }

  Future<void> _cancel() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: l10n.approvalCancelConfirmTitle,
      content: Text(l10n.approvalCancelConfirmBody),
      confirmLabel: l10n.approvalCancelAction,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _submitting = true;
      _actionError = null;
    });
    final AppError? error = await context.read<ApprovalsCubit>().cancel(
      widget.approval.id,
    );
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(ApprovalDetailOutcome.cancelled);
      return;
    }
    setState(() {
      _submitting = false;
      _actionError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.approval.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              _statusLine(l10n),
              const SizedBox(height: LegalHubTheme.spaceSm),
              Text(
                '${l10n.approvalDetailKind}: '
                '${approvalKindLabel(l10n, widget.approval.kind)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              Text(
                '${l10n.approvalDetailCreated}: '
                '${formatMediumDate(l10n, widget.approval.createdAt.toLocal())}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (widget.approval.description != null) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceMd),
                Text(
                  l10n.approvalDetailDescription,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(widget.approval.description!),
              ],
              if (widget.approval.decidedAt != null ||
                  widget.approval.decisionNote != null) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceMd),
                _decisionSection(l10n),
              ],
              if (_canDecide) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceLg),
                TextField(
                  controller: _note,
                  enabled: !_submitting,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: l10n.approvalDecideNoteLabel,
                    errorText: _noteError,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: LegalHubTheme.spaceSm),
                FilledButton(
                  onPressed: _submitting ? null : () => _decide(approve: true),
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.approvalApprove),
                ),
                const SizedBox(height: LegalHubTheme.spaceSm),
                OutlinedButton(
                  onPressed: _submitting ? null : () => _decide(approve: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(l10n.approvalReject),
                ),
              ],
              if (_canCancel) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceLg),
                OutlinedButton(
                  onPressed: _submitting ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(l10n.approvalCancelAction),
                ),
              ],
              if (_actionError != null) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceMd),
                Text(
                  approvalErrorMessage(l10n, _actionError!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusLine(AppLocalizations l10n) {
    return Row(
      children: <Widget>[
        Icon(
          approvalStatusIcon(widget.approval.status),
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: LegalHubTheme.spaceXs),
        Text(
          approvalStatusLabel(l10n, widget.approval.status),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _decisionSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.approval.decidedAt != null)
          Text(
            '${l10n.approvalDetailDecided}: '
            '${formatMediumDateTime(l10n, widget.approval.decidedAt!.toLocal())}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (widget.approval.decisionNote != null) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceXs),
          Text(
            l10n.approvalDetailDecisionNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: LegalHubTheme.spaceXs),
          Text(widget.approval.decisionNote!),
        ],
      ],
    );
  }
}
