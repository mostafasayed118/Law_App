import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/legalhub_theme.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/forms/validators.dart';
import '../../../shared/widgets/widgets.dart';
import 'org_cubit.dart';
import 'org_error_messages.dart';

/// Create-organization form (P3 slice 1.1).
///
/// Name-only input: the server makes the caller its initial partner (D-08).
/// Empty/whitespace names are rejected client-side and again at the seam;
/// on success [onCreated] hands the created organization to the host so it
/// can switch to the roster. The form lives under the hub's [OrgCubit], so
/// it never talks to the gateway directly.
class CreateOrganizationScreen extends StatefulWidget {
  const CreateOrganizationScreen({required this.onCreated, super.key});

  final ValueChanged<OrganizationSummary> onCreated;

  @override
  State<CreateOrganizationScreen> createState() =>
      _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState extends State<CreateOrganizationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return BlocListener<OrgCubit, OrgState>(
      listener: (BuildContext context, OrgState state) {
        switch (state) {
          case OrgCreateSuccess(organization: final OrganizationSummary org):
            widget.onCreated(org);
          case OrgCreateFailed(kind: final OrgFailureKind kind):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  orgErrorMessage(AppLocalizations.of(context), kind),
                ),
              ),
            );
          case OrgCreateLoading() ||
              OrgInitial() ||
              OrgRosterLoading() ||
              OrgRosterLoaded() ||
              OrgRosterFailed():
            break;
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.createOrgTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(
              LegalHubTheme.marginMobile,
            ),
            children: <Widget>[
              const SizedBox(height: LegalHubTheme.spaceMd),
              Center(
                child: const IconHeroBadge(
                  icon: Icons.domain_add_outlined,
                  iconSize: 48,
                ),
              ),
              const SizedBox(height: LegalHubTheme.spaceLg),
              Text(
                l10n.createOrgTitle,
                textAlign: TextAlign.center,
                style: text.displaySmall,
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              Text(
                l10n.createOrgSubtitle,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: LegalHubTheme.spaceXl),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    LegalHubTextField(
                      controller: _name,
                      label: l10n.orgNameLabel,
                      hint: l10n.orgNamePlaceholder,
                      prefixIcon: Icons.business_outlined,
                      validator: (String? value) =>
                          LegalHubValidators.required(l10n, value),
                    ),
                    const SizedBox(height: LegalHubTheme.spaceLg),
                    BlocBuilder<OrgCubit, OrgState>(
                      buildWhen: (OrgState previous, OrgState current) =>
                          (previous is OrgCreateLoading) !=
                          (current is OrgCreateLoading),
                      builder: (BuildContext context, OrgState state) {
                        final bool creating = state is OrgCreateLoading;
                        return ElevatedButton.icon(
                          onPressed: creating ? null : _submit,
                          icon: creating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_business_outlined),
                          label: Text(l10n.createOrgButton),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await context.read<OrgCubit>().createOrganization(name: _name.text.trim());
  }
}
