import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_admin_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'attorney_admin_cubit.dart';
import 'attorney_admin_form.dart';
import 'attorney_admin_state.dart';

part 'attorney_admin_tile.dart';

/// Platform-admin attorney directory (design §2).
///
/// Lists every profile (active and inactive) with status chips; the create
/// button opens the form and a row opens it for editing. Deactivation is
/// behind a confirmation dialog. The owner-only RPC gates server-side: a
/// non-owner sees the unauthorized arm, never an empty-success list.
class AttorneyAdminScreen extends StatelessWidget {
  const AttorneyAdminScreen({this.gateway, super.key});

  /// Test seam: production leaves this null and resolves the locator's
  /// registered [AttorneyAdminGateway]; tests inject a gateway to pin
  /// owner/non-owner and action behavior without the DI graph.
  final AttorneyAdminGateway? gateway;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.attorneyAdminTitle)),
      body: CubitListSurface<AttorneyAdminCubit, AttorneyAdminState, Attorney>(
        createCubit: () => AttorneyAdminCubit(
          gateway ?? serviceLocator<AttorneyAdminGateway>(),
        ),
        project: (AttorneyAdminState state) => state.attorneys,
        load: (AttorneyAdminCubit cubit) => cubit.load(),
        tileBuilder: (BuildContext context, Attorney attorney) =>
            _AttorneyAdminTile(attorney: attorney),
        header: const <Widget>[
          _AdminNote(),
          SizedBox(height: LegalHubTheme.spaceMd),
          _AddButton(),
          SizedBox(height: LegalHubTheme.spaceMd),
        ],
        empty: (BuildContext context, AttorneyAdminState state) => Padding(
          padding: const EdgeInsetsDirectional.only(top: LegalHubTheme.spaceMd),
          child: Text(
            l10n.attorneyAdminEmpty,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        errorCopy: l10n.attorneyAdminError,
        localOnlyNote: '',
      ),
    );
  }
}

/// The honest directory note (design §1 principle 4): the platform maintains
/// the listing; no credential verification is claimed.
class _AdminNote extends StatelessWidget {
  const _AdminNote();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: LegalHubTheme.spaceSm),
        Expanded(
          child: Text(
            AppLocalizations.of(context).attorneyAdminNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FilledButton.icon(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context).attorneyAdminCreate),
      ),
    );
  }
}

/// Pushes the form with the screen's cubit in scope; a successful write
/// reloads the list behind it. [BlocProvider.value] keeps ownership with the
/// screen (the route must not close the list's cubit on pop).
void _openForm(BuildContext context, {Attorney? initial}) {
  final AttorneyAdminCubit cubit = context.read<AttorneyAdminCubit>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext routeContext) =>
          BlocProvider<AttorneyAdminCubit>.value(
            value: cubit,
            child: AttorneyAdminForm(initial: initial),
          ),
    ),
  );
}
