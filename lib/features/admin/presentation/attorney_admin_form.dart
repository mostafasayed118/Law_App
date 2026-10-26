import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/core/contracts/server_limits.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_admin_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'attorney_admin_cubit.dart';
import 'attorney_admin_state.dart';

/// Create/edit form for one directory profile (design §2).
///
/// Validation mirrors the server bounds: display name length, years 0–80, at
/// least one specialty. Headline, city, bio, and languages are optional. The
/// form is pushed with the screen's cubit in scope, so a successful write
/// reloads the list behind it.
class AttorneyAdminForm extends StatefulWidget {
  const AttorneyAdminForm({this.initial, super.key});

  /// The profile being edited, or null for a create.
  final Attorney? initial;

  @override
  State<AttorneyAdminForm> createState() => _AttorneyAdminFormState();
}

class _AttorneyAdminFormState extends State<AttorneyAdminForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _headline;
  late final TextEditingController _bio;
  late final TextEditingController _city;
  late final TextEditingController _years;
  late final TextEditingController _languages;
  late final Set<String> _specialties;

  bool _specialtyMissing = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    final Attorney? initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _headline = TextEditingController(text: initial?.headline ?? '');
    _bio = TextEditingController(text: initial?.bio ?? '');
    _city = TextEditingController(text: initial?.city ?? '');
    _years = TextEditingController(
      text: initial?.yearsExperience?.toString() ?? '',
    );
    _languages = TextEditingController(
      text: initial?.languages.join(', ') ?? '',
    );
    _specialties = <String>{
      for (final String value in initial?.specialties ?? const <String>[])
        value.trim().toLowerCase(),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _headline.dispose();
    _bio.dispose();
    _city.dispose();
    _years.dispose();
    _languages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool editing = widget.initial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? l10n.attorneyAdminEditTitle : l10n.attorneyAdminCreate,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsetsDirectional.all(
              LegalHubTheme.marginMobile,
            ),
            children: <Widget>[
              LegalHubTextField(
                controller: _name,
                label: l10n.attorneyAdminNameLabel,
                hint: l10n.attorneyAdminNameLabel,
                textInputAction: TextInputAction.next,
                maxLength: kAttorneyNameMaxLength,
                validator: (String? value) {
                  final String trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return l10n.attorneyAdminNameRequired;
                  }
                  if (trimmed.length < 2) {
                    return l10n.attorneyAdminNameTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              LegalHubTextField(
                controller: _headline,
                label: l10n.attorneyAdminHeadlineLabel,
                hint: l10n.attorneyAdminHeadlineLabel,
                textInputAction: TextInputAction.next,
                maxLength: kTitleMaxLength,
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              LegalHubTextField(
                controller: _city,
                label: l10n.attorneyAdminCityLabel,
                hint: l10n.attorneyAdminCityLabel,
                textInputAction: TextInputAction.next,
                maxLength: kAttorneyNameMaxLength,
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              LegalHubTextField(
                controller: _years,
                label: l10n.attorneyAdminYearsLabel,
                hint: l10n.attorneyAdminYearsLabel,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _validateYears,
              ),
              const SizedBox(height: LegalHubTheme.spaceLg),
              Text(
                l10n.attorneyAdminSpecialtiesLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: LegalHubTheme.spaceSm),
              Wrap(
                spacing: LegalHubTheme.spaceSm,
                runSpacing: LegalHubTheme.spaceSm,
                children: <Widget>[
                  for (final PracticeArea area in PracticeArea.values)
                    FilterChip(
                      label: Text(practiceAreaLabel(l10n, area)),
                      selected: _specialties.contains(area.name),
                      onSelected: (bool selected) =>
                          _toggleSpecialty(area.name, selected: selected),
                    ),
                ],
              ),
              if (_specialtyMissing) ...<Widget>[
                const SizedBox(height: LegalHubTheme.spaceXs),
                Text(
                  l10n.attorneyAdminSpecialtyRequired,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: LegalHubTheme.spaceLg),
              LegalHubTextField(
                controller: _languages,
                label: l10n.attorneyAdminLanguagesLabel,
                hint: l10n.attorneyAdminLanguagesHint,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: LegalHubTheme.spaceMd),
              LabelledField(
                label: l10n.attorneyAdminBioLabel,
                child: TextFormField(
                  controller: _bio,
                  maxLines: 4,
                  maxLength: kAttorneyBioMaxLength,
                  decoration: InputDecoration(
                    hintText: l10n.attorneyAdminBioLabel,
                  ),
                ),
              ),
              const SizedBox(height: LegalHubTheme.spaceLg),
              if (_saveFailed) ...<Widget>[
                Text(
                  l10n.attorneyAdminSaveFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: LegalHubTheme.spaceSm),
              ],
              BlocBuilder<AttorneyAdminCubit, AttorneyAdminState>(
                builder: (BuildContext context, AttorneyAdminState state) {
                  return FilledButton(
                    onPressed: state.pending ? null : _submit,
                    child: Text(l10n.attorneyAdminSave),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateYears(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final int? years = int.tryParse(trimmed);
    if (years == null || years < 0 || years > 80) {
      return AppLocalizations.of(context).attorneyAdminYearsInvalid;
    }
    return null;
  }

  void _toggleSpecialty(String value, {required bool selected}) {
    setState(() {
      if (selected) {
        _specialties.add(value);
      } else {
        _specialties.remove(value);
      }
      if (_specialties.isNotEmpty) {
        _specialtyMissing = false;
      }
    });
  }

  Future<void> _submit() async {
    final bool formValid = _formKey.currentState?.validate() ?? false;
    final bool hasSpecialty = _specialties.isNotEmpty;
    if (!formValid || !hasSpecialty) {
      setState(() => _specialtyMissing = !hasSpecialty);
      return;
    }
    setState(() => _saveFailed = false);
    final String yearsText = _years.text.trim();
    final AttorneyDraft draft = AttorneyDraft(
      displayName: _name.text.trim(),
      headline: _nonEmpty(_headline.text),
      bio: _nonEmpty(_bio.text),
      city: _nonEmpty(_city.text),
      specialties: _specialties.toList(growable: false),
      languages: _languages.text
          .split(',')
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList(growable: false),
      yearsExperience: yearsText.isEmpty ? null : int.parse(yearsText),
    );
    final AttorneyAdminCubit cubit = context.read<AttorneyAdminCubit>();
    final Attorney? initial = widget.initial;
    final bool saved = initial == null
        ? await cubit.create(draft)
        : await cubit.update(initial.id, draft);
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saveFailed = true);
  }

  String? _nonEmpty(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
