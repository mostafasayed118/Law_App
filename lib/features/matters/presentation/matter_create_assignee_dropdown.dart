part of 'matter_create_screen.dart';

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
