import '../../core/practice_area.dart';
import '../../l10n/app_localizations.dart';

/// Localized label for a [PracticeArea], shared by the discovery and matter
/// surfaces (Phase 6 slices 6.1/6.2, Phase 7 slice 7.1).
///
/// Reuses the home dashboard's practice-area keys (`l10n.areaCorporate` …
/// `l10n.areaFamily`), so the surfaces add no new area strings. Lives in the
/// shared barrel because [PracticeArea] is a core value shared across
/// features.
String practiceAreaLabel(AppLocalizations l10n, PracticeArea area) =>
    switch (area) {
      PracticeArea.corporate => l10n.areaCorporate,
      PracticeArea.civil => l10n.areaCivil,
      PracticeArea.criminal => l10n.areaCriminal,
      PracticeArea.family => l10n.areaFamily,
    };
