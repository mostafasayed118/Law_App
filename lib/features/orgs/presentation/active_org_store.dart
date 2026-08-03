import 'package:flutter/foundation.dart';

import '../../../core/auth/session.dart';

/// Client-side active-organization context (Phase 7 slice 7.0, D-M7/D-08).
///
/// The active org is a **client-side UX convenience only** (P0 D-08): every
/// server request re-derives membership from the authenticated session and
/// never trusts a client-selected org id. This store holds the locally
/// selected organization id, seeded from [Session.activeMembership] and
/// updated by the org switcher. It is app-scoped in the service locator,
/// in-memory only, never serialized, and never transmitted.
///
/// Note: the seed guard keys on the session `userId`, so an active
/// membership change *within* the same session does not re-seed — a
/// deliberate choice (a user selection must survive); consumers that need
/// the membership re-derived should watch the session themselves.
class ActiveOrgStore extends ChangeNotifier {
  String? _activeOrganizationId;
  String? _seededUserId;

  /// The locally selected organization id (null before any session exists).
  String? get activeOrganizationId => _activeOrganizationId;

  /// Seeds [activeOrganizationId] from [Session.activeMembership].
  ///
  /// Re-seeding happens only when the session identity changes (sign-out →
  /// null, or a different user); a selection made in the current session is
  /// preserved across rebuilds. No notification is emitted — callers invoke
  /// this from a build/dependency pass that already triggers their rebuild.
  void syncFromSession(Session? session) {
    final String? userId = session?.userId;
    if (userId == _seededUserId) {
      return;
    }
    _seededUserId = userId;
    _activeOrganizationId = session?.activeMembership?.organizationId;
  }

  /// Switches the locally selected organization (D-08: client-side only —
  /// never sent to the server). Notifies listeners so surfaces re-render.
  void select(String organizationId) {
    if (_activeOrganizationId == organizationId) {
      return;
    }
    _activeOrganizationId = organizationId;
    notifyListeners();
  }
}
