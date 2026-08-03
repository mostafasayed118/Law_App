import '../../../core/organizations/organization_gateway.dart';
import '../../../l10n/app_localizations.dart';

/// Localized, non-sensitive message for an [OrgFailureKind].
///
/// P3 spec §4.4: every server error surfaces as a localized message; provider
/// wording never reaches the user. The kind is the contract — the gateway's
/// own message stays in diagnostics only.
String orgErrorMessage(AppLocalizations l10n, OrgFailureKind kind) {
  return switch (kind) {
    OrgFailureKind.denied => l10n.orgErrorDenied,
    OrgFailureKind.duplicateMember => l10n.orgErrorDuplicateMember,
    OrgFailureKind.lastPartner => l10n.orgErrorLastPartner,
    OrgFailureKind.invalidRole => l10n.orgErrorInvalidRole,
    OrgFailureKind.invalidName => l10n.orgErrorInvalidName,
    OrgFailureKind.invalidInvitation => l10n.orgErrorInvalidInvitation,
    OrgFailureKind.providerUnavailable => l10n.orgErrorProviderUnavailable,
    OrgFailureKind.unknown => l10n.orgErrorUnknown,
  };
}
