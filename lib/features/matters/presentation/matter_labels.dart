import '../../../l10n/app_localizations.dart';
import '../domain/matter.dart';

/// Localized label for a [MatterStatus], shared by the list surface (and the
/// slice 7.2 details surface).
String matterStatusLabel(AppLocalizations l10n, MatterStatus status) =>
    switch (status) {
      MatterStatus.open => l10n.matterStatusOpen,
      MatterStatus.active => l10n.matterStatusActive,
      MatterStatus.closed => l10n.matterStatusClosed,
    };
