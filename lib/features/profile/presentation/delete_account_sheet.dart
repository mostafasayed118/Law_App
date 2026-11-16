import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/profile/domain/account_gateway.dart';
import 'package:legalhub/features/profile/presentation/account_deletion_cubit.dart';
import 'package:legalhub/features/profile/presentation/account_deletion_state.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

/// The account-deletion danger sheet (ADR-0011).
///
/// The copy is the important part. The RPC hard-deletes the identity, removes
/// the caller's own uploads and cascades personal rows — but it deliberately
/// leaves other people's data and provider-side records alone. This sheet says
/// both halves out loud, then requires a typed confirmation, then a second
/// confirmation dialog. Nothing here claims a "full" deletion it cannot prove.
Future<bool> showDeleteAccountSheet(BuildContext context) async {
  final bool? confirmed = await showAppSheet<bool>(
    context: context,
    builder: (BuildContext _) => BlocProvider<AccountDeletionCubit>(
      create: (BuildContext context) =>
          AccountDeletionCubit(serviceLocator<AccountGateway>()),
      child: const _DeleteAccountSheet(),
    ),
  );
  return confirmed == true;
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  late final TextEditingController _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? ok = await showConfirmDialog(
      context: context,
      title: l10n.accountDeleteTitle,
      content: Text(l10n.accountDeleteIntro),
      confirmLabel: l10n.accountDeleteSubmit,
    );
    if (ok != true || !mounted) {
      return;
    }
    final bool done = await context.read<AccountDeletionCubit>().delete();
    if (done && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String _errorText(AppLocalizations l10n, AccountDeletionState state) {
    if (state.isLastPartner) {
      return l10n.accountDeleteLastPartner;
    }
    if (state.isPlatformOwner) {
      return l10n.accountDeleteOwner;
    }
    if (state.lastError != null) {
      return l10n.accountDeleteGenericError;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return BlocBuilder<AccountDeletionCubit, AccountDeletionState>(
      builder: (BuildContext context, AccountDeletionState state) {
        final String error = _errorText(l10n, state);
        final bool deleting = state.stage == AccountDeletionStage.deleting;
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l10n.accountDeleteTitle, style: text.headlineSmall),
              const SizedBox(height: LegalHubTheme.spaceSm),
              Text(l10n.accountDeleteIntro, style: text.bodyMedium),
              const SizedBox(height: LegalHubTheme.spaceLg),
              Text(l10n.accountDeleteRemovesTitle, style: text.titleSmall),
              const SizedBox(height: LegalHubTheme.spaceXs),
              _FactRow(text: l10n.accountDeleteRemovesIdentity),
              _FactRow(text: l10n.accountDeleteRemovesLibrary),
              _FactRow(text: l10n.accountDeleteRemovesFiles),
              const SizedBox(height: LegalHubTheme.spaceMd),
              Text(l10n.accountDeleteKeepsTitle, style: text.titleSmall),
              const SizedBox(height: LegalHubTheme.spaceXs),
              _FactRow(text: l10n.accountDeleteKeepsOthers),
              _FactRow(text: l10n.accountDeleteKeepsStorage),
              _FactRow(text: l10n.accountDeleteKeepsAudit),
              const SizedBox(height: LegalHubTheme.spaceLg),
              Semantics(
                label: l10n.accountDeleteConfirmLabel,
                child: TextField(
                  controller: _confirmation,
                  enabled: !deleting,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.accountDeleteConfirmLabel,
                    hintText: l10n.accountDeleteConfirmHint,
                    border: const OutlineInputBorder(),
                    errorText: error.isEmpty ? null : error,
                  ),
                  onChanged: (String value) => context
                      .read<AccountDeletionCubit>()
                      .confirmationChanged(value),
                ),
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  onPressed: deleting || _confirmation.text.trim() != 'DELETE'
                      ? null
                      : _submit,
                  child: deleting
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: LegalHubTheme.spaceXs),
                            Text(l10n.accountDeleteInProgress),
                          ],
                        )
                      : Text(l10n.accountDeleteSubmit),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: LegalHubTheme.space2xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.remove_circle_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: LegalHubTheme.spaceXs),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
