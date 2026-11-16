import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Localized labels for the library's taxonomy and lifecycle enums.
///
/// Kept in presentation, not domain: the enums are wire-independent values and
/// the copy is a presentation concern. Exhaustive switches, so a new category or
/// status is a compile error here rather than a blank chip on a device.
String libraryCategoryLabel(AppLocalizations l10n, LegalCategory category) {
  return switch (category) {
    LegalCategory.civil => l10n.libraryCategoryCivil,
    LegalCategory.criminal => l10n.libraryCategoryCriminal,
    LegalCategory.labor => l10n.libraryCategoryLabor,
    LegalCategory.commercial => l10n.libraryCategoryCommercial,
    LegalCategory.family => l10n.libraryCategoryFamily,
    LegalCategory.administrative => l10n.libraryCategoryAdministrative,
    LegalCategory.constitutional => l10n.libraryCategoryConstitutional,
    LegalCategory.other => l10n.libraryCategoryOther,
  };
}

String libraryStatusLabel(AppLocalizations l10n, LegalStatus status) {
  return switch (status) {
    LegalStatus.inForce => l10n.libraryStatusInForce,
    LegalStatus.amended => l10n.libraryStatusAmended,
    LegalStatus.repealed => l10n.libraryStatusRepealed,
    LegalStatus.unknown => l10n.libraryStatusUnknown,
  };
}
