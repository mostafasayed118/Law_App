import 'package:flutter/material.dart';

import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/features/library/domain/highlight_color_slot.dart';
import 'package:legalhub/features/library/presentation/highlight_palette.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/app_modal_sheet.dart';
import 'package:legalhub/shared/widgets/confirm_dialog.dart';
import 'package:legalhub/shared/widgets/form_fields/legalhub_text_field.dart';

/// What the highlight editor resolved to.
sealed class HighlightEditorResult {
  const HighlightEditorResult();
}

/// The reader picked a colour (and optionally a note).
class HighlightSaved extends HighlightEditorResult {
  const HighlightSaved({required this.color, this.note});

  final HighlightColorSlot color;
  final String? note;
}

/// The reader asked to delete an existing highlight.
class HighlightDeleted extends HighlightEditorResult {
  const HighlightDeleted();
}

/// The colour-and-note editor, shared by "new highlight" and "edit highlight".
///
/// Opens through [showAppSheet], so a phone gets a bottom sheet and a wide window
/// a centred dialog without this file knowing the difference. Returns null when
/// dismissed, which the caller treats as "change nothing" — the same contract as
/// the other create sheets in the app.
Future<HighlightEditorResult?> showHighlightEditor({
  required BuildContext context,
  required String title,
  HighlightColorSlot initialColor = HighlightColorSlot.yellow,
  String? initialNote,
  bool allowDelete = false,
}) {
  return showAppSheet<HighlightEditorResult>(
    context: context,
    builder: (BuildContext _) => _HighlightEditor(
      title: title,
      initialColor: initialColor,
      initialNote: initialNote,
      allowDelete: allowDelete,
    ),
  );
}

class _HighlightEditor extends StatefulWidget {
  const _HighlightEditor({
    required this.title,
    required this.initialColor,
    required this.initialNote,
    required this.allowDelete,
  });

  final String title;
  final HighlightColorSlot initialColor;
  final String? initialNote;
  final bool allowDelete;

  @override
  State<_HighlightEditor> createState() => _HighlightEditorState();
}

class _HighlightEditorState extends State<_HighlightEditor> {
  late HighlightColorSlot _color = widget.initialColor;
  late final TextEditingController _note = TextEditingController(
    text: widget.initialNote ?? '',
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showConfirmDialog(
      context: context,
      title: l10n.libraryHighlightDeleteConfirm,
      content: const SizedBox.shrink(),
      confirmLabel: l10n.libraryHighlightDeleteAction,
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const HighlightDeleted());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String trimmed = _note.text.trim();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceMd,
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Text(
            l10n.libraryHighlightColourLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: LegalHubTheme.spaceXs),
          Wrap(
            spacing: LegalHubTheme.spaceSm,
            runSpacing: LegalHubTheme.spaceXs,
            children: <Widget>[
              for (final HighlightColorSlot slot in HighlightColorSlot.values)
                _ColourOption(
                  slot: slot,
                  selected: slot == _color,
                  onTap: () => setState(() => _color = slot),
                ),
            ],
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          LegalHubTextField(
            controller: _note,
            hint: l10n.libraryHighlightNoteLabel,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: LegalHubTheme.spaceMd),
          Row(
            children: <Widget>[
              if (widget.allowDelete)
                Expanded(
                  child: TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.libraryHighlightDeleteAction),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: LegalHubTheme.spaceSm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    HighlightSaved(
                      color: _color,
                      note: trimmed.isEmpty ? null : trimmed,
                    ),
                  ),
                  child: Text(l10n.libraryHighlightSaveAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One colour choice: a swatch plus its localized name.
///
/// The name is not decoration — a colour-only picker is unusable with a screen
/// reader and ambiguous for a colour-blind reader.
class _ColourOption extends StatelessWidget {
  const _ColourOption({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final HighlightColorSlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = HighlightPalette.label(l10n, slot);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusMd),
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: LegalHubTheme.spaceSm,
            vertical: LegalHubTheme.spaceXs,
          ),
          decoration: BoxDecoration(
            color: HighlightPalette.background(context, slot),
            borderRadius: const BorderRadius.all(
              Radius.circular(LegalHubTheme.radiusMd),
            ),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                Icon(Icons.check, size: 16, color: scheme.onSurface),
                const SizedBox(width: LegalHubTheme.space2xs),
              ],
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
