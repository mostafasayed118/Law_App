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
///   only when the next seeded session still holds a membership for it —
///   the session is the membership authority, so a stale or foreign
///   selection is never applied.
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
  String? _restoredOrganizationId;

  /// The locally selected organization id (null before any session exists).
  String? get activeOrganizationId => _activeOrganizationId;

  /// Reads the persisted selection once, at construction.
  ///
  /// The value is cached, not applied directly: it is consumed by the next
  /// [syncFromSession] seed, which validates it against the session's
  /// memberships (D-08 — the session is the membership authority). If the
  /// read races a seed that already consumed an earlier value, the late
  /// value is simply held for the next identity change, where the same
  /// validation applies. A read failure logs loudly and is treated as "no
  /// persisted selection".
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
    final String? restored = _restoredOrganizationId;
    _restoredOrganizationId = null;
    final List<OrganizationMembership> memberships =
        session?.memberships ?? const <OrganizationMembership>[];
    final bool restoredIsValid =
        restored != null &&
        memberships.any(
          (OrganizationMembership m) => m.organizationId == restored,
        );
    _activeOrganizationId = restoredIsValid
        ? restored
        : session?.activeMembership?.organizationId;
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
