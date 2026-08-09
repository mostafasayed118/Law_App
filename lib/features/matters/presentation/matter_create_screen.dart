import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/organizations/organization_gateway.dart';
import '../../../core/practice_area.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/forms/validators.dart';
import '../../../shared/widgets/practice_area_label.dart';
import '../../../shared/widgets/widgets.dart';
import '../../orgs/presentation/active_org_store.dart';
import '../domain/matter_write_gateway.dart';
import 'matter_create_cubit.dart';
import 'matter_create_state.dart';

/// Create-matter form flow (F-01 step 2 client swap, C-D6).
///
/// A `/matters/new` route that sends the create intent through the
/// [MatterWriteGateway] seam (the dev fake in env-less runs, the Supabase
/// `create_matter` RPC in configured builds). The server is the authority —
/// this form sends ONLY the create intent; the org id is the ACTIVE org from
/// the [ActiveOrgStore] (a routing hint, D-08) and membership/owner/member
/// gates are re-derived in-function (F-11). Assignee dropdowns are
/// pre-filtered to the org's ACTIVE members via the roster seam (C-D2/Q2);
/// the platform owner holds no membership, so it is never offered (F2-D2),
/// and orphan creates (no assignees) are allowed (F2-D5).
///
/// Honest UX (R1): on success the view shows the returned matter id and does
/// NOT promise list visibility — an assigned-to-partner create IS visible to
/// the partner (RLS read-back), an orphan create is not (the battery 13.16
/// pin). The create entry is a partner-only UX gate (the list FAB); the
/// server re-asserts F2-D1, so any caller reaching this screen gets the
/// typed denial, never empty success (AC-7).
class MatterCreateScreen extends StatefulWidget {
  const MatterCreateScreen({super.key});

  @override
  State<MatterCreateScreen> createState() => _MatterCreateScreenState();
}

