import 'package:flutter/material.dart';

import '../../../app/legalhub_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Home-dashboard entry into the booking wizard (Phase 5 slice 5.2).
///
/// Rendered on the home screen only when the session's role grants
/// [RoleCapability.canBookConsultation]. Tapping navigates to the `/book`
/// route. The entry is a navigation hint only — like every capability flag in
/// this bootstrap, it is never an authorization grant.
class BookingEntryCard extends StatelessWidget {
  const BookingEntryCard({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(LegalHubTheme.radiusXl),
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.spaceMd),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.event_available_outlined,
                  size: 22,
                  color: scheme.onPrimaryContainer,
                  fill: 1,
                ),
              ),
              const SizedBox(width: LegalHubTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.bookingEntryTitle,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.bookingEntrySubtitle,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
