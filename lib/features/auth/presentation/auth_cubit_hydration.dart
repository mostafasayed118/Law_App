part of 'auth_cubit.dart';

/// The membership-hydration + stream-mapping group of [AuthCubit] —
/// the same method bodies moved verbatim; the class applies this mixin.
mixin _AuthHydration on _AuthCubitBase {
  /// Public membership re-hydration seam (P3.3 Slice A) — the recorded Task 8
  /// retry/refresh hook for an already-authenticated session.
  ///
  /// Resolves the Task 8 "no first-class `hydrate()` retry seam" limitation:
  /// after an org mutation (create/invite/accept), presentation calls this so
  /// the freshly mutated membership joins [Session.memberships] without
  /// re-authenticating. It is a **background refresh**: the current
  /// authenticated state is held (no loading/restoring flash — scope §7) and
  /// only re-emitted when the hydrated memberships actually change
  /// ([_emitIfChanged] dedupe).
  ///
  /// No-ops when: the session is absent or expired (nothing to refresh), an
  /// explicit operation owns the emission, or another hydrate is in flight
  /// (first-call-wins). A failure leaves the last-known-good state untouched
  /// and is surfaced through the diagnostic channel (never invalidating the
  /// session). The sign-out guard applies the refresh only when the state is
  /// still authenticated for the same user — a session that changed or
  /// disappeared mid-refresh is never clobbered.
  Future<void> hydrate() async {
    final Session? current = state.session;
    if (current == null ||
        current.isExpired ||
        _explicitOperationInFlight ||
        _hydrationInFlight) {
      return;
    }
    _hydrationInFlight = true;
    final int epoch = _hydrationEpoch;
    try {
      final MembershipHydrationResult result = await _membershipRepository
          .loadMemberships(userId: current.userId);
      switch (result) {
        case HydrationSucceeded(
          :final List<OrganizationMembership> memberships,
        ):
          // An explicit op that started (or completed) while this refresh
          // was awaiting owns the emission — its hydration is fresher, so a
          // same-user re-auth is never clobbered by the stale refresh.
          if (epoch != _hydrationEpoch) {
            return;
          }
          final Session? now = state.session;
          if (now == null || now.userId != current.userId || now.isExpired) {
            return;
          }
          _emitIfChanged(
            AuthState(
              status: AuthStatus.authenticated,
              session: _withMemberships(now, memberships),
            ),
          );
        case HydrationFailed(:final MembershipHydrationFailureKind kind):
          await _reportHydrationFailure(kind);
      }
    } finally {
      _hydrationInFlight = false;
    }
  }

  /// Contract-§5 authenticated mapping + P3.2 membership hydration.
  ///
  /// The loading/restoring status is held until hydration resolves (scope
  /// §7 mitigation — no intermediate authenticated-with-empty render).
  /// Hydration is best-effort enrichment of an already-authenticated
  /// session: a provider-reported empty list stays the honest `[]` (plan
  /// §6), and a failed read still authenticates the session (it is never
  /// invalidated) but is surfaced through the diagnostic channel (Task 8
  /// review inputs). Expiry is honored before hydration (AC-3): an expired
  /// session re-authenticates and is never hydrated.
  ///
  /// The provider stream path (Phase 4.1 deep-link) maps without hydration
  /// by design. The first-class refresh seam for an already-authenticated
  /// session is [hydrate] (P3.3) — presentation calls it after an org
  /// mutation; the next explicit auth op re-hydrates as well.
  Future<void> _applyAuthenticatedSession(Session session) async {
    // This explicit hydration is fresher than any in-flight [hydrate]
    // refresh (Slice A review fix — see [_hydrationEpoch]).
    _hydrationEpoch += 1;
    if (session.isExpired) {
      emit(const AuthState(status: AuthStatus.reauthRequired));
      return;
    }
    final MembershipHydrationResult result = await _membershipRepository
        .loadMemberships(userId: session.userId);
    switch (result) {
      case HydrationSucceeded(:final List<OrganizationMembership> memberships):
        _emitIfChanged(
          AuthState(
            status: AuthStatus.authenticated,
            session: _withMemberships(session, memberships),
          ),
        );
      case HydrationFailed(:final MembershipHydrationFailureKind kind):
        // Honest empty — never a fabricated membership; the session stays
        // authenticated with the gateway snapshot's memberships. The
        // diagnostic report must never gate this emission (a throwing
        // reporter must not strand the session in loading), so the state is
        // emitted first and the report is best-effort.
        _emitIfChanged(
          AuthState(
            status: AuthStatus.authenticated,
            session: _withMemberships(
              session,
              const <OrganizationMembership>[],
            ),
          ),
        );
        await _reportHydrationFailure(kind);
    }
  }

  /// Rebuilds [session] with the hydrated memberships (identity, display
  /// name, and expiry are carried unchanged — only the RLS-scoped
  /// membership view is refreshed).
  Session _withMemberships(
    Session session,
    List<OrganizationMembership> memberships,
  ) => Session(
    userId: session.userId,
    displayName: session.displayName,
    memberships: memberships,
    expiresAt: session.expiresAt,
  );

  /// Diagnostic-channel report (Task 8 review input 2 — the ErrorReporter
  /// seam instead of repository debugPrint). Best-effort by contract: the
  /// authenticated session is emitted before this runs, and a throwing
  /// reporter must never surface as a failure, so the report is wrapped.
  Future<void> _reportHydrationFailure(
    MembershipHydrationFailureKind kind,
  ) async {
    try {
      await _reporter.report(
        AppError(
          code: 'membershipHydrationFailed',
          userMessage: 'Organization memberships could not be loaded.',
          context: <String, Object?>{'kind': kind.name},
        ),
      );
    } catch (error) {
      // Diagnostics must not break the already-emitted authenticated state.
      debugPrint('AuthCubit: hydration diagnostic report failed: $error');
    }
  }

  /// Emits [next] only when it actually differs from the current state.
  ///
  /// The gateway stream replays the session after explicit operations (the
  /// fake emits on `startDemoSession`/`signOut`), so the same [AuthState]
  /// can arrive from both the stream listener and the outcome mapping;
  /// re-emitting an equal state would just churn the router refresh.
  void _emitIfChanged(AuthState next) {
    if (!isClosed && next != state) {
      emit(next);
    }
  }

  /// Applies a provider-initiated session change (the auth callback handler).
  ///
  /// Mirrors the [AuthOutcome] mapping so the app state stays consistent no
  /// matter how the session arrived: a null session is honestly
  /// `unauthenticated`, an expired one `reauthRequired`, and a valid one
  /// `authenticated` (contract §5). Emits only on an actual change; the
  /// gateway stream also replays the session after explicit operations, and
  /// re-emitting an equal [AuthState] would just churn the router refresh.
  void _onSessionChange(Session? session) {
    if (isClosed || _explicitOperationInFlight) {
      return;
    }
    _emitIfChanged(_stateFor(session));
  }

  AuthState _stateFor(Session? session) {
    if (session == null) {
      return const AuthState.unauthenticated();
    }
    if (session.isExpired) {
      return const AuthState(status: AuthStatus.reauthRequired);
    }
    return AuthState(status: AuthStatus.authenticated, session: session);
  }
}
