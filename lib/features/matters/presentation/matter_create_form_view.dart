part of 'matter_create_screen.dart';

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
