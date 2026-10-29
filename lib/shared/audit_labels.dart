import 'package:legalhub/l10n/app_localizations.dart';

/// Localized label for a server audit code.
///
/// Audit rows used to render the raw server token (`memberRoleChange`) as
/// their title, which is vocabulary no user should have to read. Known codes
/// map to a localized sentence; **unknown codes fall back to the raw value**
/// — an audit log must never silently drop or blank an event it does not
/// recognise.
String auditEventLabel(AppLocalizations l10n, String action) => switch (action) {
  'memberRoleChange' => l10n.auditEventMemberRoleChange,
  'memberInvite' => l10n.auditEventMemberInvite,
  'memberSuspend' => l10n.auditEventMemberSuspend,
  _ => action,
};
