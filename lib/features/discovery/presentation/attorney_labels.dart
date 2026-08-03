import '../../../l10n/app_localizations.dart';
import '../domain/attorney.dart';

/// Localized label for a [PracticeArea], shared by the search and profile
/// surfaces (Phase 6, slices 6.1/6.2).
///
/// Reuses the home dashboard's practice-area keys (`l10n.areaCorporate` …
/// `l10n.areaFamily`), so the discovery surfaces add no new area strings.
String practiceAreaLabel(AppLocalizations l10n, PracticeArea area) =>
    switch (area) {
      PracticeArea.corporate => l10n.areaCorporate,
      PracticeArea.civil => l10n.areaCivil,
      PracticeArea.criminal => l10n.areaCriminal,
      PracticeArea.family => l10n.areaFamily,
    };
