import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/widgets/label_chip.dart';
import 'package:material_ui/material_ui.dart';

/// The visible marker that a row's text is invented demonstration content.
///
/// This is a truthfulness control, not decoration (ADR-0009). The library ships
/// sample data only; a reader must never mistake it for official legal text, so
/// every surface that renders a sample document or article renders this badge
/// beside it. The DB flag (`is_sample`) is the source of truth — this widget is
/// only the rendering of it.
///
/// Non-negotiable: it must remain readable at the 2.0 text-scale ceiling, which
/// is why it is a [LabelChip] with a wrapping label rather than an icon.
class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: l10n.librarySampleNotice,
      child: ExcludeSemantics(
        child: LabelChip(
          label: l10n.librarySampleBadge,
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
          maxLines: null,
        ),
      ),
    );
  }
}

/// The persistent reader disclaimer: "Informational only. Not legal advice."
///
/// A separate one-line surface from [SampleBadge]: the badge says the *text* is
/// sample data, this says the *app* is not a legal adviser. Both are required
/// (ADR-0009), and both must survive in every locale.
class LegalDisclaimerLine extends StatelessWidget {
  const LegalDisclaimerLine({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: LegalHubTheme.spaceSm,
        bottom: LegalHubTheme.spaceSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: LegalHubTheme.spaceXs),
          Expanded(
            child: Text(
              l10n.libraryDisclaimer,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