class _MatterCreateScreenState extends State<MatterCreateScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  PracticeArea _practiceArea = PracticeArea.corporate;
  String? _assignedClientId;
  String? _assignedAttorneyId;

  /// The active org's active members (the assignee options), loaded once on
  /// open via the roster seam; null while loading.
  List<OrgMember>? _members;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final String? organizationId =
        serviceLocator<ActiveOrgStore>().activeOrganizationId;
    if (organizationId == null || !mounted) {
      return;
    }
    final OrgOutcome<List<OrgMember>> outcome =
        await serviceLocator<OrganizationGateway>().listMembers(
          organizationId: organizationId,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      // F2-D4: only ACTIVE members are offerable as assignees; suspended and
      // removed rows are excluded client-side (the server re-asserts).
      _members = switch (outcome) {
        OrgSuccess<List<OrgMember>>(value: final List<OrgMember> members) =>
          members
              .where((OrgMember member) => member.isActive)
              .toList(growable: false),
        OrgFailed<List<OrgMember>>() => const <OrgMember>[],
      };
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final String? organizationId =
        serviceLocator<ActiveOrgStore>().activeOrganizationId;
    if (organizationId == null) {
      return;
    }
    await context.read<MatterCreateCubit>().submit(
      CreateMatterRequest(
        organizationId: organizationId,
        title: _title.text,
        practiceArea: _practiceArea,
        assignedClientId: _assignedClientId,
        assignedAttorneyId: _assignedAttorneyId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matterCreateTitle)),
      body: SafeArea(
        child: BlocBuilder<MatterCreateCubit, MatterCreateState>(
          builder: (BuildContext context, MatterCreateState state) {
            return switch (state) {
              MatterCreateSuccess(createdMatter: final created) => _SuccessView(
                matterId: created.id,
                onDone: () => context.pop(),
              ),
              MatterCreateSubmitting() ||
              MatterCreateInitial() ||
              MatterCreateFailure() => _FormView(
                formKey: _formKey,
                titleController: _title,
                practiceArea: _practiceArea,
                assignedClientId: _assignedClientId,
                assignedAttorneyId: _assignedAttorneyId,
                members: _members,
                submitting: state is MatterCreateSubmitting,
                error: state is MatterCreateFailure ? state.error : null,
                onPracticeAreaChanged: (PracticeArea area) =>
                    setState(() => _practiceArea = area),
                onClientChanged: (String? id) =>
                    setState(() => _assignedClientId = id),
                onAttorneyChanged: (String? id) =>
                    setState(() => _assignedAttorneyId = id),
                onSubmit: _submit,
                scheme: scheme,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.titleController,
    required this.practiceArea,
    required this.assignedClientId,
    required this.assignedAttorneyId,
    required this.members,
    required this.submitting,
    required this.error,
    required this.onPracticeAreaChanged,
    required this.onClientChanged,
    required this.onAttorneyChanged,
    required this.onSubmit,
    required this.scheme,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final PracticeArea practiceArea;
  final String? assignedClientId;
  final String? assignedAttorneyId;
  final List<OrgMember>? members;
  final bool submitting;
  final AppError? error;
  final ValueChanged<PracticeArea> onPracticeAreaChanged;
  final ValueChanged<String?> onClientChanged;
  final ValueChanged<String?> onAttorneyChanged;
  final VoidCallback onSubmit;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        if (error != null) ...<Widget>[
          Text(
            _errorMessage(l10n, error!),
            style: TextStyle(color: scheme.error),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
        ],
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: titleController,
                enabled: !submitting,
                decoration: InputDecoration(
                  labelText: l10n.matterCreateTitleLabel,
                  hintText: l10n.matterCreateTitleHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (String? value) =>
                    LegalHubValidators.required(l10n, value),
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              DropdownButtonFormField<PracticeArea>(
                initialValue: practiceArea,
                decoration: InputDecoration(
                  labelText: l10n.matterCreatePracticeAreaLabel,
                  border: const OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<PracticeArea>>[
                  for (final PracticeArea area in PracticeArea.values)
                    DropdownMenuItem<PracticeArea>(
                      value: area,
                      child: Text(practiceAreaLabel(l10n, area)),
                    ),
                ],
                onChanged: submitting
                    ? null
                    : (PracticeArea? value) {
                        if (value != null) {
                          onPracticeAreaChanged(value);
                        }
                      },
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              _AssigneeDropdown(
                label: l10n.matterCreateAssignedClientLabel,
                value: assignedClientId,
                members: members,
                enabled: !submitting,
                onChanged: onClientChanged,
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              _AssigneeDropdown(
                label: l10n.matterCreateAssignedAttorneyLabel,
                value: assignedAttorneyId,
                members: members,
                enabled: !submitting,
                onChanged: onAttorneyChanged,
              ),
              const SizedBox(height: LegalHubTheme.spaceLg),
              FilledButton(
                onPressed: submitting ? null : onSubmit,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.matterCreateSubmit),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One optional assignee dropdown: "None" + the org's active members.
///
/// The platform owner holds no membership, so it is never offerable (F2-D2);
/// orphan creates are allowed (F2-D5). Members are loaded once via the
/// roster seam; while loading (or when the roster failed) the dropdown is
/// disabled rather than guessing an offerable set.
class _AssigneeDropdown extends StatelessWidget {
  const _AssigneeDropdown({
    required this.label,
    required this.value,
    required this.members,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<OrgMember>? members;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<OrgMember>? roster = members;
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      // While the roster loads (or failed) no assignee is offerable — the
      // dropdown stays disabled rather than guessing.
      items: roster == null
          ? null
          : <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.matterCreateAssigneeNone),
              ),
              for (final OrgMember member in roster)
                DropdownMenuItem<String?>(
                  value: member.userId,
                  child: Text(member.displayName),
                ),
            ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.matterId, required this.onDone});

  final String matterId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 48, color: scheme.primary),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(l10n.matterCreateSuccessTitle, style: text.titleLarge),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(l10n.matterCreateSuccessBody(matterId), style: text.bodyMedium),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(
            l10n.matterCreateSuccessNote,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: LegalHubTheme.spaceLg),
          FilledButton(onPressed: onDone, child: Text(l10n.matterCreateDone)),
        ],
      ),
    );
  }
}

/// Maps the typed C-D2 error code to the localized copy; unknown codes fall
/// back to the seam's redaction-safe English message (never empty success —
/// AC-7).
String _errorMessage(AppLocalizations l10n, AppError error) {
  return switch (error.code) {
    'matter_write_denied' => l10n.matterCreateErrorDenied,
    'matter_write_owner_forbidden' => l10n.matterCreateErrorOwnerForbidden,
    'matter_write_assignee_invalid' => l10n.matterCreateErrorAssigneeInvalid,
    'matter_write_validation' => l10n.matterCreateErrorValidation,
    'matter_write_unavailable' => l10n.matterCreateErrorUnavailable,
    'matter_write_failed' => l10n.matterCreateErrorFailed,
    _ => error.userMessage,
  };
}
