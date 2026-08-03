import '../../../l10n/app_localizations.dart';
import '../domain/document.dart';

/// Localized label for a [DocumentType], rendered as the vault tile's type
/// chip and secondary-line type label (Phase 8, slice 8.1).
String documentTypeLabel(AppLocalizations l10n, DocumentType type) =>
    switch (type) {
      DocumentType.contract => l10n.documentTypeContract,
      DocumentType.brief => l10n.documentTypeBrief,
      DocumentType.evidence => l10n.documentTypeEvidence,
      DocumentType.correspondence => l10n.documentTypeCorrespondence,
    };
