import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/auth/session.dart';
import '../../../data/local/org_selection_store.dart';

/// Client-side active-organization context (Phase 7 slice 7.0, D-M7/D-08;
/// persistence added in P3.2, D-P32.2).
///
/// The active org is a **client-side UX convenience only** (P0 D-08): every
/// server request re-derives membership from the authenticated session and
/// never trusts a client-selected org id. This store holds the locally
/// selected organization id, seeded from [Session.activeMembership] and
/// updated by the org switcher. It is app-scoped in the service locator and
/// persisted **on-device only** ([OrgSelectionStore] — SharedPreferences in
/// production) so the selection survives restarts; it is never transmitted
/// and never an authorization claim.
///
/// Persistence semantics (D-P32.2):
/// - **Restore:** the persisted id is read once at construction and applied
///   only when the seeded session still holds a membership for it — the
///   session is the membership authority, so a stale or foreign selection is
///   never applied. The read may resolve before or after the first seed
///   (cold start: the hub seeds in the same build pass the store is
///   constructed); both orderings apply the value exactly once for the
///   current user.
/// - **Persist:** `select` writes the id best-effort; a write failure logs
///   loudly and never breaks the in-memory selection.
/// - **Seed guard unchanged:** [syncFromSession] keys on the session
///   `userId`, so an active membership change *within* the same session does
///   not re-seed — a deliberate choice (a user selection must survive);
///   consumers that need the membership re-derived should watch the session
///   themselves.
class ActiveOrgStore extends ChangeNotifier {
  ActiveOrgStore(this._orgSelectionStore) {
    _restoreSelection();
  }

  final OrgSelectionStore _orgSelectionStore;

  String? _activeOrganizationId;
  String? _seededUserId;
  List<OrganizationMembership>? _seededMemberships;
  String? _restoredOrganizationId;

  /// The locally selected organization id (null before any session exists).
  String? get activeOrganizationId => _activeOrganizationId;

  /// Reads the persisted selection once, at construction.
  ///
  /// Validated application (D-08 — the session is the membership authority):
  /// if a session is already seeded when the read resolves (the cold-start
  /// ordering where the hub seeded during the same build pass), the value is
  /// applied now when that session still holds the membership; otherwise it
  /// is cached for the next [syncFromSession] identity change, which applies
  /// the same validation. Either way the value is applied at most once. A
  /// read failure logs loudly and is treated as "no persisted selection".
  Future<void> _restoreSelection() async {
    String? restored;
    try {
      restored = await _orgSelectionStore.read();
    } catch (error) {
      debugPrint('ActiveOrgStore: failed to read persisted selection: $error');
    }
    if (restored == null) {
      return;
    }
    final List<OrganizationMembership>? seededMemberships = _seededMemberships;
    if (seededMemberships != null &&
        seededMemberships.any(
          (OrganizationMembership m) => m.organizationId == restored,
        )) {
      _activeOrganizationId = restored;
      notifyListeners();
      return;
    }
    _restoredOrganizationId = restored;
  }

  /// Seeds [activeOrganizationId] from [Session.activeMembership].
  ///
  /// Re-seeding happens only when the session identity changes (sign-out →
  /// null, or a different user); a selection made in the current session is
  /// preserved across rebuilds. When a persisted selection exists, it wins
  /// over the session default — but only if the session still holds a
  /// membership for it; otherwise the session-derived default applies. No
  /// notification is emitted — callers invoke this from a build/dependency
  /// pass that already triggers their rebuild.
  void syncFromSession(Session? session) {
    final String? userId = session?.userId;
    if (userId == _seededUserId) {
      return;
    }
    _seededUserId = userId;
    _seededMemberships = session?.memberships;
    if (session == null) {
      // Sign-out: clear the context but never discard a cached, not-yet-
      // applied restore — the next real-user seed re-validates it, so a
      // same-user sign-out → sign-in keeps the persisted selection.
      _activeOrganizationId = null;
      return;
    }
    final String? restored = _restoredOrganizationId;
    _restoredOrganizationId = null;
    final List<OrganizationMembership> memberships = session.memberships;
    final bool restoredIsValid =
        restored != null &&
        memberships.any(
          (OrganizationMembership m) => m.organizationId == restored,
        );
    _activeOrganizationId = restoredIsValid
        ? restored
        : session.activeMembership?.organizationId;
  }

  /// Switches the locally selected organization (D-08: client-side only —
  /// never sent to the server). Notifies listeners so surfaces re-render and
  /// persists the selection best-effort ([OrgSelectionStore]).
  void select(String organizationId) {
    if (_activeOrganizationId == organizationId) {
      return;
    }
    _activeOrganizationId = organizationId;
    notifyListeners();
    unawaited(_persistSelection(organizationId));
  }

  /// Best-effort persistence: the in-memory selection is already applied;
  /// a write failure is logged loudly and must not break the UX (D-08).
  Future<void> _persistSelection(String organizationId) async {
    try {
      await _orgSelectionStore.write(organizationId);
    } catch (error) {
      debugPrint('ActiveOrgStore: failed to persist selection: $error');
    }
  }
}
